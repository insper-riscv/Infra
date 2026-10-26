# base-ghdl

`ghcr.io/<organização>/base-ghdl` contém só o GHDL, em `/opt/ghdl`. A [`ci-vhdl`](ci-vhdl.md) copia esse diretório. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| GHDL | backend LLVM, construído a partir do código-fonte, em `/opt/ghdl` |
| `/opt/ghdl/.tag` | o commit do `ghdl/ghdl` de que a instalação foi construída |

O backend LLVM roda em `amd64` e `arm64`, ao contrário do `mcode`, que é só x86; as duas arquiteturas precisam rodar o mesmo simulador. Com esse backend, `ghdl -r` exige um `ghdl -e` antes (ou `ghdl --elab-run`). O GHDL liga com `libgnat`, `libllvm`, `zlib1g` e `libedit2`, instaladas na `ci-vhdl`.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `Dockerfile.ghdl` |
| Workflow | `GHDL image` |
| Tags | `<commit>` e `latest` |
| Rótulo | `ghdl.commit` |
| Agenda | todo dia, 03:00 UTC |

O workflow segue a série 6 do GHDL (`SERIES`), então uma série nova é escolhida editando essa linha. O run agendado usa o commit da tag da release `6.x.y` mais recente e constrói só se a imagem para esse commit não existe.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit a construir; vazio, o da tag da release mais recente |
| `force` | reconstrói e republica mesmo que a imagem desse commit já exista |

## 4. Construindo localmente

```bash
docker build -f Dockerfile.ghdl -t base-ghdl \
  --build-arg GHDL_COMMIT="$(git ls-remote https://github.com/ghdl/ghdl 'refs/tags/v6.0.0^{}' | cut -f1)" .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `GHDL_COMMIT` | nenhum | o commit do `ghdl/ghdl` a construir |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
