# Setting up a self-hosted runner

A workstation with an FPGA board and a USB-Blaster, registered as a self-hosted runner of GitHub Actions. The jobs that touch the board run in a Docker container, a CI image of the project, which gets the Quartus of the host mounted read-only and reaches the board through the JTAG server (`jtagd`) of the host. The host therefore holds Quartus, Docker, `jtagd` and the runner, and none of the tools of the CI images (GHDL, the RISC-V GCC, Spike and the rest).

| Component | Where | Role |
| :--- | :--- | :--- |
| Runner program | `/opt/actions-runner`, user `runner` | receives the jobs from GitHub |
| Docker | host | runs the container of each job |
| CI image | container | the tools of the tests, from the [Docker images](docker/README.md) |
| Quartus | `/opt/altera_lite` on the host, read-only in the container | compiles and programs the board |
| `jtagd` | host, port 1309 | the JTAG server that owns the USB-Blaster |

`/opt` is the standard place (FHS, Filesystem Hierarchy Standard) for software installed by hand, outside the package manager of the distro; the names below it are a convention, adjust them to the machine.

## 1. Requirements

| Requirement | How |
| :--- | :--- |
| Quartus Prime Lite in `/opt/altera_lite` | [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md) |
| Docker Engine | the [installation guide](https://docs.docker.com/engine/install/) of the distro |
| Access to GitHub and to `ghcr.io` | outbound HTTPS |
| A user with `sudo` | to run the steps below |

## 2. Permission for the USB-Blaster

The `udev` rule that Quartus needs to let a process open the USB-Blaster without being root. Create `/etc/udev/rules.d/92-usbblaster.rules`:

```text
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6001", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6002", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6003", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6010", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6810", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6020", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6022", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6024", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6025", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6026", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="602C", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="602D", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="602E", GROUP="plugdev", MODE="0660"
```

Then reload the rules and plug the cable again:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
lsusb -d 09fb:     # lists the USB-Blaster
```

`09fb` is the vendor id of Altera, and `GROUP="plugdev", MODE="0660"` lets the members of the `plugdev` group open the device, and nobody else. A user who runs `jtagconfig` by hand on the machine also needs to be in `plugdev`.

## 3. Dedicated service user

The runner runs as a system user **without a password, without its own sudo and not in the group of the admin user**, which isolates it from the rest of the machine. The `docker` group lets it start the containers of the jobs, and `plugdev` lets its `jtagd` open the USB-Blaster.

```bash
sudo useradd -r -m -d /opt/actions-runner -s /usr/sbin/nologin runner
sudo passwd -l runner              # no password login; only via sudo/systemd
sudo usermod -aG docker runner     # starts the containers of the jobs
sudo usermod -aG plugdev runner    # opens the USB-Blaster (section 2)
```

Membership in the `docker` group is equivalent to root on the machine, which is at odds with the isolation above. Where that is not acceptable, give `runner` its own rootless Docker instead of the group.

- `-r` creates the user with a UID/GID in the system range, chosen among whatever is free on the machine.
- `-m -d /opt/actions-runner` creates the home already in the right place, owned by `runner:runner`.
- `-s /usr/sbin/nologin` gives the account no interactive shell.

Because of `nologin`, `sudo -iu runner ...` and `sudo su - runner` fail; every command in this guide uses `sudo -u runner bash -lc '...'`, without `-i`.

Check that the home recorded for the account is `/opt/actions-runner`, which is what `-d` sets at creation:

```bash
getent passwd runner   # the 6th field is the home
sudo usermod -d /opt/actions-runner runner   # only if it shows something else
```

## 4. JTAG server on the host

The container reaches the board through a `jtagd` that runs on the host and listens on `localhost:1309`. A systemd service keeps it up and starts it again if it dies:

```bash
sudo tee /etc/systemd/system/jtagd.service <<'UNIT'
[Unit]
Description=Quartus JTAG server (jtagd)
After=network.target

[Service]
Type=simple
User=runner
ExecStart=/opt/altera_lite/25.1std/quartus/bin/jtagd --foreground --no-config
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now jtagd
```

| Option | Effect |
| :--- | :--- |
| `--foreground` | keeps `jtagd` as the process systemd supervises, instead of detaching to the background |
| `--no-config` | starts with the default configuration and writes no configuration file; the USB-Blaster is auto-detected |

Check that it listens and answers:

```bash
sudo systemctl status jtagd --no-pager   # active (running)
ss -ltn | grep ':1309 '                  # listening on port 1309
jtagconfig                               # prints the cable and the chip with the board connected
```

With no board connected, `jtagconfig` prints `No JTAG hardware available`. The behavior of the hardware itself, such as the USB port number changing or a JTAG chain that only a power cycle clears, is in [HARDWARE_PROGRAMMING.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/HARDWARE_PROGRAMMING.md) of TopLevel.

## 5. Register the runner with GitHub

**Where to get the token and the URL**: on the repo (or on the org, for an org-level runner) → **Settings → Actions → Runners → New runner**. The token expires in about one hour, so copy it right away.

```bash
sudo -u runner HOME=/opt/actions-runner bash -lc '
  cd /opt/actions-runner
  curl -o actions-runner.tar.gz -L <DOWNLOAD_URL_FROM_THE_PAGE>
  tar xzf actions-runner.tar.gz
  ./config.sh --url https://github.com/<org-or-org/repo> --token <TOKEN_FROM_THE_PAGE> \
      --labels self-hosted,quartus,fpga --name workstation-fpga --unattended
'
```

`HOME=/opt/actions-runner` is passed explicitly so the registration does not depend on the home recorded for the account.

### 5.1. Org-level runner

A runner registered on the org is available to **any repo** that its *runner group* allows, and by default that group is "All repositories", which exposes the machine to the public repos of the org.

- **Mandatory**: Org Settings → Actions → Runner groups → the group of the runner → **Repository access → Selected repositories** → only the repos that need the hardware.
- **The group has to be named `FPGA`**, not "Default" or any other name.
- At registration, `config.sh` without `--runnergroup` asks which group to use: pick or create `FPGA`.
- A runner already registered in the wrong group is moved in Org Settings → Actions → Runner groups → `FPGA` → **Runners → Add runner**.

A runner in the wrong group gives no error: the job that needs it stays in "Queued" with no message.

## 6. systemd service for the runner

The `svc.sh` script of the runner package assumes the service user has sudo, which `runner` does not, so the unit is written directly. It starts after Docker and `jtagd`:

```bash
sudo tee /etc/systemd/system/gh-actions-runner.service <<'UNIT'
[Unit]
Description=GitHub Actions self-hosted runner (FPGA workstation)
After=network.target docker.service jtagd.service
Wants=docker.service jtagd.service

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
sudo systemctl status gh-actions-runner --no-pager   # active (running)
```

## 7. Restarting the JTAG server

A `jtagd` left in a bad state, for example by a session that did not end, can make `jtagconfig` report a broken chain, and restarting it clears that case. A chain broken by the board itself needs a power cycle of the board, which no restart clears.

Because `jtagd` runs as the `runner` user (section 4), the runner ends it with `killall jtagd`, with no `sudo` and no sudoers rule, and systemd starts it again after the 5 seconds of `RestartSec`. A job can check the chain before using the board, restart `jtagd` once and check again before failing:

```bash
killall jtagd
sleep 6          # the 5 seconds of RestartSec plus the start
jtagconfig
```

Only the steps that run on the host can do this: a step inside the container does not share the processes of the host.

## 8. What the container of a job needs

A job that touches the board runs in a CI image and has to give its container the following. The complete command, with the error that appears when `jtagd` is not running on the host, is in section 7 of [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md).

| Need | How |
| :--- | :--- |
| Quartus | mount `/opt/altera_lite` read-only at the same path and put `/opt/altera_lite/25.1std/quartus/bin` on the `PATH` |
| The `jtagd` of the host | share the network of the host (`--network host`), so `localhost:1309` is the server of section 4 |
| Files owned by the invoking user | `--user "$(id -u):$(id -g)"` and a writable `HOME`, for example `-e HOME=/tmp/h` |
| A Docker daemon that remaps users | add `--userns=host`, which the daemon requires together with `--network host` |

The image needs no Quartus of its own: it carries the system library the command-line tools of Quartus link against.

## 9. Secret to confirm manual runs (optional)

Unlike the previous sections, this one is configured per repository on GitHub, and is optional depending on the trust model of the team. Beyond the access control of the repo, it is a second gate for runs started by hand with `workflow_dispatch`, useful if more people get write access to the repo without being meant to trigger physical hardware.

- Repo → **Settings → Secrets and variables → Actions → New repository secret**.
- Name `FPGA_RUN_SECRET`, with any phrase as the value (for example `openssl rand -hex 32`).
- The workflow compares an input `confirm` against this secret before any step that touches the board.

## 10. Final checklist

- [ ] `sudo systemctl status jtagd gh-actions-runner` shows both `active (running)`
- [ ] `ss -ltn | grep ':1309 '` shows `jtagd` listening
- [ ] `jtagconfig` prints the cable and the chip of the board
- [ ] `sudo -u runner killall jtagd` and, 6 seconds later, `ss -ltn | grep ':1309 '` shows the server again
- [ ] The runner shows up as **Idle** in Settings → Actions → Runners, with the right labels
- [ ] The runner group is restricted to **Selected repositories**, not "All repositories"
- [ ] Docker works as `runner`: `sudo -u runner docker run --rm ghcr.io/insper-riscv/ci-asm:latest riscv32-unknown-elf-gcc --version`
- [ ] Quartus runs in the container, with the options of section 8: `quartus_pgm --version` prints the version
- [ ] The manual confirmation secret is configured, if applicable

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
