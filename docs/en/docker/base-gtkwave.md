# base-gtkwave

`ghcr.io/<organization>/base-gtkwave` holds GTKWave, the waveform viewer, in `/opt/gtkwave`. [`dev_tools`](dev-tools.md) copies that directory. The overview of the images is in [README.md](README.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| GTKWave | the head of the `lts` branch (3.3 maintenance line, GTK 3 tree), which runs natively on Wayland and on X11 |

GTKWave links against GTK 3, and `dev_tools` installs the libraries it needs.

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `docker/base/gtkwave/Dockerfile` |
| Workflow | `GTKWave image` |
| Tags | `<commit>` and `latest` |
| Label | `gtkwave.commit` |
| Schedule | every day, 03:00 UTC |

The workflow follows the `lts` branch (`BRANCH`) and builds only if the head commit has no image yet.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the commit to build; empty, the head of the `lts` branch |
| `force` | rebuild and republish even if the image for that commit exists |

## 4. Building locally

```bash
docker build -f docker/base/gtkwave/Dockerfile -t base-gtkwave \
  --build-arg GTKWAVE_COMMIT="$(git ls-remote https://github.com/gtkwave/gtkwave refs/heads/lts | cut -f1)" .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `GTKWAVE_COMMIT` | none | the GTKWave commit to build |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
