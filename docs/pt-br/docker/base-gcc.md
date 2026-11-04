# base-gcc

`ghcr.io/<organização>/base-gcc` contém o GCC RISC-V, sem biblioteca C, em `/opt/riscv-foundation/riscv32-elf`. A [`base-picolibc`](base-picolibc.md) é compilada com ele, e a [`ci-elf`](ci-elf.md) copia as duas. A visão geral das imagens está em [README.md](README.md), e o passo a passo de construir o GCC à mão está em [GCC_SETUP.md](../manual/GCC_SETUP.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| binutils | o assembler, o linker e o arquivador para o alvo `riscv32-unknown-elf` |
| GCC RISC-V | alvo `riscv32-unknown-elf`, front ends C e C++, com as variantes de biblioteca da seção 1.1 |
| libgcc | a biblioteca de apoio do compilador, construída com esse compilador |
| `/opt/riscv-foundation/riscv32-elf/.tag` | duas linhas. A primeira é o commit do `riscv-gnu-toolchain` de que a instalação foi construída, e a segunda é a data desse commit, o commit curto e o número de variantes de biblioteca (`2026-10-28 (317ee3d), 192 variants`) |

### 1.1. Variantes

| Base e ponto flutuante | `-march` (cada um sem multiplicação, `_zmmul` e `m`) | `-mabi` |
| :--- | :--- | :--- |
| I, sem ponto flutuante | `rv32i`, `rv32i_zmmul`, `rv32im` | `ilp32` |
| I com F | `rv32if`, `rv32if_zmmul`, `rv32imf` | `ilp32`, `ilp32f` |
| I com F e D | `rv32ifd`, `rv32ifd_zmmul`, `rv32imfd` | `ilp32`, `ilp32f`, `ilp32d` |
| E, sem ponto flutuante | `rv32e`, `rv32e_zmmul`, `rv32em` | `ilp32e` |
| E com F | `rv32ef`, `rv32ef_zmmul`, `rv32emf` | `ilp32e` |

`_zmmul` é multiplicação em hardware e divisão em software, `m` é as duas em hardware, e o nome sem nenhum dos dois tem as duas em software. O RV32E permite só o ABI `ilp32e` (soft-float, então `float` passa em registradores inteiros mesmo com F), e esse ABI não suporta o D, então não há variante E com D. Os ABIs hard-float `ilp32f` e `ilp32d` existem só para o I. A extensão Q não tem ABI em RV32, então não tem variante.

As 24 combinações de base, multiplicação e ponto flutuante são construídas cada uma sem ou com mais três escolhas, o que dá 24 × 2 × 2 × 2 = 192 variantes, com `rv32im/ilp32` como padrão. O `scripts/gcc-multilib.sh` as lista.

| Eixo | Escolhas |
| :--- | :--- |
| Base | I, E |
| Multiplicação | nenhuma, Zmmul, M |
| Ponto flutuante | nenhum, F, F e D (D não com E) |
| A | sem, com (instruções atômicas) |
| C | sem, com (instruções compactas) |
| B | sem, com o grupo Zba, Zbb e Zbs juntos |

O nome de uma variante acrescenta as letras `a` e `c` e o sufixo `_zba_zbb_zbs` ao nome da combinação de base, então `rv32im` gera `rv32im`, `rv32ima`, `rv32imc`, `rv32imac` e as quatro com `_zba_zbb_zbs`.

Como o compilador escolhe entre as variantes está na seção 3 de [base-picolibc.md](base-picolibc.md). A `libgcc` é construída para cada variante. O compilador escreve os nomes das variantes de forma normalizada, que a seção 2.4 desse documento descreve, e `-print-multi-lib` os lista.

O build instala o binutils e o primeiro compilador da configuração da picolibc, e depois constrói a libgcc com ele; o segundo estágio do `riscv-gnu-toolchain`, que refaria o compilador e a libgcc contra a picolibc, não é executado. O `cc1` liga com `libmpc3` e `libmpfr6`, instaladas na `ci-elf`. A imagem não tem biblioteca C nem libstdc++. A picolibc vem da `base-picolibc`, e programas C++ que precisem da biblioteca padrão estão fora de escopo. Os executáveis se chamam `riscv32-unknown-elf-*`, sem conflito com o `gcc` do host.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/gcc/Dockerfile` |
| Workflow | `GCC image` |
| Tags | `<commit do GCC>` e `latest` |
| Rótulos | `riscv-gnu-toolchain.commit` e `riscv-gnu-toolchain.variants` (o número de variantes de biblioteca) |
| Agenda | todo dia, 03:00 UTC |

O GCC não tem release a seguir, então o run agendado usa o commit mais recente da branch `master` do `riscv-gnu-toolchain` em que o workflow `Build` dele passou, e constrói só se a imagem para esse commit não existe. O `Build` do upstream leva horas, então esse commit costuma estar cerca de um dia atrás da ponta, e um commit ainda em execução é pulado, não esperado. Um commit cujo `Build` falhou ou foi cancelado também é pulado. O número de variantes de biblioteca fica num rótulo porque o commit sozinho não o diz: um run com `force` que reconstrua o mesmo commit com outro número de variantes faz o `Picolibc image` e o `CI images` construírem de novo, como o `README.md` descreve.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit do `riscv-gnu-toolchain`; vazio, o mais recente cujo `Build` do upstream passou |
| `ignore_ci` | sem `commit`, usa a ponta da branch `master`, qualquer que seja o resultado do CI dela |
| `force` | reconstrói e republica mesmo que a imagem desse commit já exista |

## 4. Construindo localmente

```bash
docker build -f docker/base/gcc/Dockerfile -t base-gcc \
  --build-arg RISCV_GNU_TOOLCHAIN_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .
```

O build leva de dezenas de minutos a mais de uma hora, conforme a máquina.

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `RISCV_GNU_TOOLCHAIN_COMMIT` | nenhum | o commit do `riscv-gnu-toolchain` |
| `MULTILIB` | a lista de `scripts/gcc-multilib.sh` | as variantes, no formato da opção `--with-multilib-generator` do GCC |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
