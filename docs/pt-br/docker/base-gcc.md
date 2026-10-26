# base-gcc

`ghcr.io/<organização>/base-gcc` contém o GCC RISC-V, sem biblioteca C, em `/opt/riscv-foundation/riscv32-elf`. A [`base-picolibc`](base-picolibc.md) é compilada com ele, e a [`ci-asm`](ci-asm.md) copia as duas. A visão geral das imagens está em [README.md](README.md), e o passo a passo de construir o GCC à mão está em [GCC_SETUP.md](../manual/GCC_SETUP.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| binutils | o assembler, o linker e o arquivador para o alvo `riscv32-unknown-elf` |
| GCC RISC-V | alvo `riscv32-unknown-elf`, front ends C e C++, com as variantes de biblioteca da seção 1.1 |
| libgcc | a biblioteca de apoio do compilador, construída com esse compilador |
| `/opt/riscv-foundation/riscv32-elf/.tag` | o commit do `riscv-gnu-toolchain` de que a instalação foi construída |

### 1.1. Variantes

| `-march` | `-mabi` | Multiplicação e divisão inteiras | Ponto flutuante |
| :--- | :--- | :--- | :--- |
| `rv32i` | `ilp32` | em software | em software |
| `rv32i_zmmul` | `ilp32` | multiplicação em hardware, divisão em software | em software |
| `rv32im` (o padrão) | `ilp32` | em hardware | em software |
| `rv32imf` | `ilp32f` | em hardware | precisão simples em hardware |
| `rv32imfd` | `ilp32d` | em hardware | precisão simples e dupla em hardware |

Uma biblioteca feita para menos extensões roda num núcleo com mais extensões, e o contrário não vale, então cada núcleo usa a variante que corresponde ao que ele tem, ou qualquer variante que seja subconjunto dela. O compilador escolhe a variante pelo `-march` e `-mabi` informados e pega a maior variante que seja subconjunto do pedido: `rv32ic` pega a `rv32i`, e `rv32imc` e `rv32ima` pegam a `rv32im`. As variantes com ponto flutuante não se ligam com as inteiras, porque o ABI muda como `float` e `double` são passados. A `libgcc` é construída para cada variante. O compilador mostra a variante com F com `zicsr` e `zmmul` no nome, porque o F exige o Zicsr; os nomes são normalizados pelo compilador, e `-print-multi-lib` os lista.

O build instala o binutils e o primeiro compilador da configuração da picolibc, e depois constrói a libgcc com ele; o segundo estágio do `riscv-gnu-toolchain`, que refaria o compilador e a libgcc contra a picolibc, não é executado. O `cc1` liga com `libmpc3` e `libmpfr6`, instaladas na `ci-asm`. A imagem não tem biblioteca C nem libstdc++. A picolibc vem da `base-picolibc`, e programas C++ que precisem da biblioteca padrão estão fora de escopo. Os executáveis se chamam `riscv32-unknown-elf-*`, sem conflito com o `gcc` do host.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/gcc/Dockerfile` |
| Workflow | `GCC image` |
| Tags | `<commit do GCC>` e `latest` |
| Rótulo | `riscv-gnu-toolchain.commit` |
| Agenda | todo dia, 03:00 UTC |

O GCC não tem release a seguir, então o run agendado usa o commit mais recente da branch `master` do `riscv-gnu-toolchain` em que o workflow `Build` dele passou, e constrói só se a imagem para esse commit não existe. O `Build` do upstream leva horas, então esse commit costuma estar cerca de um dia atrás da ponta, e um commit ainda em execução é pulado, não esperado. Um commit cujo `Build` falhou ou foi cancelado também é pulado.

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
| `MULTILIB` | as variantes acima | as variantes, no formato da opção `--with-multilib-generator` do GCC |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
