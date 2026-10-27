# Instalação manual

Passo a passo para instalar as ferramentas da infraestrutura direto numa máquina, sem Docker. Cada guia compila ou instala uma ferramenta no mesmo diretório que as imagens Docker usam, então uma máquina instalada à mão e uma imagem têm o mesmo layout.

| Guia | Instala | Diretório |
| :--- | :--- | :--- |
| [GCC_SETUP.md](GCC_SETUP.md) | O GCC RISC-V, o binutils, o GDB e a picolibc, para as variantes das imagens | `/opt/riscv-foundation/riscv32-elf` |
| [SPIKE_SETUP.md](SPIKE_SETUP.md) | O `uv` globalmente e o simulador de referência RISC-V | `/opt/riscv-foundation/spike` |
| [GHDL_SETUP.md](GHDL_SETUP.md) | O GHDL com o backend LLVM | `/opt/ghdl` |
| [YOSYS_SETUP.md](YOSYS_SETUP.md) | O Yosys e o SymbiYosys | `/opt/yosys` |
| [PYTHON_SETUP.md](PYTHON_SETUP.md) | O `uv`, o Python, o cocotb e o `click` | `/usr/local/bin`, `/opt/uv/python` |
| [SAIL_SETUP.md](SAIL_SETUP.md) | O modelo Sail RISC-V | `/opt/riscv-foundation/sail` |
| [ACT4_SETUP.md](ACT4_SETUP.md) | Ruby, Bundler e as dependências do ACT4 | `/opt/act-bundle`, `/opt/act-uv-cache`, `/opt/act-cache` |
| [GTKWAVE_SETUP.md](GTKWAVE_SETUP.md) | O GTKWave | `/opt/gtkwave` |

## 1. Ordem sugerida

Cada ferramenta se instala sozinha, exceto o ACT4, que precisa das três antes dele. Para os testes do projeto, nesta ordem:

1. [PYTHON_SETUP.md](PYTHON_SETUP.md), [GHDL_SETUP.md](GHDL_SETUP.md) e [YOSYS_SETUP.md](YOSYS_SETUP.md), as ferramentas dos testes VHDL.
2. [GCC_SETUP.md](GCC_SETUP.md) e [SPIKE_SETUP.md](SPIKE_SETUP.md), para gerar ELFs (compilar assembly e C) e rodá-los no Spike.
3. [SAIL_SETUP.md](SAIL_SETUP.md) e [ACT4_SETUP.md](ACT4_SETUP.md), para a certificação ACT4.
4. [GTKWAVE_SETUP.md](GTKWAVE_SETUP.md), para abrir as formas de onda.

O Quartus Prime Lite do fluxo da placa se instala à parte, em [QUARTUS_INSTALL.md](../QUARTUS_INSTALL.md), e o runner self-hosted que usa essas ferramentas é configurado em [RUNNER_SETUP.md](../RUNNER_SETUP.md).

## 2. Comum aos guias

- Todos os guias cobrem distros Debian-like (`apt`) e RHEL-like (`dnf`/`yum`). Os comandos foram executados no Ubuntu 26.04 e no Rocky Linux 9, exceto o build do GHDL em distros RHEL-like, que foi executado no Fedora porque o GNAT não instala no Rocky Linux 9.
- Os scripts dos guias de GHDL, Yosys, Python, Sail, GTKWave e ACT4 rodam como root. Os que compilam uma ferramenta gravam a versão instalada num arquivo `.tag` dentro do diretório dela, e rodar um de novo nessa versão não faz nada.
- As imagens Docker que têm as mesmas ferramentas estão descritas na [visão geral das imagens](../docker/README.md).

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).