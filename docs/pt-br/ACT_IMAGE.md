# Imagens do ACT

`ghcr.io/<organização>/act_tools` é o ambiente para rodar a suíte ACT4 (riscv-arch-test, os Architectural Certification Tests): a [imagem de ferramentas de desenvolvimento](DEVTOOLS_IMAGE.md) mais o Sail, o Ruby, o Bundler e as dependências de um commit do ACT4. `ghcr.io/<organização>/infra-sail` guarda só o Sail, e a `act_tools` o copia de lá. As duas são publicadas para `linux/amd64` e `linux/arm64`.

## 1. O que as imagens trazem

| Imagem | Item | Versão |
| :--- | :--- | :--- |
| `infra-sail` | `sail_riscv_sim`, o executável do modelo Sail RISC-V, em `/opt/sail` | a última release estável da série 0 (uma release se chama `0.N`) |
| `act_tools` | tudo o que há na `dev_tools` | ver a imagem de ferramentas de desenvolvimento |
| `act_tools` | Sail | o da `infra-sail` |
| `act_tools` | Ruby e Bundler | Ruby 3.3 do Ubuntu, Bundler 4.0.23 |
| `act_tools` | gems do ACT4 (as gems do UDB e suas dependências), instaladas em `/opt/act-bundle` | as que o commit do rótulo `act4.commit` registra |
| `act_tools` | pacotes Python do ACT4, no cache do `uv` em `/opt/act-uv-cache` | os que esse commit registra |
| `act_tools` | programas auxiliares e a biblioteca Z3 que as gems do UDB baixam, em `/opt/act-cache` | os que as gems pedem |

Os três diretórios da `act_tools` podem ser escritos por qualquer usuário do contêiner.

## 2. Rodando a suíte ACT4

Clone o ACT4 no commit que o projeto fixa e rode o contêiner com o clone como diretório de trabalho:

```bash
docker run --rm -it --user "$(id -u):$(id -g)" -e HOME=/tmp -e UV_LINK_MODE=copy \
  -v "$PWD:/work" -w /work ghcr.io/insper-riscv/act_tools:latest bash
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

## 3. Sem rede

Com o commit do ACT4 do rótulo `act4.commit`, `make tests` e `make` não precisam de rede: as gems, os pacotes Python e os programas auxiliares estão na imagem. Um commit diferente do ACT4 que mude uma dependência precisa de rede na primeira execução, e os downloads vão para os mesmos diretórios.

## 4. Publicação

| Imagem | Tags |
| :--- | :--- |
| `infra-sail` | o commit da tag da release, e `latest` |
| `act_tools` | `latest`, `sha-<commit do Infra>`, e `devtools-<12 dígitos do digest da dev_tools>-sail-<7 do commit do Sail>-act4-<7 do commit do ACT4>` |

O workflow `Sail image` roda todo dia às 03:10 UTC, pega a última release estável da série 0 e a constrói se a imagem para o commit dela não existe. Ele confere cada tarball contra o SHA-256 que o GitHub publica para o arquivo. O workflow `ACT image` roda todo dia às 04:30 UTC e quando o workflow da imagem Dev tools ou o da imagem do Sail termina; ele constrói quando a combinação da tag não existe.

O commit do ACT4 cujas dependências são instaladas é o `ACT4_COMMIT` do workflow `ACT image`, que muda editando-o, ou pelo campo `act4_commit` de uma execução manual. Uma execução manual de qualquer um dos workflows, com `confirm` igual ao valor do segredo `IMAGE_PUBLISH_SECRET`, reconstrói a imagem.

Construção local:

```bash
docker build -f Dockerfile.sail -t infra-sail \
  --build-arg SAIL_VERSION=0.16 \
  --build-arg SAIL_SHA256_AMD64=<digest de sail-riscv-Linux-x86_64.tar.gz> \
  --build-arg SAIL_SHA256_ARM64=<digest de sail-riscv-Linux-aarch64.tar.gz> .

docker build -f Dockerfile.act -t act_tools \
  --build-arg SAIL_IMAGE=infra-sail \
  --build-arg ACT4_COMMIT=<commit do riscv/riscv-arch-test> .
```
