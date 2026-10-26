# ci-asm

`ghcr.io/<organização>/ci-asm` é o nível 2 das imagens de CI, com o que um teste em assembly ou em C precisa. Ela é a [`ci-vhdl`](ci-vhdl.md) mais o GCC RISC-V com a picolibc ([`base-gcc`](base-gcc.md)) e o Spike ([`base-spike`](base-spike.md)). As imagens [`ci-elf`](ci-elf.md) e seguintes são construídas sobre ela. A visão geral das imagens está em [README.md](README.md).

## 1. O que acrescenta à ci-vhdl

| Componente | Detalhe | Caminho |
| :--- | :--- | :--- |
| GCC RISC-V | alvo `riscv32-unknown-elf`, com as variantes de biblioteca `rv32i/ilp32`, `rv32i_zmmul/ilp32`, `rv32im/ilp32`, `rv32imf/ilp32f` e `rv32imfd/ilp32d` | `/opt/riscv-foundation/riscv32-elf` |
| picolibc | a biblioteca C desse GCC, vinda da `base-picolibc`, compilada com ele | `/opt/riscv-foundation/riscv32-elf` |
| Spike | com o módulo de depuração em `0x70000000` | `/opt/riscv-foundation/spike` |
| `libmpc3` e `libmpfr6` | as bibliotecas que o `cc1` do GCC RISC-V liga, do Ubuntu | `/usr/lib` |

O GCC, a picolibc e o Spike já estão no `PATH`. Os executáveis do GCC RISC-V têm os nomes `riscv32-unknown-elf-*`, então não conflitam com o `gcc` do host que vem da `ci-vhdl`.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `Dockerfile.asm-img` |
| Workflow | `ASM image` |
| Tags | `latest`, `sha-<commit do Infra>` e `vhdl-<12 do digest>-gcc-<7>-picolibc-<7>-spike-<7>` |
| Rótulos | `riscv-gnu-toolchain.commit`, `picolibc.commit` e `riscv-isa-sim.commit` |
| Agenda | quando `VHDL image`, `GCC image` ou `Spike image` termina |

A picolibc é a `base-picolibc` mais recente. O workflow só monta quando essa imagem de picolibc foi compilada com a `base-gcc` mais recente; se uma `GCC image` ou uma `Picolibc image` está em execução, ele espera.

Antes de publicar, o workflow confere que os commits deixados na imagem (os arquivos `.tag`) são os fixados, que o GCC compila com a picolibc, que ele tem as cinco variantes de biblioteca e que o Spike não coloca o módulo de depuração no endereço `0`.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |

## 4. Construindo localmente

```bash
docker build -f Dockerfile.asm-img -t ci-asm \
  --build-arg VHDL_IMAGE=ci-vhdl --build-arg GCC_IMAGE=base-gcc --build-arg SPIKE_IMAGE=base-spike .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `VHDL_IMAGE` | `ci-vhdl:latest` | o nível abaixo |
| `GCC_IMAGE` | `base-gcc:latest` | de onde vem o GCC |
| `PICOLIBC_IMAGE` | `base-picolibc:latest` | de onde vem a picolibc |
| `SPIKE_IMAGE` | `base-spike:latest` | de onde vem o Spike |

## 5. Verificando

```bash
docker run --rm ci-asm riscv32-unknown-elf-gcc --version
docker run --rm ci-asm riscv32-unknown-elf-gcc -print-multi-lib
docker run --rm ci-asm spike --help
```

O segundo comando deve imprimir cinco linhas, uma para cada variante.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
