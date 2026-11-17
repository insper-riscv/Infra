# Setting up self-hosted runners

A Linux workstation registered as several self-hosted runners of GitHub Actions, split by class of work. A runner executes one job at a time, so the number of runners of a class on a machine is the number of its jobs that run together, and each class is a label. The jobs run in the CI images of the project. The ones that touch an FPGA board get the Quartus of the host mounted read-only and reach the board through the JTAG server (`jtagd`) of the host.

| Class | Label | What it runs | Load profile |
| :--- | :--- | :--- | :--- |
| Compute | `formal`, `build` and `cert` on the same runner | `make formal` proofs (SymbiYosys), the `amd64` build of the Infra images and the simulated ACT4 certification | High CPU, up to about 15 GiB of memory per base platform in the certification, long |
| Simulated test | `sim` | cocotb, VSG, `check-tree`, style and unit tests | Light to medium, short |
| Board | The name of the board, such as `DE2-115` | Test or certification on the real board, including the Quartus compilation | One job per board, queued |

Every runner also carries the `self-hosted` label and the label of the machine, which is the output of `hostname`. The `arm64` build of the images runs on the GitHub-hosted runner (`ubuntu-26.04-arm`), because the workstations are x86_64.

| Component | Where | Role |
| :--- | :--- | :--- |
| Runner program | `/opt/runners/<name>`, user `runner` | receives the jobs from GitHub, one folder per runner |
| Docker | host | runs the container of each job |
| CI image | container | the tools of the tests, from the [Docker images](docker/README.md) |
| Quartus | `/opt/altera_lite` on the host, read-only in the container | compiles and programs the board, only on machines with a board |
| `jtagd` | host, port 1309 | the JTAG server that owns the USB-Blasters, only on machines with a board |

`/opt` is the standard place (FHS, Filesystem Hierarchy Standard) for software installed by hand, outside the package manager of the distro; the names below it are a convention, adjust them to the machine.

## 1. Requirements

| Requirement | How |
| :--- | :--- |
| Docker Engine | the [installation guide](https://docs.docker.com/engine/install/) of the distro |
| Access to GitHub and to `ghcr.io` | outbound HTTPS |
| A user with `sudo` | to run the steps below |
| Quartus Prime Lite in `/opt/altera_lite` | [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md), only on machines with a board |

## 2. Permission for the USB-Blaster

Only on machines with a board. The `udev` rule that Quartus needs to let a process open the USB-Blaster without being root has one line per `idProduct` (`6001`, `6002`, `6003`, `6010`, `6810`, `6020`, `6022`, `6024`, `6025`, `6026`, `602C`, `602D` and `602E`). One block creates `/etc/udev/rules.d/92-usbblaster.rules`, reloads the rules and lists the cables:

```bash
for p in 6001 6002 6003 6010 6810 6020 6022 6024 6025 6026 602C 602D 602E; do
  printf 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="%s", GROUP="plugdev", MODE="0660"\n' "$p"
done | sudo tee /etc/udev/rules.d/92-usbblaster.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --action=add
lsusb -d 09fb:     # lists the USB-Blasters
```

`09fb` is the vendor id of Altera, and `GROUP="plugdev", MODE="0660"` lets the members of the `plugdev` group open the device, and nobody else. A user who runs `jtagconfig` by hand on the machine also needs to be in `plugdev`.

## 3. Dedicated service user

All the runners of the machine run as the same system user **without a password, without its own sudo and not in the group of the admin user**, which isolates it from the rest of the machine. The `docker` group lets it start the containers of the jobs, and `plugdev` lets its `jtagd` open the USB-Blaster.

```bash
sudo useradd -r -m -d /opt/runners -s /usr/sbin/nologin runner
sudo passwd -l runner              # no password login; only via sudo/systemd
sudo usermod -aG docker runner     # starts the containers of the jobs
sudo usermod -aG plugdev runner    # opens the USB-Blaster (section 2), only on machines with a board
```

Membership in the `docker` group is equivalent to root on the machine, which is at odds with the isolation above. Where that is not acceptable, give `runner` its own rootless Docker instead of the group.

- `-r` creates the user with a UID/GID in the system range, chosen among whatever is free on the machine.
- `-m -d /opt/runners` creates the home already in the right place, owned by `runner:runner`.
- `-s /usr/sbin/nologin` gives the account no interactive shell.

Because of `nologin`, `sudo -iu runner ...` and `sudo su - runner` fail; every command in this guide uses `sudo -u runner bash -lc '...'`, without `-i`.

Check that the home registered for the account is `/opt/runners`, which is what `-d` sets at creation:

```bash
getent passwd runner   # the 6th field is the home
sudo usermod -d /opt/runners runner   # only if another value shows up, with jtagd stopped
```

`useradd -m` creates the home with the `0750` mode of `HOME_MODE` in `/etc/login.defs`, which keeps the other users of the machine from listing and reading the runners. The command below opens the root and the files for reading and folder traversal, and leaves only the private key of the runner restricted:

```bash
sudo chmod 755 /opt/runners
sudo find /opt/runners -xdev ! -type l ! -name '.credentials_rsaparams' -exec chmod o+rX {} +
```

`.credentials_rsaparams` holds the key the runner authenticates to GitHub with, and whoever reads it can impersonate the runner. `config.sh` already creates it with mode `600`, and it stays that way.

## 4. JTAG server on the host

Only on machines with a board. The container reaches the boards through a `jtagd` that runs on the host and listens on `localhost:1309`. One `jtagd` per machine sees all of its cables.

### 4.1. The `jtagd` service

A systemd service keeps it up and starts it again if it dies:

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
| `--foreground` | keeps `jtagd` as the process systemd supervises, instead of going to the background |
| `--no-config` | starts with the default configuration and writes no configuration file; the USB-Blasters are detected automatically |

Check that it listens and answers:

```bash
sudo systemctl status jtagd --no-pager   # active (running)
ss -ltn | grep ':1309 '                  # listening on port 1309
sudo -u runner /opt/altera_lite/25.1std/quartus/bin/jtagconfig   # prints each cable and chip
```

With no board connected, `jtagconfig` prints `No JTAG hardware available`. The behavior of the hardware itself, such as the USB port number changing or a JTAG chain that only a power cycle fixes, is in the [HARDWARE_PROGRAMMING.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/HARDWARE_PROGRAMMING.md) of the TopLevel.

### 4.2. The cable of each board

The name of the cable (`USB-Blaster [1-6]`) changes when the USB port changes, so the job finds the cable by the IDCODE of the board, which `jtagconfig` prints right below the cable.

| Board | Label | IDCODE |
| :--- | :--- | :--- |
| DE0-CV | `DE0-CV` | `02B050DD` |
| DE2-115 | `DE2-115` | `020F70DD` |
| DE0-Nano (chip EP4CE22) | `DE0-Nano` | `020F30DD` |
| DE10-Lite (chip 10M50DA) | `DE10-Lite` | `031050DD` |

```bash
cable() {  # cable <IDCODE>
  jtagconfig | awk -v id="$1" '/^[0-9]+\)/ {sub(/^[0-9]+\) /,""); c=$0} $1==id {print c; exit}'
}
cable 020F70DD     # prints the cable of the DE2-115
```

An IDCODE with no cable prints nothing, and the job must fail in that case instead of programming another board. A new board follows the same pattern, with its name as the label and the IDCODE that `jtagconfig` prints for it.

### 4.3. Lock per board

Each board has a lock file of its own, and every use of the board takes it for the whole session: the CI job, an agent and whoever runs by hand. The file is the one `riscv-tools board lock` takes, named `<board without hyphen>-<host>.lock` in `/tmp` (for example `de2115-<host>.lock`), where `<host>` is the label of the machine in the `boards.yaml` of `riscv-tools`, by default the short hostname. The `lock_dir` of that file changes the folder, and every user of the machine must use the same value.

Two jobs on different boards of the same machine run together, and on the same board they run in a queue, whatever the number of runners it has. Whoever does not use `riscv-tools` takes the same lock with a plain `flock` on the same file:

```bash
flock -w 3600 /tmp/de2115-<host>.lock <command>
```

The lock files are created once, as root, with mode `666`. With the `fs.protected_regular=2` that Ubuntu ships, a user cannot open in `/tmp` a file that another user created, and the `runner` and whoever works over ssh would stop sharing the same lock. A `systemd-tmpfiles` file creates the files again at every boot and excludes them from the periodic cleanup of `/tmp`, with one `f` line and one `x` line per board. The first command creates the file, and each following board goes in with `tee -a`, because `tee` without `-a` overwrites the boards already listed:

```bash
h=$(hostname -s)
printf 'f /tmp/de2115-%s.lock 0666 root root -\nx /tmp/de2115-%s.lock\n' $h $h | sudo tee /etc/tmpfiles.d/board-locks.conf
printf 'f /tmp/de0cv-%s.lock 0666 root root -\nx /tmp/de0cv-%s.lock\n' $h $h | sudo tee -a /etc/tmpfiles.d/board-locks.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/board-locks.conf
ls -l /tmp/*.lock
```

The `ls` must list one `-rw-rw-rw-` file per board of the machine, and the number of `f` lines in the configuration file equals the number of files listed.

The board that the job programs must have the IDCODE the `.sof` expects. Programming the `.sof` of one board into another is the mistake to avoid.

## 5. Registering a runner

The token and the URL of the package are in the org, under **Settings → Actions → Runners → New runner**. The token expires in about an hour, so copy it right away, and one token registers several runners within that time. The name and the folder of a runner follow `<host>-<class>-<n>`, where `<host>` is the output of `hostname` and `<class>` is `compute`, `sim` or the name of the board. An example is `D-20003265-LINUX-sim-2`.

```bash
name=$(hostname)-compute-1
sudo -u runner mkdir -p /opt/runners/$name
sudo -u runner HOME=/opt/runners bash -lc "
  cd /opt/runners/$name
  curl -o actions-runner.tar.gz -L <DOWNLOAD_URL_FROM_THE_PAGE>
  tar xzf actions-runner.tar.gz
  ./config.sh --url https://github.com/<org> --token <TOKEN_FROM_THE_PAGE> \
      --runnergroup Workstation --labels self-hosted,$(hostname),formal,build,cert,quartus \
      --name $name --unattended
"
```

`HOME=/opt/runners` is passed explicitly so the registration does not depend on the home recorded in the account. The labels of each class are these:

| Runner | Labels | How many per machine |
| :--- | :--- | :--- |
| `compute` | `self-hosted,<host>,formal,build,cert,quartus` | 1 |
| `sim` | `self-hosted,<host>,sim,quartus` | 2 |
| Board | `self-hosted,<host>,<board>,quartus` | 1 per board |

The `quartus` label goes on every runner of a machine that has Quartus installed, and is left out on machines without it. An already registered runner gains or loses a label through the API:

```bash
gh api -X POST   orgs/<org>/actions/runners/<id>/labels -f 'labels[]=<label>'
gh api -X DELETE orgs/<org>/actions/runners/<id>/labels/<label>
```

The `<id>` appears in `gh api orgs/<org>/actions/runners`.

### 5.1. Runner group

A runner registered in the org is available to **any repo** its *runner group* allows, and by default that group is "All repositories", which exposes the machine to the public repos of the org.

- **Required**: Org Settings → Actions → Runner groups → the `Workstation` group → **Repository access → Selected repositories** → only the repos that use the runners.
- **The group is called `Workstation`**, not "Default". At registration, `config.sh` without `--runnergroup` asks which group to use.
- A runner already registered in the wrong group is moved in Org Settings → Actions → Runner groups → `Workstation` → **Runners → Add runner**.

A runner in the wrong group gives no error: the job that needs it stays "Queued" with no message at all.

## 6. Runner systemd service

The `svc.sh` script of the runner package assumes the service user has sudo, which `runner` does not, so the unit is written directly. One template unit serves all the runners, and the name of the instance is the name of the folder:

```bash
sudo tee /etc/systemd/system/gh-runner@.service <<'UNIT'
[Unit]
Description=GitHub Actions self-hosted runner %i
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=runner
WorkingDirectory=/opt/runners/%i
ExecStart=/opt/runners/%i/run.sh
Restart=always
RestartSec=5
CPUWeight=50

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now gh-runner@$name
sudo systemctl status gh-runner@$name --no-pager   # active (running)
```

`CPUWeight=50`, lower than the default (100), keeps the interactive sessions ahead of the jobs when the CPU is contended.

A board runner starts after `jtagd`, which a drop-in of the instance declares:

```bash
sudo mkdir -p /etc/systemd/system/gh-runner@$name.service.d
printf '[Unit]\nAfter=jtagd.service\nWants=jtagd.service\n' | sudo tee /etc/systemd/system/gh-runner@$name.service.d/jtagd.conf
sudo systemctl daemon-reload
```

### 6.1. No resource ceiling

No runner has `CPUQuota` or `MemoryMax`, and each job uses whatever the machine has free. The CPU is shared by the Linux scheduler. Memory is not shared, and when it runs out the kernel kills a process. For it to kill those of the job, and not an ssh session or `jtagd`, every runner gets an OOM priority drop-in:

```bash
for u in $(systemctl list-units 'gh-runner@*' --no-legend --plain | awk '{print $1}'); do
  d=/etc/systemd/system/$u.d
  sudo mkdir -p "$d"
  printf '[Service]\nOOMScoreAdjust=500\n' | sudo tee "$d/oom.conf" >/dev/null
done
sudo systemctl daemon-reload
```

The processes the runner starts inherit `OOMScoreAdjust`, but a Docker container does not, because `dockerd` creates it outside the service of the runner. For the container, use `--oom-score-adj` in its options. Check the value with `systemctl show -p OOMScoreAdjust gh-runner@<name>`.

## 7. Restarting the JTAG server

A `jtagd` in a bad state, for example because of a session that did not finish, can make `jtagconfig` report a broken chain, and restarting it fixes that case. A chain broken by the board itself needs a power cycle of the board, which no restart fixes.

Since `jtagd` runs as the `runner` user (section 4.1), the runner stops it with `killall jtagd`, without `sudo` and without a sudoers rule, and systemd starts it again after the 5 seconds of `RestartSec`. A job can check the chain before using the board, restart `jtagd` once and check again before failing:

```bash
killall jtagd
sleep 6          # the 5 seconds of RestartSec plus the start
jtagconfig
```

Only the steps that run on the host can do this: a step inside the container does not share the processes of the host. There is one `jtagd` per machine, so restarting it also drops the session of a job on another board of the same machine.

## 8. What the container of a board job needs

A job that touches the board runs in a CI image and has to give its container the following. The complete command, with the error that appears when `jtagd` is not running on the host, is in section 7 of [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md).

| Need | How |
| :--- | :--- |
| Quartus | mount `/opt/altera_lite` read-only at the same path and put `/opt/altera_lite/25.1std/quartus/bin` on the `PATH` |
| The `jtagd` of the host | share the network of the host (`--network host`), so `localhost:1309` is the server of section 4.1 |
| Files owned by the invoking user | `--user "$(id -u):$(id -g)"` and a writable `HOME`, for example `-e HOME=/tmp/h` |
| A Docker daemon that remaps users | add `--userns=host`, which the daemon requires together with `--network host` |

The image needs no Quartus of its own: it carries the system library the command-line tools of Quartus link against.

## 9. One compute load at a time

The `compute` runner carries the three labels `formal`, `build` and `cert`. Since a runner executes one job at a time, two jobs of these three classes never run together on the same machine, with no lock and no hook, and a job of any of the three goes to the first free `compute` runner among the machines. The certification of one base platform takes about 15 GiB of memory, and two such jobs together exceed the 31 GiB of a machine with that memory.

A machine runs two compute jobs at the same time with a second `compute` runner, named `<host>-compute-2`, registered as in section 5.

## 10. Workflows

`runs-on` picks the class by label.

```yaml
formal:
  runs-on: [self-hosted, formal]

certification:
  runs-on: [self-hosted, cert]

unit-tests:
  runs-on: [self-hosted, sim]

board:
  runs-on: [self-hosted, DE2-115]

specific-machine:
  runs-on: [self-hosted, DE2-115, D-20003264-LINUX]
```

The `arm64` build uses `runs-on: ubuntu-26.04-arm`, and the `amd64` one uses `[self-hosted, build]`. With two boards of the same kind on different machines, such as the `DE2-115`, the label of the machine pins the job to one of them. A workflow that changes `runs-on` changes `.github/`.

## 11. Security

- The `Workstation` *runner group* stays restricted to **Selected repositories**, never "All repositories" (section 5.1).
- The repos of the org are public. In **Settings → Actions → General** of each repo, **Fork pull request workflows** requires **Require approval for all external contributors** before any self-hosted runner runs an outside PR.
- In **Org Settings → Actions → General → Runners**, **Repository self-hosted runners** stays on **Selected repositories** with no repository checked, so no repository registers a runner of its own outside the group.
- The `_work` of a persistent runner is not cleaned between jobs. The workflow that uses the runner must clean what it creates.
- The `docker` group of the `runner` user is equivalent to root on the machine (section 3), so only trusted repositories join the group.

### 11.1. Secret to confirm manual runs (optional)

Configured per repository on GitHub, it is a second gate for runs started by hand with `workflow_dispatch`, useful if more people get write access to the repo without being meant to trigger physical hardware.

- Repo → **Settings → Secrets and variables → Actions → New repository secret**.
- Name `FPGA_RUN_SECRET`, with any phrase as the value (for example `openssl rand -hex 32`).
- The workflow compares an input `confirm` against this secret before any step that touches the board.

## 12. Updating, removing and moving

To remove a runner, stop the service, unregister it with the removal token from the runner page and delete the folder:

```bash
sudo systemctl stop gh-runner@<name>
sudo -u runner HOME=/opt/runners bash -lc "cd /opt/runners/<name> && ./config.sh remove --token <REMOVAL_TOKEN>"
sudo systemctl disable gh-runner@<name>
sudo rm -rf /opt/runners/<name>
```

The runner program updates itself. To pin a version or swap the package, stop the service, extract the new `tar.gz` over the folder and start the service again.

### 12.1. Moving a board

Moving a board to another machine means removing its runner on the old machine and registering a new one on the new machine. A job in progress fails when the runner stops, and the failure only shows in GitHub after a few minutes. Re-run the job with **Re-run job**, and the jobs still in the queue wait for the new runner to become **Idle**.

On the old machine, remove the `<old-host>-<board>-1` runner as in section 12. If the machine is left with no board, also stop the JTAG server with `sudo systemctl disable --now jtagd`.

On the new machine:

1. If it had no board yet, do sections 2, 3 and 4 and confirm that Quartus Lite is installed.
2. Plug the board in and check that `jtagconfig` lists its IDCODE and that `cable <IDCODE>` prints the cable.
3. Register the runner with section 5, with the name `<new-host>-<board>-1` and the labels `self-hosted,<new-host>,<board>,quartus` in the `Workstation` group.
4. Start the service with section 6, with the `jtagd` drop-in.
5. Run the checklist of section 13 for that board.

A `runs-on` that lists the label of the machine, such as `[self-hosted, DE2-115, D-20003264-LINUX]`, no longer finds a runner after the move. The ones that list only the board, such as `[self-hosted, DE0-Nano]`, stay correct.

## 13. Final checklist

- [ ] `systemctl status gh-runner@<name>` shows `active (running)` for each runner
- [ ] Each runner shows up as **Idle** in the org under Settings → Actions → Runners, with the labels of section 5 and in the `Workstation` group
- [ ] The `Workstation` group is restricted to **Selected repositories**, not "All repositories"
- [ ] Fork PR approval is on in every repository of the group
- [ ] `systemctl show -p MemoryMax,CPUQuotaPerSecUSec,OOMScoreAdjust gh-runner@<name>` shows `infinity`, `infinity` and `500`
- [ ] On machines with a board, `ss -ltn | grep ':1309 '` shows `jtagd` and `cable <IDCODE>` prints the cable of each board
- [ ] On machines with a board, `sudo -u runner killall jtagd` and, 6 seconds later, `ss -ltn | grep ':1309 '` shows the server again
- [ ] A user without `sudo` lists `/opt/runners` and reads the files of the runners, and `stat -c %A /opt/runners/*/.credentials_rsaparams` shows `-rw-------`
- [ ] A test job per label runs and prints the name of the runner
- [ ] Docker works as `runner`: `sudo -u runner docker run --rm ghcr.io/insper-riscv/ci-elf:latest riscv32-unknown-elf-gcc --version`
- [ ] Quartus runs in the container, with the options of section 8: `quartus_pgm --version` prints the version
- [ ] The manual confirmation secret is configured, if applicable

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
