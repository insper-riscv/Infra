# base-picolibc

`ghcr.io/<organização>/base-picolibc` contém os arquivos que a picolibc instala no sysroot do GCC, sob `/opt/riscv-foundation/riscv32-elf`. É compilada com a [`base-gcc`](base-gcc.md), e a [`ci-elf`](ci-elf.md) a copia sobre o prefixo do GCC. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| picolibc | a biblioteca C compilada pelo GCC da `base-gcc` mais recente, instalada no sysroot, uma vez para cada uma das 192 variantes desse GCC (seção 2.1) |

O arquivo `/opt/riscv-foundation/riscv32-elf/.picolibc.tag` tem duas linhas. A primeira é o commit da picolibc, e a segunda é a versão, o commit curto e o número de variantes de biblioteca (`1.8.12 (2ae376c), 192 variants`).

A picolibc é compilada por um cross compiler, então o build usa a imagem de GCC mais recente. A imagem leva o commit desse GCC no rótulo `riscv-gnu-toolchain.commit`, e um GCC novo gera um build novo da picolibc.

## 2. Variantes

### 2.1. O que roda em hardware e o que roda em software

Cada linha é uma combinação de base, multiplicação e ponto flutuante, construída em oito versões (seção 2.2), e cada versão é uma biblioteca instalada no sysroot. Uma operação marcada como software é uma chamada a uma rotina da `libgcc` (por exemplo `__mulsi3`, `__divsi3`, `__addsf3` e `__adddf3`), então um núcleo sem a extensão ainda executa o programa, só que mais devagar.

| `-march` | `-mabi` | Registradores inteiros | Multiplicação | Divisão | Precisão simples (`float`) | Precisão dupla (`double`) |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- |
| `rv32i` | `ilp32` | 32 | software | software | software | software |
| `rv32if` | `ilp32` | 32 | software | software | hardware | software |
| `rv32if` | `ilp32f` | 32 | software | software | hardware | software |
| `rv32ifd` | `ilp32` | 32 | software | software | hardware | hardware |
| `rv32ifd` | `ilp32f` | 32 | software | software | hardware | hardware |
| `rv32ifd` | `ilp32d` | 32 | software | software | hardware | hardware |
| `rv32i_zmmul` | `ilp32` | 32 | hardware | software | software | software |
| `rv32if_zmmul` | `ilp32` | 32 | hardware | software | hardware | software |
| `rv32if_zmmul` | `ilp32f` | 32 | hardware | software | hardware | software |
| `rv32ifd_zmmul` | `ilp32` | 32 | hardware | software | hardware | hardware |
| `rv32ifd_zmmul` | `ilp32f` | 32 | hardware | software | hardware | hardware |
| `rv32ifd_zmmul` | `ilp32d` | 32 | hardware | software | hardware | hardware |
| `rv32im` (default) | `ilp32` | 32 | hardware | hardware | software | software |
| `rv32imf` | `ilp32` | 32 | hardware | hardware | hardware | software |
| `rv32imf` | `ilp32f` | 32 | hardware | hardware | hardware | software |
| `rv32imfd` | `ilp32` | 32 | hardware | hardware | hardware | hardware |
| `rv32imfd` | `ilp32f` | 32 | hardware | hardware | hardware | hardware |
| `rv32imfd` | `ilp32d` | 32 | hardware | hardware | hardware | hardware |
| `rv32e` | `ilp32e` | 16 | software | software | software | software |
| `rv32ef` | `ilp32e` | 16 | software | software | hardware | software |
| `rv32e_zmmul` | `ilp32e` | 16 | hardware | software | software | software |
| `rv32ef_zmmul` | `ilp32e` | 16 | hardware | software | hardware | software |
| `rv32em` | `ilp32e` | 16 | hardware | hardware | software | software |
| `rv32emf` | `ilp32e` | 16 | hardware | hardware | hardware | software |

As colunas decorrem do nome do `-march`.

| Parte do nome | Significado |
| :--- | :--- |
| `rv32i` | 32 registradores inteiros (`x0` a `x31`) |
| `rv32e` | 16 registradores inteiros (`x0` a `x15`) |
| `_zmmul` | multiplicação em hardware, divisão em software |
| `m` após a base | multiplicação e divisão em hardware |
| `f` | precisão simples em hardware (traz também o `zicsr`, que o compilador acrescenta ao nome) |
| `fd` | precisão simples e dupla em hardware |

### 2.2. As extensões A, C e B

Cada linha da seção 2.1 é construída em oito versões, uma para cada escolha de A, C e B. Uma variante com uma extensão tem código que a usa, então roda só num núcleo que tenha essa extensão.

| Extensão | O que o código da biblioteca usa | Efeito |
| :--- | :--- | :--- |
| A | instruções atômicas (`lr`, `sc` e a família `amo`) | um pedido com A pega só uma variante com A, e um pedido sem A pega só uma variante sem A |
| C | instruções compactas de 16 bits | código menor |
| B | as instruções de Zba, Zbb e Zbs, como soma com deslocamento, rotação, contagem de bits e operações de um bit | código menor e mais rápido nas rotinas que as usam |

As três extensões do B são uma escolha só, então uma variante tem todas ou nenhuma, e um pedido só com Zba e Zbb pega a variante sem B.

### 2.3. ABIs

O ABI decide onde `float` e `double` são passados, então uma biblioteca só se liga com código feito para o mesmo ABI.

| `-mabi` | Base | `float` | `double` | Exige |
| :--- | :--- | :--- | :--- | :--- |
| `ilp32` | I | registradores inteiros | pares de registradores inteiros | nada |
| `ilp32f` | I | registradores de ponto flutuante | pares de registradores inteiros | F |
| `ilp32d` | I | registradores de ponto flutuante | registradores de ponto flutuante | F e D |
| `ilp32e` | E | registradores inteiros | pares de registradores inteiros | nada |

`ilp32` e `ilp32e` são ABIs soft-float. Com F ou D presentes a aritmética dentro de uma função continua usando o hardware, e só as chamadas entre funções passam os valores em registradores inteiros. O RV32E tem só o `ilp32e`, então não existe variante E de `ilp32f` nem de `ilp32d`, e o compilador rejeita o D com `ilp32e`, então as variantes E vão até o F. A extensão Q não tem ABI em RV32 e não tem variante.

### 2.4. Nomes na árvore instalada

O compilador escreve o nome de cada variante de forma normalizada, e esse nome é o diretório da variante sob `lib` no sysroot e o que `-print-multi-lib` lista. Ele mantém as letras do nome e acrescenta as extensões que elas implicam.

| Letra no nome | O que o compilador acrescenta |
| :--- | :--- |
| `f` | `_zicsr` |
| `m` | `_zmmul` |
| `a` | `_zaamo_zalrsc` |
| `c` | `_zca`, mais `_zcf` com F e `_zcd` com D |
| o grupo B | nada, o nome já tem `_zba_zbb_zbs` |

A extensão acrescentada para o `m` não é a variante `_zmmul` da seção 2.1. A extensão M inclui o Zmmul (a multiplicação) e acrescenta a divisão, então o compilador lista `_zmmul` no nome de toda variante que tem `m`, e uma variante só com a multiplicação tem `_zmmul` e não tem `m`. As extensões acrescentadas vêm depois das letras, na ordem `_zicsr`, `_zmmul`, `_zaamo_zalrsc`, `_zca`, `_zcd`, `_zcf` e `_zba_zbb_zbs`. A variante `rv32im/ilp32` é o padrão do compilador, então é instalada na raiz de `lib` e não tem diretório próprio.

| Variante da seção 2.1 | Diretório |
| :--- | :--- |
| `rv32if/ilp32` | `rv32if_zicsr/ilp32` |
| `rv32imc/ilp32` | `rv32imc_zmmul_zca/ilp32` |
| `rv32ec/ilp32e` | `rv32ec_zca/ilp32e` |
| `rv32ea/ilp32e` | `rv32ea_zaamo_zalrsc/ilp32e` |
| `rv32ifdc/ilp32d` | `rv32ifdc_zicsr_zca_zcd_zcf/ilp32d` |
| `rv32imc_zba_zbb_zbs/ilp32` | `rv32imc_zmmul_zca_zba_zbb_zbs/ilp32` |
| `rv32imafdc/ilp32d` | `rv32imafdc_zicsr_zmmul_zaamo_zalrsc_zca_zcd_zcf/ilp32d` |

## 3. Como o GCC escolhe a variante

O compilador recebe `-march` e `-mabi`, ou usa o padrão do build (`rv32im` com `ilp32`) quando faltam. Ele então toma a variante por estas regras, e o `--specs=picolibc.specs` acha o `libc.a` no diretório dessa mesma variante.

1. O ABI tem de ser o da variante. Não há conversão entre ABIs.
2. O `-march` da variante tem de ser subconjunto do `-march` pedido. Uma biblioteca feita para menos extensões roda num núcleo com mais extensões, e o contrário não vale.
3. A variante e o pedido têm de concordar no A, porque o código das bibliotecas de suporte muda com e sem atômicas.
4. Entre as variantes que cumprem as regras acima, vale a que tem mais extensões em comum com o pedido.

As extensões que não têm variante própria, como Zicsr, Zifencei, Zicntr, Zihpm e Zicclsm, não impedem o pedido de tomar uma variante, e o pedido pega a que não as tem. A tabela usa os nomes da seção 2.1, e a seção 2.4 traz os nomes normalizados que o compilador usa.

| Pedido | Variante usada | Motivo |
| :--- | :--- | :--- |
| `-march=rv32im -mabi=ilp32` | `rv32im/ilp32` | correspondência exata |
| `-march=rv32imc -mabi=ilp32` | `rv32imc/ilp32` | o C tem variante própria |
| `-march=rv32ima -mabi=ilp32` | `rv32ima/ilp32` | o A tem variante própria |
| `-march=rv32imac_zicsr_zifencei -mabi=ilp32` | `rv32imac/ilp32` | Zicsr e Zifencei são ignorados |
| `-march=rv32imc_zba_zbb -mabi=ilp32` | `rv32imc/ilp32` | o B exige Zba, Zbb e Zbs juntos |
| `-march=rv32imc_zba_zbb_zbs -mabi=ilp32` | `rv32imc_zba_zbb_zbs/ilp32` | as três extensões do B |
| `-march=rv32imafdc -mabi=ilp32d` | `rv32imafdc/ilp32d` | correspondência exata |
| `-march=rv32imfd -mabi=ilp32f` | `rv32imfd/ilp32f` | a biblioteca usa o D em hardware e passa só `float` em registradores |
| `-march=rv32ec -mabi=ilp32e` | `rv32ec/ilp32e` | a base E com C |
| `-march=rv32imf -mabi=ilp32e` | `rv32im/ilp32` | nenhuma variante tem `ilp32e` com a base I, o compilador aceita e toma o diretório padrão |
| `-march=rv32im -mabi=ilp32f` | nenhuma, o compilador dá erro | o `ilp32f` exige F |
| `-march=rv32efd -mabi=ilp32e` | nenhuma, o compilador dá erro | o `ilp32e` não suporta D |

A variante escolhida para um build pode ser lida com os comandos abaixo.

```bash
riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -print-multi-directory
riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 --specs=picolibc.specs -print-file-name=libc.a
riscv32-unknown-elf-gcc -print-multi-lib
```

## 4. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/picolibc/Dockerfile` |
| Workflow | `Picolibc image` |
| Tags | `<commit da picolibc>-<commit do GCC>` e `latest` |
| Rótulos | `picolibc.commit`, `riscv-gnu-toolchain.commit` e `riscv-gnu-toolchain.variants` (o número de variantes desse GCC) |
| Agenda | todo dia, 03:10 UTC, e quando a `GCC image` termina |

O workflow segue a série 1 (`SERIES`), então o run agendado usa a tag de release `1.x.y` mais recente. O run agendado espera um run da `GCC image` que esteja em andamento, e o fim desse run dispara este workflow de novo com o GCC novo. A tag tem só os dois commits, então o run também compara o número de variantes do rótulo da imagem dessa tag com o do GCC, e constrói de novo quando diferem.

## 5. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit da picolibc; vazio, a tag de release mais recente da série |
| `force` | reconstrói e republica mesmo que a imagem dessa combinação já exista |

## 6. Construindo localmente

```bash
docker build -f docker/base/picolibc/Dockerfile -t base-picolibc \
  --build-arg GCC_IMAGE=base-gcc \
  --build-arg PICOLIBC_COMMIT="$(git ls-remote https://github.com/picolibc/picolibc 'refs/tags/1.8.12^{}' | cut -f1)" \
  --build-arg GCC_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `GCC_IMAGE` | `base-gcc:latest` | o GCC que compila a picolibc |
| `PICOLIBC_COMMIT` | nenhum | o commit da picolibc a compilar |
| `GCC_COMMIT` | nenhum | o commit do GCC dessa imagem, registrado na tag |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
