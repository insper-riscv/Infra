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

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](LICENSE).
