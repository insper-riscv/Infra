# Infra

🌐 [Português](README.md) · [English](README.en.md)

Documentação dos requisitos e de como instalar/configurar a infraestrutura
da organização (workstations com hardware FPGA, runners self-hosted do
GitHub Actions, ferramentas compartilhadas), feita para distros Debian-like
(`apt`) e RHEL-like (`dnf`/`yum`).

## Docs

- [QUARTUS_INSTALL.md](docs/pt-br/QUARTUS_INSTALL.md): instalar o Quartus Prime Lite
  globalmente numa workstation (pré-requisito do runner).
- [RUNNER_SETUP.md](docs/pt-br/RUNNER_SETUP.md): configurar um runner self-hosted do
  GitHub Actions com acesso a hardware FPGA (Quartus + JTAG).
- [SPIKE_SETUP.md](docs/pt-br/SPIKE_SETUP.md): instalar `uv` globalmente e compilar o
  simulador de referência RISC-V no cache compartilhado, em distros `apt`
  e `dnf`/`yum`.
- [GCC_SETUP.md](docs/pt-br/GCC_SETUP.md): compilar o GCC RISC-V a partir do
  código-fonte no mesmo cache compartilhado, em distros `apt` e `dnf`/`yum`.
- [TOOLCHAIN_IMAGE.md](docs/pt-br/TOOLCHAIN_IMAGE.md): imagens Docker do GCC
  RISC-V (picolibc), do Spike e uma completa com GHDL, GCC, Spike e `uv`,
  construídas e publicadas pelo CI, para quem não quer instalar isso numa
  máquina.
- [DEVTOOLS_IMAGE.md](docs/pt-br/DEVTOOLS_IMAGE.md): `dev_tools`, a imagem do
  toolchain mais o usuário `dev`, o Python, o GTKWave (Wayland nativo) e as
  ferramentas de compilação, para um Dev Container.

## Ordem sugerida

Cada doc já linka seus próprios pré-requisitos, mas a ordem natural para uma
workstation nova é:

1. [QUARTUS_INSTALL.md](docs/pt-br/QUARTUS_INSTALL.md)
2. [RUNNER_SETUP.md](docs/pt-br/RUNNER_SETUP.md)
3. [GCC_SETUP.md](docs/pt-br/GCC_SETUP.md)
4. [SPIKE_SETUP.md](docs/pt-br/SPIKE_SETUP.md)

## Escopo

- **[QUARTUS_INSTALL.md](docs/pt-br/QUARTUS_INSTALL.md)**: instala o
  Quartus Prime Lite globalmente na workstation. Sem ele, não tem como
  sintetizar nem programar o hardware que o `RV32IM` implementa.
- **[RUNNER_SETUP.md](docs/pt-br/RUNNER_SETUP.md)**: configura um runner
  self-hosted do GitHub Actions com acesso a hardware FPGA (Quartus +
  JTAG). Sem ele, não tem como rodar os testes de hardware real do
  `Tests`. O runner também precisa de Docker, para a imagem de toolchain.
- **[GCC_SETUP.md](docs/pt-br/GCC_SETUP.md)**: compila o GCC RISC-V
  (binutils, compilador, picolibc, gdb) para o alvo `rv32im`. É com ele que a
  [imagem de toolchain](docs/pt-br/TOOLCHAIN_IMAGE.md) é construída; instale-o
  numa workstation só para compilar fora da imagem.
- **[SPIKE_SETUP.md](docs/pt-br/SPIKE_SETUP.md)**: compila o Spike, o
  simulador de referência RISC-V. Como o GCC, ele está na imagem de
  toolchain; o setup serve para rodá-lo fora da imagem.

Esses docs juntos são a base da qual `RV32`, `Tests` e `Tools` dependem
para funcionar como pretendido.

## O que as imagens contêm

As duas são publicadas para `linux/amd64` e `linux/arm64`, com as mesmas versões em cada uma, e a
`dev_tools` é a imagem do toolchain mais o que está listado abaixo dela. Como cada item é atualizado
está no [TOOLCHAIN_IMAGE.md](docs/pt-br/TOOLCHAIN_IMAGE.md) e no
[DEVTOOLS_IMAGE.md](docs/pt-br/DEVTOOLS_IMAGE.md), e por que cada versão foi escolhida está na
[seção 8 do TOOLCHAIN_IMAGE.md](docs/pt-br/TOOLCHAIN_IMAGE.md#8-por-que-cada-versão).

### Imagem do toolchain (`ghcr.io/insper-riscv/infra-toolchain`)

| Item | Versão |
| :--- | :--- |
| Ubuntu | 26.04 LTS |
| GHDL (backend LLVM) | 6.0.0 |
| LLVM (biblioteca em que o backend do GHDL roda) | 21.1.8 |
| GCC RISC-V (`rv32im`, `ilp32`: sem CSR, sem F nem D) | 16.1.0 (commit `d118e53` do `riscv-gnu-toolchain`) |
| picolibc (biblioteca C do GCC RISC-V, uma variante para o mesmo `rv32im`: sem CSR, ponto flutuante em software) | 1.8.11 |
| Spike | 1.1.1-dev (commit `fdc1ffa` do `riscv-isa-sim`, módulo de debug em `0x70000000`) |
| `uv` | 0.12.23 |
| Python | 3.14.8 |
| cocotb | 2.1.0 |
| `gcc` e `g++` (do host) | 15.2.0 |
| `git` | 2.53.0 |
| `make` | 4.4.1 |
| `curl` | 8.18.0 |

### Imagem de ferramentas de desenvolvimento (`ghcr.io/insper-riscv/dev_tools`)

Tudo o que está na imagem do toolchain, mais:

| Item | Versão |
| :--- | :--- |
| GTKWave (árvore GTK 3, Wayland e X11) | 3.3.116 |
| GTK 3 | 3.24.52 |
| `gnat` | 14 |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](LICENSE).
