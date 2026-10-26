# base-spike

`ghcr.io/<organization>/base-spike` holds Spike, the RISC-V reference simulator, in `/opt/riscv-foundation/spike`. [`ci-asm`](ci-asm.md) copies that directory. The overview of the images is in [README.md](README.md), and the step by step of building Spike by hand is in [SPIKE_SETUP.md](../manual/SPIKE_SETUP.md).

## 1. What it holds

| Item | Detail |
| :--- | :--- |
| Spike | with its debug module moved from address `0x0` to `0x70000000`, so it does not overlap the program memory |
| `/opt/riscv-foundation/spike/.tag` | the commit of `riscv-isa-sim` the install was built from, with the suffix `-debug-start` |

## 2. Publication

| Item | Value |
| :--- | :--- |
| Recipe | `Dockerfile.spike` |
| Workflow | `Spike image` |
| Tags | `<commit>` and `latest` |
| Label | `riscv-isa-sim.commit` |
| Schedule | every day, 03:00 UTC |

Spike has no release to follow (the last, `v1.1.0`, is from 2021). The scheduled run takes the latest commit of the `master` branch of `riscv-isa-sim` on which the `Continuous Integration` and `Debug Quick Test` workflows passed, and waits up to 60 minutes for a running one.

## 3. Manual run

| Field | Meaning |
| :--- | :--- |
| `confirm` | the value of the `IMAGE_PUBLISH_SECRET` secret |
| `commit` | the `riscv-isa-sim` commit; empty, the latest one with green CI |
| `ignore_ci` | with no `commit`, take the head of the default branch whatever its CI says |
| `force` | rebuild and republish even if the image for that commit exists |

## 4. Building locally

```bash
docker build -f Dockerfile.spike -t base-spike \
  --build-arg RISCV_ISA_SIM_COMMIT="$(git ls-remote https://github.com/riscv-software-src/riscv-isa-sim HEAD | cut -f1)" .
```

| Argument | Default | Meaning |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | base image (multi-architecture) |
| `RISCV_ISA_SIM_COMMIT` | none | the `riscv-isa-sim` commit to build |

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
