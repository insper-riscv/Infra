# Setting up a self-hosted runner (step-by-step guide)

Covers a workstation with access to FPGA hardware (Quartus + JTAG). `/opt`
itself is standard FHS (Filesystem Hierarchy Standard) for manually
installed/add-on software, outside the distro's package manager; the
subfolder names below it (`actions-runner`, `altera_lite`,
`riscv-foundation`) are a suggested convention. Adjust to your machine's
setup.

## Overview

```
/opt/actions-runner/      home of the "runner" service user (the GitHub Actions runner itself)
/opt/altera_lite/         the actual Quartus install, directly in /opt (prerequisite, see QUARTUS_INSTALL.md)
/opt/riscv-foundation/    shared cache for what is compiled locally for RISC-V (GCC, Spike)
```

## Prerequisite: Install Quartus Prime Lite

Quartus needs to be installed directly under `/opt/altera_lite` before
following the phases below: download, GUI/CLI mode, global PATH and
`.desktop` shortcut are in [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md).

## Phase 1: Dedicated service user

The runner runs as a system user **without a password, without its own
sudo, not in the admin user's group**: deliberate isolation.

```bash
sudo useradd -r -m -d /opt/actions-runner -s /usr/sbin/nologin runner
sudo passwd -l runner              # no password login; only via sudo/systemd
sudo usermod -aG plugdev runner    # access to the USB-Blaster (defense in depth)
```

- `-r` → UID/GID in the system range (usually below `1000`), chosen
  automatically among whatever is already free on the machine the command
  runs on.
- `-m -d /opt/actions-runner` → creates the home already in the right
  place, owned by `runner:runner`.
- `-s /usr/sbin/nologin` → deliberate: `runner` should not have any
  interactive login shell, which reduces a service account's attack
  surface with no loss of functionality. Details on which commands this
  affects right below.

Because of `nologin`, `sudo -iu runner ...` and `sudo su - runner` fail:
every command in this guide uses `sudo -u runner bash -lc '...'` (without
`-i`) instead.

**Verify afterward that the account is configured correctly**: the `-d`
above only guarantees the right `HOME` at creation time. If the `runner`
account is ever recreated some other way later (a different provisioning
script, or a repeated `useradd runner` by someone who doesn't know about
this convention), `/etc/passwd` ends up recording `HOME=/home/runner` (a
directory that never existed) instead of `/opt/actions-runner`, which
silently breaks any tool that depends on
`$HOME` when run manually via `sudo -u runner`: for example, `uv` (see
[SPIKE_SETUP.md](SPIKE_SETUP.md)) fails with `Failed to initialize cache
at /home/runner/.cache/uv: Permission denied` because it tries to create
a cache in a nonexistent/wrongly-owned directory.

Verify:
```bash
getent passwd runner   # check the 6th field (home)
```

If it is wrong, fix it:
```bash
sudo usermod -d /opt/actions-runner runner
```

## Phase 2: Register the runner with GitHub

**Where to get the token/URL**: on the repo (or the org, if this is an
org-level runner) → **Settings → Actions → Runners → New runner**. The
token expires in ~1h, so copy it right away.

```bash
sudo -u runner HOME=/opt/actions-runner bash -lc '
  cd /opt/actions-runner
  curl -o actions-runner.tar.gz -L <DOWNLOAD_URL_FROM_THE_PAGE>
  tar xzf actions-runner.tar.gz
  ./config.sh --url https://github.com/<org-or-org/repo> --token <TOKEN_FROM_THE_PAGE> \
      --labels self-hosted,quartus,fpga --name workstation-fpga --unattended
'
```

- `sudo -u runner ... bash -lc` (without `-i`) and explicit
  `HOME=/opt/actions-runner`: see Phase 1 (why to avoid `-i` with
  `nologin`, and why to pass `HOME=` even when the account is already
  correct).
- **If the token gives a permission error like "refusing to allow a
  Personal Access Token to create or update workflow ... without
  `workflow` scope"**: the token (fine-grained PAT) needs the
  **"Workflows"** permission enabled (Read and write); it is different
  from "Contents"/"Actions", and needs to be added explicitly on the
  token's edit screen.

### Security: org-level runner

If the runner is registered on the ORG (not on a specific repo), it
becomes available to **any repo** that its *runner group* allows: by
default that is usually "All repositories", which exposes this machine to
public repos in the same org.

**Mandatory**: Org Settings → Actions → Runner groups → the group this
runner landed in → **Repository access → Selected repositories → only the
repos that actually need to touch hardware**. Without this, any public
repo in the org reaches this machine through the same runner.

**The group has to be named `FPGA`** (not the default "Default", nor any
other name like "Workstation - FPGA"): that is the group this project's
workflows expect to be able to reach.

- **At registration** (`config.sh` without `--runnergroup`): the CLI asks
  which group to put the runner in; pick or create the `FPGA` group
  there.
- **If the runner was already registered in the wrong group**: move it
  via Org Settings → Actions → Runner groups → `FPGA` → **Runners → Add
  runner**, or change its group from the page of the group it is
  currently in.

A runner in the wrong group does not give a clear error: a workflow's job
that needs it just sits stuck in "Queued" forever, with no message
explaining why.

## Phase 3: systemd service (autorun, survives reboot)

The `svc.sh` script that ships with the runner package assumes the service
user itself has sudo (it calls `sudo systemctl` internally); since
`runner` does not, the unit is written directly:

```bash
sudo tee /etc/systemd/system/gh-actions-runner.service <<'UNIT'
[Unit]
Description=GitHub Actions self-hosted runner (FPGA workstation)
After=network.target

[Service]
Type=simple
User=runner
WorkingDirectory=/opt/actions-runner
ExecStart=/opt/actions-runner/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now gh-actions-runner
sudo systemctl status gh-actions-runner --no-pager   # should show "active (running)"
```

## Phase 4: Shared cache for GCC and Spike (`/opt/riscv-foundation`)

Without this cache, every batch of tests the runner ran would have to
recompile the RISC-V GCC and Spike from scratch before even starting; with
the cache, the job only checks whether the already-built commit is the
same one, and only recompiles when it is not. Creating the directory,
cloning the source, compiling, and putting it on the global `PATH` are
steps specific to each toolchain:

- RISC-V GCC: [GCC_SETUP.md](GCC_SETUP.md).
- Spike: [SPIKE_SETUP.md](SPIKE_SETUP.md).

For another user (does not need to be an admin) to also be able to create
files in this cache without `sudo` every time, just add them to the
`runner` group: this does not grant any privilege beyond access to
`/opt/riscv-foundation`, and does not guarantee write access to files that
already exist with a different owner/permission (depends on each
individual file's mode):

```bash
sudo usermod -aG runner <user>
```

**Note**: a group change only applies to a new shell session. To use it in
the current session without logging out: `sg runner -c "<command>"`.

## Phase 5 (optional, on GitHub): Secret to confirm manual triggering

Unlike the other phases, this is configured per repository in GitHub's
settings, not on the machine: it needs to be repeated in every repo that
uses this runner for real hardware, and it is optional depending on the
team's trust model.

Beyond the repo's access control (Phase 2), a second gate for manual
triggering via `workflow_dispatch`: useful if more people ever get write
access to the repo without being meant to trigger physical hardware.

- Repo → **Settings → Secrets and variables → Actions → New repository
  secret**
- Name: `FPGA_RUN_SECRET`, value: any phrase (e.g. `openssl rand -hex 32`)
- In the workflow, a `workflow_dispatch.inputs.confirm` compared against
  this secret before any step that touches the board (see the project's
  `real.yml`).

## Phase 6: Permission for the runner to reset the JTAG

The project's real-hardware workflow (example: `real.yml` in
[insper-riscv/Testes](https://github.com/insper-riscv/Testes)) typically
checks `jtagconfig` before compiling and, if the chain is stuck, tries a
`killall jtagd` with an automatic recheck before failing with a clear
message asking for manual intervention. This needs passwordless sudo for
just that exact command:

```bash
echo 'runner ALL=(root) NOPASSWD: /usr/bin/killall jtagd' | \
  sudo tee /etc/sudoers.d/runner-jtagd
```

JTAG hardware gotchas (the USB port number changing, autosuspend dropping
the connection, a "chain broken" that only resolves with a power-cycle)
are behavior of the hardware itself, not content of the runner's setup:
a documented example is in
[HARDWARE_PROGRAMMING.md from insper-riscv/Testes](https://github.com/insper-riscv/Testes/blob/main/docs/HARDWARE_PROGRAMMING.md).

## Final checklist

- [ ] `sudo systemctl status gh-actions-runner` → `active (running)`
- [ ] Runner shows up as **Idle** in Settings → Actions → Runners, with the
  right labels
- [ ] Runner group restricted to **Selected repositories** (not "All
  repositories")
- [ ] RISC-V GCC and Spike compiled and on the `PATH`: `which
  riscv32-unknown-elf-gcc` and `which spike`
- [ ] `jtagconfig` reads the board's device ID with no error
- [ ] Manual confirmation secret configured, if applicable

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
