# base-sail

`ghcr.io/<organização>/base-sail` contém o modelo Sail RISC-V (`sail_riscv_sim`) de uma release, em `/opt/riscv-foundation/sail`. A [`ci-act4`](ci-act4.md) copia esse diretório. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| `sail_riscv_sim` | o executável do modelo, com as bibliotecas que o tarball da release traz, em `/opt/riscv-foundation/sail/bin` |

O build baixa o tarball da release do `riscv/sail-riscv` para a arquitetura da build (`x86_64` ou `aarch64`), confere o SHA-256 contra o que o GitHub publica para o arquivo, extrai em `/opt/riscv-foundation/sail` e executa `sail_riscv_sim --version`. Qualquer divergência falha o build.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/sail/Dockerfile` |
| Workflow | `Sail image` |
| Tags | o commit da tag da release e `latest` |
| Rótulos | `sail-riscv.version` e `sail-riscv.commit` |
| Agenda | todo dia, 03:00 UTC |

O workflow segue a série 0 (`SERIES`), cujas releases se chamam `0.N`. As pré-releases semanais do upstream não são releases estáveis e nunca entram.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `version` | a release a construir; vazio, a estável mais recente da série |
| `force` | reconstrói e republica mesmo que a imagem dessa release já exista |

## 4. Construindo localmente

```bash
docker build -f docker/base/sail/Dockerfile -t base-sail \
  --build-arg SAIL_VERSION=0.16 \
  --build-arg SAIL_SHA256_AMD64=<digest de sail-riscv-Linux-x86_64.tar.gz> \
  --build-arg SAIL_SHA256_ARM64=<digest de sail-riscv-Linux-aarch64.tar.gz> .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `SAIL_VERSION` | nenhum | a release do `riscv/sail-riscv` |
| `SAIL_SHA256_AMD64` | nenhum | o SHA-256 do tarball `x86_64` |
| `SAIL_SHA256_ARM64` | nenhum | o SHA-256 do tarball `aarch64` |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
