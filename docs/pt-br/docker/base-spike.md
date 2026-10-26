# base-spike

`ghcr.io/<organização>/base-spike` contém o Spike, o simulador de referência do RISC-V, em `/opt/riscv-foundation/spike`. A [`ci-asm`](ci-asm.md) copia esse diretório. A visão geral das imagens está em [README.md](README.md), e o passo a passo de construir o Spike à mão está em [SPIKE_SETUP.md](../manual/SPIKE_SETUP.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| Spike | com o módulo de depuração movido do endereço `0x0` para `0x70000000`, para não sobrepor a memória do programa |
| `/opt/riscv-foundation/spike/.tag` | o commit do `riscv-isa-sim` de que a instalação foi construída, com o sufixo `-debug-start` |

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/spike/Dockerfile` |
| Workflow | `Spike image` |
| Tags | `<commit>` e `latest` |
| Rótulo | `riscv-isa-sim.commit` |
| Agenda | todo dia, 03:00 UTC |

O Spike não tem release a seguir (a última, `v1.1.0`, é de 2021). O run agendado usa o commit mais recente da branch `master` do `riscv-isa-sim` em que os workflows `Continuous Integration` e `Debug Quick Test` passaram, e espera até 60 minutos por um CI em andamento.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit do `riscv-isa-sim`; vazio, o mais recente com CI verde |
| `ignore_ci` | sem `commit`, usa a ponta da branch padrão, qualquer que seja o resultado do CI dela |
| `force` | reconstrói e republica mesmo que a imagem desse commit já exista |

## 4. Construindo localmente

```bash
docker build -f docker/base/spike/Dockerfile -t base-spike \
  --build-arg RISCV_ISA_SIM_COMMIT="$(git ls-remote https://github.com/riscv-software-src/riscv-isa-sim HEAD | cut -f1)" .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `RISCV_ISA_SIM_COMMIT` | nenhum | o commit do `riscv-isa-sim` a construir |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
