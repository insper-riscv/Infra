# base-picolibc

`ghcr.io/<organização>/base-picolibc` contém os arquivos que a picolibc instala no sysroot do GCC, sob `/opt/riscv-foundation/riscv32-elf`. É compilada com a [`base-gcc`](base-gcc.md), e a [`ci-elf`](ci-elf.md) a copia sobre o prefixo do GCC. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| picolibc | a biblioteca C compilada pelo GCC da `base-gcc` mais recente, instalada no sysroot, uma vez para cada variante desse GCC (`rv32i/ilp32`, `rv32i_zmmul/ilp32`, `rv32im/ilp32`, `rv32imf/ilp32f` e `rv32imfd/ilp32d`) |

A picolibc é compilada por um cross compiler, então o build usa a imagem de GCC mais recente. A imagem leva o commit desse GCC no rótulo `riscv-gnu-toolchain.commit`, e um GCC novo gera um build novo da picolibc.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/picolibc/Dockerfile` |
| Workflow | `Picolibc image` |
| Tags | `<commit da picolibc>-<commit do GCC>` e `latest` |
| Rótulos | `picolibc.commit` e `riscv-gnu-toolchain.commit` |
| Agenda | todo dia, 03:10 UTC, e quando a `GCC image` termina |

O workflow segue a série 1 (`SERIES`), então o run agendado usa a tag de release `1.x.y` mais recente. O run agendado espera um run da `GCC image` que esteja em andamento, e o fim desse run dispara este workflow de novo com o GCC novo.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit da picolibc; vazio, a tag de release mais recente da série |
| `force` | reconstrói e republica mesmo que a imagem dessa combinação já exista |

## 4. Construindo localmente

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
