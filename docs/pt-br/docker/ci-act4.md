# ci-act4

`ghcr.io/<organização>/ci-act4` é o nível 3 das imagens de CI, com o que a certificação precisa, isto é, a suíte ACT4 (riscv-arch-test, os Architectural Certification Tests). Ela é a [`ci-elf`](ci-elf.md), cujo GCC RISC-V gera os ELFs, mais o Sail ([`base-sail`](base-sail.md)), o Ruby, o Bundler e as dependências de um commit do ACT4. A [`dev_tools`](dev-tools.md) é construída sobre ela. A visão geral das imagens está em [README.md](README.md).

## 1. O que acrescenta à ci-elf

| Item | Detalhe | Versão |
| :--- | :--- | :--- |
| Sail | `sail_riscv_sim`, em `/opt/riscv-foundation/sail`, vindo da `base-sail` | o da `base-sail` |
| Ruby e Bundler | o ACT4 lê a configuração pelas gems do UDB | Ruby 3.3 do Ubuntu, Bundler 4.0.23 |
| gems do ACT4 (as gems do UDB e suas dependências) | instaladas em `/opt/act-bundle` | as que o commit do rótulo `act4.commit` registra |
| pacotes Python do ACT4 | no cache do `uv`, em `/opt/act-uv-cache` | os que esse commit registra |
| programas auxiliares e a biblioteca Z3 que as gems do UDB baixam | em `/opt/act-cache` | os que as gems pedem |

Os três diretórios de cache podem ser escritos por qualquer usuário do contêiner.

## 2. Rodando a suíte ACT4

Clone o ACT4 no commit do rótulo `act4.commit` da imagem e rode o contêiner com o clone como diretório de trabalho:

```bash
docker run --rm -it --user "$(id -u):$(id -g)" -e HOME=/tmp -e UV_LINK_MODE=copy \
  -v "$PWD:/work" -w /work ghcr.io/insper-riscv/ci-act4:latest bash
```

Dentro do contêiner, a suíte é gerada, compilada e executada como na documentação do ACT4. O compilador da imagem é o `riscv32-unknown-elf-gcc`, então a configuração do DUT o nomeia:

```yaml
compiler_exe: riscv32-unknown-elf-gcc
objdump_exe: riscv32-unknown-elf-objdump
ref_model_exe: sail_riscv_sim
```

Depois, no diretório do ACT4:

```bash
CONFIG_FILES=<diretório do DUT>/test_config.yaml make EXTENSIONS=I,M
```

Com a configuração `config/sail/sail-rv32-max` do ACT4, trocando apenas os dois nomes de compilador, a suíte da extensão I gera os seus ELFs e o Sail executa todos eles.

`--user` faz os arquivos que o ACT4 cria pertencerem a você, `HOME=/tmp` dá às ferramentas que querem um diretório pessoal um que qualquer usuário escreve, e `UV_LINK_MODE=copy` evita um aviso quando o cache do `uv` e o diretório de trabalho ficam em sistemas de arquivos diferentes. Num daemon do Docker que remapeia espaços de usuário, acrescente `--userns=host`.

## 3. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/ci/act4/Dockerfile` |
| Workflow | `CI images`, job `act4` |
| Tags | `latest`, `sha-<commit do Infra>` e `elf-<12 do digest da ci-elf>-sail-<7 do commit do Sail>-act4-<7 do commit do ACT4>` |
| Rótulos | `act4.commit` e `sail-riscv.commit` |
| Agenda | no mesmo run da `ci-elf`, logo depois dela: todo dia, 03:00 UTC, e quando `Sail image` termina |

O commit do ACT4 cujas dependências são instaladas é o commit mais recente do ramo `act4` do `riscv/riscv-arch-test` em que o workflow `ACT Regression` dele passou, consultado a cada run, então a imagem acompanha a suíte e um commit novo gera uma tag nova. O commit só é aceito se o Sail da imagem for a versão que ele exige. Quando não é, o run mantém o commit do ACT4 da `ci-act4` publicada e avisa, e falha se esse commit também não casar com o Sail. Um projeto que usa o ACT4 como submódulo pega o commit do rótulo `act4.commit`.

| Campo (execução manual) | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `from_level` | o nível a partir do qual reconstruir (`vhdl`, `elf`, `act4` ou `devtools`): ele e os de cima são reconstruídos, os de baixo são reaproveitados |
| `act4_commit` | o commit do `riscv/riscv-arch-test`; vazio, o commit verde mais recente do ramo `act4`. O run falha se o Sail da imagem não for a versão que esse commit exige |

## 4. Construindo localmente

```bash
docker build -f docker/ci/act4/Dockerfile -t ci-act4 \
  --build-arg ELF_IMAGE=ci-elf --build-arg SAIL_IMAGE=base-sail \
  --build-arg ACT4_COMMIT=<commit do riscv/riscv-arch-test> .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `ELF_IMAGE` | `ci-elf:latest` | o nível abaixo |
| `SAIL_IMAGE` | `base-sail:latest` | de onde vem o Sail |
| `ACT4_COMMIT` | nenhum | o commit do `riscv/riscv-arch-test` cujas dependências entram |
| `BUNDLER_VERSION` | `4.0.23` | o Bundler que o `Gemfile.lock` do ACT4 registra |

O build termina conferindo `ruby --version`, `bundle --version` e `sail_riscv_sim --version`, e que o Sail não tem biblioteca faltando.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
