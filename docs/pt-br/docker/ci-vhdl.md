# ci-vhdl

`ghcr.io/<organização>/ci-vhdl` é o nível 1 das imagens de CI, com o que um teste VHDL precisa. Ela copia o [`base-ghdl`](base-ghdl.md) e o [`base-yosys`](base-yosys.md), e a imagem [`ci-asm`](ci-asm.md) e seguintes são construídas sobre ela. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Componente | Detalhe | Caminho |
| :--- | :--- | :--- |
| GHDL | backend LLVM, vindo de `base-ghdl` | `/opt/ghdl` |
| Yosys | lê o netlist Verilog que o GHDL sintetiza do VHDL, vindo de `base-yosys` | `/opt/yosys` |
| SymbiYosys (`sby`) | roda o Yosys e os solvers, vindo de `base-yosys` | `/opt/yosys` |
| `z3` e `boolector` | os solvers SMT do SymbiYosys, do Ubuntu | `/usr/bin` |
| `uv` | gerenciador de projetos Python, instalado pelo instalador oficial da versão escolhida, que confere o binário contra o SHA-256 que ele carrega | `/usr/local/bin` |
| Python | 3.14, instalado pelo `uv` para todos os usuários, com `python3` e `python` no `PATH` | `/opt/uv/python` |
| cocotb | 2.1.0, instalado nesse Python | `/opt/uv/python` |
| `click` | 8.5.0, a biblioteca Python que o `sby` importa, instalada pelo `uv` | `/opt/uv/python` |

O `gcc` e o `g++` do host também estão na imagem. O backend LLVM liga com o `gcc` o executável que elabora, e o cocotb é compilado com o `g++` no `arm64`, onde não tem wheel para Linux; o `uv sync` de cada projeto o compila lá também. A imagem não tem `pip`; um projeto instala o restante das suas dependências com `uv sync`, que encontra este Python em vez de baixar outro.

O Python é fixado em 3.14 porque o cocotb mais recente, o 2.1.0, suporta o Python até a versão 3.14, e é por isso que os projetos exigem essa versão (`>=3.14,<3.15`). Um Python mais novo espera um cocotb que o suporte (os argumentos de build `PYTHON_VERSION` e `COCOTB_VERSION` mudam os dois juntos).

Também vêm do Ubuntu `git`, `make`, `curl` e `ca-certificates` (o checkout de um workflow, os Makefiles dos projetos, os instaladores e os certificados com que `curl` e `git` verificam servidores HTTPS), a biblioteca `libglib2.0-0t64`, que as ferramentas de linha de comando de um Quartus montado do host usam e a imagem base do Ubuntu não traz, as bibliotecas que o GHDL liga (`libgnat`, `libllvm`, `zlib1g-dev`, `libedit2`) e as que o Yosys liga (`libreadline8t64`, `libtcl8.6`, `libffi8`).

### 1.1. O que se atualiza sozinho e o que é fixo

| Item | Versão | Muda quando |
| :--- | :--- | :--- |
| GHDL, Yosys, SymbiYosys | as da `base-ghdl` e da `base-yosys` | essas imagens ganham uma versão nova (automático) |
| `uv` | a release estável mais recente da série 0 | o `uv` lança uma versão nova (automático, consultado todo dia) |
| Python | o patch mais recente do 3.14 que o `uv` da imagem conhece | sai um `uv` novo (automático); o minor só muda editando `PYTHON_VERSION` |
| cocotb | 2.1.0, fixo | `COCOTB_VERSION` é editado |
| `click` | 8.5.0, fixo | `CLICK_VERSION` é editado |
| `z3`, `boolector` e os demais pacotes do Ubuntu | o que o Ubuntu 26.04 tem quando a imagem é construída | a imagem é reconstruída por outro motivo |

A imagem é reconstruída só quando o GHDL, o Yosys, o SymbiYosys ou o `uv` mudam. O patch do Python acompanha o `uv`, porque um `uv` novo traz o patch novo, mas o cocotb e o `click` não o acompanham: ficam nas versões que o `Dockerfile.vhdl-img` fixa até alguém editar o argumento de build e rodar o workflow à mão com `force`. As versões de Python, cocotb e `click` estão na tag longa e nos rótulos de toda imagem, e não entram na decisão de construir.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `Dockerfile.vhdl-img` |
| Workflow | `VHDL image` |
| Tags | `latest`, `sha-<commit do Infra>`, `ghdl-<7>-yosys-<7>-sby-<7>-uv-<versão>` e a mesma com `-python-<x.y.z>-cocotb-<versão>-click-<versão>` no final |
| Rótulos | `ghdl.commit`, `yosys.commit`, `sby.commit`, `uv.version`, `python.version`, `cocotb.version` e `click.version` |
| Agenda | todo dia, 03:00 UTC, e quando `GHDL image` ou `Yosys image` termina |

O `uv` é o único componente sem imagem nossa. Todo run usa a release estável mais recente da série definida em `UV_SERIES` (`0`), ou o campo `uv_version` de um run manual. A versão entra na tag de combinação, então um run para uma versão já publicada não monta nada, e um `uv` novo é pego pelo primeiro run depois do lançamento.

Antes de publicar, o workflow confere que o commit que cada componente deixou na imagem (o arquivo `.tag`) é o que foi fixado para ele.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `uv_version` | a versão do `uv`; vazio, a estável mais recente da série |

## 4. Construindo localmente

```bash
docker build -f Dockerfile.vhdl-img -t ci-vhdl \
  --build-arg GHDL_IMAGE=base-ghdl --build-arg YOSYS_IMAGE=base-yosys \
  --build-arg UV_VERSION="$(git ls-remote --tags --refs https://github.com/astral-sh/uv '0.*' | sed 's|.*refs/tags/||' | grep -E '^0\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)" .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `GHDL_IMAGE` | `base-ghdl:latest` | de onde vem o GHDL |
| `YOSYS_IMAGE` | `base-yosys:latest` | de onde vêm o Yosys e o SymbiYosys |
| `UV_VERSION` | nenhum (obrigatório) | versão do `uv`; o build falha com uma mensagem se faltar |
| `PYTHON_VERSION` | `3.14` | Python instalado pelo `uv` |
| `COCOTB_VERSION` | `2.1.0` | cocotb instalado nele |
| `CLICK_VERSION` | uma versão fixa | `click`, usado pelo `sby` |

O build imprime uma linha por componente, com a versão e o commit, e falha se o GHDL não roda um projeto VHDL-2008, se o Yosys e o `sby` não provam uma propriedade pequena com o `z3` ou se o Python não é o 3.14 com cocotb.

## 5. Usos

### 5.1. Verificação formal

O GHDL transforma uma entidade VHDL num netlist Verilog, que o Yosys lê e sobre o qual o SymbiYosys prova propriedades. As propriedades são escritas em SystemVerilog em volta do netlist, então nenhum plugin do GHDL para o Yosys é necessário:

```bash
ghdl -a --std=08 --workdir=work meu_bloco.vhd
ghdl --synth --std=08 --workdir=work --out=verilog meu_bloco > meu_bloco.v
sby -f meu_bloco.sby
```

O arquivo `.sby` informa o modo (`prove` para uma prova ilimitada por indução, `bmc` para uma checagem limitada, `cover` para confirmar que as propriedades não são vazias), a profundidade, o motor (`smtbmc z3`) e os arquivos. Uma prova que falha grava uma forma de onda do contraexemplo ao lado do log.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
