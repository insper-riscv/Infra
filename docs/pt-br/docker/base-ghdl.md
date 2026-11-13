# base-ghdl

`ghcr.io/<organização>/base-ghdl` contém só o GHDL, em `/opt/ghdl`. A [`ci-vhdl`](ci-vhdl.md) copia esse diretório. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| GHDL | backend LLVM, construído a partir do código-fonte, em `/opt/ghdl` |
| `/opt/ghdl/.tag` | duas linhas. A primeira é o commit do `ghdl/ghdl` de que a instalação foi construída, e a segunda é a versão e o commit curto (`7.0.0-dev (8e642a9)`): a versão da release cuja tag aponta para o commit ou, se ele não for uma release, a que o commit declara no `configure` |

O backend LLVM roda em `amd64` e `arm64`, ao contrário do `mcode`, que é só x86; as duas arquiteturas precisam rodar o mesmo simulador. Com esse backend, `ghdl -r` exige um `ghdl -e` antes (ou `ghdl --elab-run`). O GHDL liga com `libgnat`, `libllvm`, `zlib1g` e `libedit2`, instaladas na `ci-vhdl`.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/ghdl/Dockerfile` |
| Workflow | `GHDL image` |
| Tags | `<commit>` e `latest` |
| Rótulo | `ghdl.commit` |
| Agenda | todo dia, 03:00 UTC |

O workflow segue a branch padrão do GHDL (a linha 7.0.0-dev), porque o plugin do GHDL para o Yosys exige uma API do GHDL que a release 6.0.0 não tem. Ele usa o commit mais recente em que o workflow `Pipeline.yml` do GHDL passou (`.github/scripts/green-commit.sh`), então um commit que falha no upstream nunca é construído. O run agendado constrói só se a imagem para esse commit não existir.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit a construir; vazio, o mais recente da branch padrão com CI verde |
| `ignore_ci` | sem `commit`, usa a ponta da branch padrão, qualquer que seja o resultado do CI dela |
| `force` | reconstrói e republica mesmo que a imagem desse commit já exista |

## 4. Construindo localmente

```bash
docker build -f docker/base/ghdl/Dockerfile -t base-ghdl \
  --build-arg GHDL_COMMIT="$(git ls-remote https://github.com/ghdl/ghdl HEAD | cut -f1)" .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `GHDL_COMMIT` | nenhum | o commit do `ghdl/ghdl` a construir |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
