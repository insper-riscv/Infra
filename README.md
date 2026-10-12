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
- [TOOLCHAIN_IMAGE.md](docs/pt-br/TOOLCHAIN_IMAGE.md): imagens Docker,
  construídas e publicadas pelo CI, de cada componente (GHDL, GCC RISC-V com
  picolibc, Spike, e Yosys com SymbiYosys) e uma completa com eles mais `uv`,
  Python e cocotb, para quem não quer instalar isso numa máquina. Mostra
  também como usar o Quartus do host dentro da imagem.
- [DEVTOOLS_IMAGE.md](docs/pt-br/DEVTOOLS_IMAGE.md): `dev_tools`, a imagem do
  toolchain mais o usuário `dev`, o Python, o GTKWave (Wayland nativo) e as
  ferramentas de compilação, para um Dev Container.

## Ordem sugerida

Cada doc já linka seus próprios pré-requisitos, mas a ordem natural para uma
workstation nova é:

1. [QUARTUS_INSTALL.md](docs/pt-br/QUARTUS_INSTALL.md)
2. [RUNNER_SETUP.md](docs/pt-br/RUNNER_SETUP.md)
3. [TOOLCHAIN_IMAGE.md](docs/pt-br/TOOLCHAIN_IMAGE.md): o GCC, o Spike, o GHDL, o
   Yosys e o resto vêm na imagem, com o Docker como único requisito.

[GCC_SETUP.md](docs/pt-br/GCC_SETUP.md) e [SPIKE_SETUP.md](docs/pt-br/SPIKE_SETUP.md)
servem só para compilar essas ferramentas na própria máquina, fora da imagem.

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

## Como as imagens se mantêm atualizadas

Cada componente tem uma imagem própria, com um workflow que segue a release
mais recente de uma série fixa (ou, no Spike, o commit mais recente cujo CI
próprio está verde), e a imagem de toolchain os monta quando um deles muda. Os
detalhes e os comandos estão em [TOOLCHAIN_IMAGE.md](docs/pt-br/TOOLCHAIN_IMAGE.md).

| Componente | Segue | Atualizado por |
| :--- | :--- | :--- |
| GHDL | o `6.x.y` mais recente | `GHDL image` |
| GCC RISC-V | o HEAD do `riscv-gnu-toolchain`, construído do segundo estágio contra a picolibc compilada | `GCC image` |
| picolibc | o `1.x.y` mais recente, compilada pelo GCC publicado antes dela | `Picolibc image`, que faz a imagem do GCC ser construída de novo |
| Spike | o commit mais recente da `master` em que o CI dele passou (não tem release recente) | `Spike image` |
| Yosys e SymbiYosys | a `v0.N` mais recente, lançadas em passo | `Yosys image` |
| `uv` | o `0.x.y` mais recente | `Toolchain image`, rodado à mão |

## O que as imagens contêm

As duas são publicadas para `linux/amd64` e `linux/arm64`, com as mesmas versões em cada uma, e a
`dev_tools` é a imagem do toolchain mais o que está listado abaixo dela. Como cada item é atualizado
está no [TOOLCHAIN_IMAGE.md](docs/pt-br/TOOLCHAIN_IMAGE.md) e no
[DEVTOOLS_IMAGE.md](docs/pt-br/DEVTOOLS_IMAGE.md), e por que cada versão foi escolhida está na
[seção 8 do TOOLCHAIN_IMAGE.md](docs/pt-br/TOOLCHAIN_IMAGE.md#8-por-que-cada-versão).

### Imagem do toolchain (`ghcr.io/insper-riscv/infra-toolchain`)

| Item | Versão | Por que está na imagem |
| :--- | :--- | :--- |
| Ubuntu | 26.04 LTS | base de todas as imagens: a última versão de suporte longo, com builds `amd64` e `arm64`, e a que o GHDL 6.0.0 foi compilado e testado |
| GHDL (backend LLVM) | 6.0.0 | simula o VHDL-2008 do core; o backend LLVM porque o `mcode` roda só em x86, e uma simulação deve se comportar igual num PC e numa máquina ARM |
| LLVM (`libllvm21`, biblioteca em que o backend do GHDL roda) | 21.1.8 | o gerador de código com que o GHDL é ligado |
| GCC RISC-V (`rv32im`, `ilp32`: sem CSR, sem F nem D) | 16.1.0 (commit `d118e53` do `riscv-gnu-toolchain`) | compila os programas de teste do core |
| picolibc (biblioteca C do GCC RISC-V, uma variante para o mesmo `rv32im`: sem CSR, ponto flutuante em software) | 1.8.12 | a biblioteca C com que esses programas são ligados; compilada pela própria imagem com o GCC publicado antes dela; o GCC é então construído contra ela, a partir do segundo estágio |
| Spike | 1.1.1-dev (commit `f8a060b` do `riscv-isa-sim`, módulo de debug em `0x70000000`) | o simulador de referência que produz o resultado golden de cada programa; o módulo de debug é movido para não sobrepor a boot ROM |
| `uv` | 0.13.0 | instala o Python e as dependências de cada projeto (`uv sync`); a imagem não tem `pip` |
| Python | 3.14.8 | a versão que os projetos exigem (`>=3.14,<3.15`) |
| cocotb | 2.1.0 | os testbenches, escritos em Python; é ele que fixa a versão do Python |
| `gcc` e `g++` (do host) | 15.2.0 | o `gcc` liga o executável que o GHDL elabora; o `g++` compila o cocotb no `arm64`, onde ele não tem wheel |
| `libc6-dev` | 2.43 | os cabeçalhos e bibliotecas C de que o `gcc` precisa para ligar esse executável e para compilar código VHPIDIRECT |
| `zlib1g-dev` | 1.3.1 | o executável que o GHDL elabora é ligado com `-lz` |
| `libgnat-14` | 14.3.0 | o runtime de Ada em que o GHDL, escrito em Ada, roda |
| `libedit2` | 3.1 | a biblioteca de edição de linha com que o GHDL é ligado |
| `libmpc3` e `libmpfr6` | 1.3.1 e 4.2.2 | as bibliotecas de aritmética com que o compilador propriamente dito (`cc1`) do GCC RISC-V é ligado |
| `git` | 2.53.0 | o checkout de um workflow e os clones dos repositórios irmãos |
| `make` | 4.4.1 | os Makefiles dos projetos e o `make` do próprio ACT4 |
| `curl` | 8.18.0 | instaladores e downloads |
| `ca-certificates` | 20260601 | os certificados confiáveis, para o `curl` e o `git` verificarem servidores HTTPS |
| `libglib2.0-0t64` | 2.88.0 | `libglib-2.0` e `libgthread-2.0`, com que as ferramentas de linha de comando de uma instalação do Quartus montada do host são ligadas |
| Yosys | 0.69 | compilado do código-fonte (a release mais recente da série 0); lê o netlist Verilog que o GHDL sintetiza a partir do VHDL, para a verificação formal |
| SymbiYosys (`sby`) | v0.69 | compilado com o Yosys, com que é lançado em passo; executa o Yosys e os solvers para provar propriedades de um bloco |
| `libreadline8t64`, `libtcl8.6` e `libffi8` | 8.3, 8.6.17 e 3.5.2 | as bibliotecas com que o Yosys é ligado |
| `z3` e `boolector` | 4.13.3 e 1.5.118 | os solvers SMT que o SymbiYosys usa |
| `click` | 8.5.0 | a biblioteca Python que o `sby` importa |

### Imagem de ferramentas de desenvolvimento (`ghcr.io/insper-riscv/dev_tools`)

Tudo o que está na imagem do toolchain, mais:

| Item | Versão | Por que está na imagem |
| :--- | :--- | :--- |
| GTKWave (árvore GTK 3, Wayland e X11) | 3.3.116 | abre as formas de onda (`.ghw`, `.fst`) de uma simulação |
| GTK 3 (`libgtk-3-0t64`) | 3.24.52 | o toolkit em que o GTKWave roda, com os backends Wayland e X11 |
| `libjudydebian1`, `libbz2-1.0` e `liblzma5` | 1.0.5, 1.0.8 e 5.8.3 | bibliotecas com que o GTKWave é ligado (arrays Judy, bzip2 e xz) |
| `adwaita-icon-theme` e `shared-mime-info` | 50.0 e 2.4 | os ícones e a base de tipos MIME que o GTK lê |
| `build-essential` e `pkg-config` | 12.12 e 2.5.1 | compilam o C dos projetos que o têm e acham as flags de uma biblioteca |
| `gnat` | 14 | o compilador e o runtime de Ada, para compilar o GHDL ou código Ada no ambiente de desenvolvimento |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](LICENSE).
