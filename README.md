# Infra

🌐 [Português](README.md) · [English](README.en.md)

A infraestrutura do projeto RV32: as imagens Docker com as ferramentas dos testes, os guias passo a passo para instalar essas ferramentas à mão e os guias para configurar uma workstation com hardware FPGA como runner self-hosted do GitHub Actions. Os guias cobrem distros Debian-like (`apt`) e RHEL-like (`dnf`/`yum`).

## 1. Qual guia seguir

| Quero | Leia |
| :--- | :--- |
| Usar as ferramentas sem instalá-las, no CI ou num Dev Container | [Imagens Docker](docs/pt-br/docker/README.md) |
| Instalar as ferramentas direto numa máquina | [Instalação manual](docs/pt-br/manual/README.md) |
| Instalar o Quartus Prime Lite numa workstation | [QUARTUS_INSTALL.md](docs/pt-br/QUARTUS_INSTALL.md) |
| Configurar uma workstation com placa FPGA como runner | [RUNNER_SETUP.md](docs/pt-br/RUNNER_SETUP.md) |

Uma workstation com placa segue o [QUARTUS_INSTALL.md](docs/pt-br/QUARTUS_INSTALL.md) e depois o [RUNNER_SETUP.md](docs/pt-br/RUNNER_SETUP.md), que precisa de Docker porque os jobs rodam nas imagens de CI.

## 2. As imagens

As imagens são de três tipos, descritos na [visão geral das imagens](docs/pt-br/docker/README.md), que também tem o arquivo de cada uma.

| Imagem | Contém |
| :--- | :--- |
| `base-*` | uma ferramenta cada: GHDL, Yosys com SymbiYosys, GCC RISC-V, picolibc, Spike, Sail e GTKWave |
| `ci-vhdl` | GHDL, Yosys, `uv`, Python e cocotb, para os testes VHDL |
| `ci-elf` | a anterior mais o GCC RISC-V com picolibc e o Spike, para gerar ELFs (compilar assembly e C) e rodá-los no Spike |
| `ci-act4` | a anterior mais o Sail e as dependências do ACT4, para a certificação ACT4 |
| `dev_tools` | a anterior mais o GTKWave e o usuário `dev`, para o Dev Container |

Toda imagem é publicada em `ghcr.io/insper-riscv` para `linux/amd64` e `linux/arm64`, e um workflow diário de cada imagem base procura uma versão nova da ferramenta dela.

## 3. O repositório

| Caminho | Conteúdo |
| :--- | :--- |
| `docker/` | a receita (`Dockerfile`) de cada imagem, em `base/` para as ferramentas, `ci/` para os níveis e `dev-tools/` |
| `.github/workflows/` | um workflow por imagem, o build compartilhado, o aviso de receitas alteradas e a limpeza de versões antigas |
| `.github/scripts/` | a escolha do commit mais recente do upstream cujo CI passou, com o teste dela |
| `scripts/` | a limpeza de versões antigas dos pacotes |
| `docs/` | os guias, em `en/` e `pt-br/` |

## 4. Ações compostas e workflows de CI dos repositórios

Os repositórios do projeto reutilizam duas ações compostas deste repositório, em `.github/actions/`.

| Ação | O que faz |
| :--- | :--- |
| `ci-plan` | Resolve as imagens de CI (sempre a tag `latest`) e decide, por trabalho caro (`formal` e `unit-tests`), se o resultado de uma execução anterior da mesma árvore pode ser reaproveitado. O digest que a `latest` tem no momento da execução entra na chave do cache, então uma imagem nova nunca reaproveita o resultado da antiga |
| `version-bump` | Falha o pull request que muda o repositório sem subir a versão do `pyproject.toml` e do `uv.lock` |

O workflow `tools-watch.yml` dispara a reconstrução das imagens quando o Tools publica uma versão nova, e os repositórios passam a usar a imagem nova sem nenhuma edição. Ele não dispara enquanto um `CI images` está na fila ou rodando, nem por três horas depois de uma execução que falhou. O build das imagens resolve nomes pelos servidores públicos 1.1.1.1 e 8.8.8.8, para o `apt-get` não depender do DNS do runner. Os repositórios chamam as ações por `insper-riscv/Infra/.github/actions/<ação>@main`.

## 5. Contribuindo

- [CONTRIBUTING.md](CONTRIBUTING.md): as regras de contribuição e a verificação antes de abrir um Pull Request.
- [AUTHORS.md](AUTHORS.md): os autores com commits no repositório.
- [CITATION.cff](CITATION.cff): os metadados para citar o software.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](LICENSE).
