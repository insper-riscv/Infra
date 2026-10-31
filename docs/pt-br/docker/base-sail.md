# base-sail

`ghcr.io/<organização>/base-sail` contém o modelo Sail RISC-V (`sail_riscv_sim`) compilado de um commit do `riscv/sail-riscv`, em `/opt/riscv-foundation/sail`. A [`ci-act4`](ci-act4.md) copia esse diretório. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| `sail_riscv_sim` | o executável do modelo, ligado estaticamente, em `/opt/riscv-foundation/sail/bin` |

O build busca o commit pelo hash, baixa o compilador Sail que esse commit exige (`cmake/sail_required_version.txt`, o binário da release do `rems-project/sail` para a arquitetura da build) e compila o modelo com CMake e Ninja, como o upstream compila a release. Em seguida confere que `sail_riscv_sim --version` imprime o número de release que o commit declara em `cmake/project_version.cmake`, que é o valor que o ACT4 compara com o seu requisito, e que o executável não tem biblioteca faltando. Qualquer divergência falha o build.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/sail/Dockerfile` |
| Workflow | `Sail image` |
| Tags | o commit e `latest` |
| Rótulos | `sail-riscv.version` (o número de release que o commit declara) e `sail-riscv.commit` |
| Agenda | todo dia, 03:00 UTC |

O commit é o mais recente da `master` do `riscv/sail-riscv` em que o workflow `ci.yml` do próprio upstream terminou com sucesso. O upstream integra por fila de merge, então esse workflow roda em `merge_group` além de `push`, e um sucesso em qualquer um dos dois vale. Um commit que ainda roda é esperado por alguns minutos e um que falhou é pulado.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit a construir (hash completo); vazio, o mais recente da `master` com o `ci.yml` verde |
| `force` | reconstrói e republica mesmo que a imagem desse commit já exista |

## 4. Construindo localmente

```bash
docker build -f docker/base/sail/Dockerfile -t base-sail \
  --build-arg SAIL_COMMIT=<hash completo do commit> \
  --build-arg SAIL_VERSION=0.16 .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `SAIL_COMMIT` | nenhum | o commit do `riscv/sail-riscv` |
| `SAIL_VERSION` | nenhum | o número de release que o commit declara |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
