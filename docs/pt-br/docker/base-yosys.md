# base-yosys

`ghcr.io/<organização>/base-yosys` contém o Yosys e o SymbiYosys (`sby`), em `/opt/yosys`. A [`ci-vhdl`](ci-vhdl.md) copia esse diretório. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| Yosys | construído a partir do código-fonte; lê o netlist Verilog que o GHDL sintetiza do VHDL |
| SymbiYosys (`sby`) | construído junto com o Yosys; roda o Yosys e os solvers |
| `/opt/yosys/.tag` e `/opt/yosys/.sby.tag` | os commits de que a instalação foi construída |

Os solvers `z3` e `boolector` vêm do Ubuntu e são instalados na `ci-vhdl`, que também instala as bibliotecas com que o Yosys liga (`libreadline8t64`, `libtcl8.6` e `libffi8`) e o `click` que o `sby` importa.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/yosys/Dockerfile` |
| Workflow | `Yosys image` |
| Tags | `<commit do Yosys>-<commit do sby>` e `latest` |
| Rótulos | `yosys.commit` e `sby.commit` |
| Agenda | todo dia, 03:00 UTC |

O workflow segue a série 0 (`SERIES`) e usa a release `v0.N` mais recente do Yosys, com a tag do `sby` de mesma versão, porque os dois são lançados em passo (`v0.N` de um com `v0.N` do outro).

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit do Yosys; vazio, o da release mais recente |
| `sby_commit` | o commit do `sby`; vazio, a tag do `sby` com a mesma versão da release do Yosys |
| `force` | reconstrói e republica mesmo que a imagem dessa combinação já exista |

## 4. Construindo localmente

```bash
docker build -f docker/base/yosys/Dockerfile -t base-yosys \
  --build-arg YOSYS_COMMIT="$(git ls-remote https://github.com/YosysHQ/yosys 'refs/tags/v0.70^{}' | cut -f1)" \
  --build-arg SBY_COMMIT="$(git ls-remote https://github.com/YosysHQ/sby 'refs/tags/v0.70^{}' | cut -f1)" .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `YOSYS_COMMIT` | nenhum | o commit do Yosys a construir |
| `SBY_COMMIT` | nenhum | o commit do `sby` a construir |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
