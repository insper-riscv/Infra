# Imagens Docker da toolchain

Quatro imagens Docker com o que o fluxo de testes RISC-V precisa, exceto o Quartus: uma só com o GHDL, uma só com o GCC, uma só com o Spike e uma completa (GHDL, GCC RISC-V com picolibc, Spike e `uv`) que copia os artefatos das três primeiras. Os `Dockerfile` ficam na raiz deste repositório, e quatro workflows as publicam no GitHub Container Registry. Toda imagem é publicada para `linux/amd64` e `linux/arm64`, e as duas arquiteturas têm as mesmas versões das mesmas ferramentas: o GHDL tem o backend LLVM nas duas, então uma simulação se comporta igual num PC e numa máquina ARM, como um Mac.

## 1. As quatro imagens

| Imagem | `Dockerfile` | Workflow | Conteúdo | Tags |
| :--- | :--- | :--- | :--- | :--- |
| `ghcr.io/<organização>/infra-ghdl` | `Dockerfile.ghdl` | `GHDL image` | Só `/opt/ghdl` | `<commit>` e `latest` |
| `ghcr.io/<organização>/infra-gcc` | `Dockerfile.gcc` | `GCC image` | Só `/opt/riscv-foundation/riscv32-elf` | `<commit>` e `latest` |
| `ghcr.io/<organização>/infra-spike` | `Dockerfile.spike` | `Spike image` | Só `/opt/riscv-foundation/spike` | `<commit>` e `latest` |
| `ghcr.io/<organização>/infra-toolchain` | `Dockerfile` | `Toolchain image` | A imagem completa | `latest`, `sha-<commit do Infra>` e `ghdl-<7 primeiros>-gcc-<7 primeiros>-spike-<7 primeiros>` |

O `<commit>` das três primeiras é o commit do `ghdl/ghdl` (o da tag de release), do `riscv-collab/riscv-gnu-toolchain` e do `riscv-software-src/riscv-isa-sim` de que foram compiladas, e fica também no rótulo `ghdl.commit`, `riscv-gnu-toolchain.commit` ou `riscv-isa-sim.commit` da imagem. As imagens de componente não têm sistema de arquivos além desses diretórios, então não dá para executá-las: elas existem para serem copiadas.

## 2. O que a imagem completa contém

| Componente | Detalhe | Caminho |
| :--- | :--- | :--- |
| GHDL | Backend LLVM, compilado do código-fonte (o backend mcode das imagens `ghdl/ghdl` é só x86, e as duas arquiteturas precisam rodar o mesmo GHDL) | `/opt/ghdl` |
| GCC RISC-V | Alvo `rv32im`/`ilp32` com picolibc, uma única variante de biblioteca (o que o [GCC_SETUP.md](GCC_SETUP.md) compila) | `/opt/riscv-foundation/riscv32-elf` |
| Spike | Com o módulo de debug movido do endereço `0x0` para `0x70000000` (o que o [SPIKE_SETUP.md](SPIKE_SETUP.md) compila) | `/opt/riscv-foundation/spike` |
| `uv` | Gerenciador de projetos Python | `/usr/local/bin` |
| Python | 3.14, instalado pelo `uv` para todos os usuários, com `python3` e `python` no `PATH` | `/opt/uv/python` |
| cocotb | 2.1.0, instalado nesse Python | `/opt/uv/python` |

O GHDL, o GCC e o Spike já estão no `PATH` da imagem. O `gcc` do host também está na imagem, porque o backend LLVM liga com ele o projeto que elabora; o do RISC-V mantém os próprios nomes `riscv32-unknown-elf-`. Com o backend LLVM o `ghdl -r` precisa de um `ghdl -e` antes (ou use `ghdl --elab-run`); os Makefiles e o runner de simulação já fazem isso. Cada instalação guarda em `.tag` o commit de que foi compilada, e a imagem completa traz os três rótulos de commit.

O Python é fixado em 3.14 porque é a versão que os projetos exigem (`>=3.14,<3.15`), e o cocotb 2.1.0 é a primeira versão que a suporta: o cocotb é quem fixa a versão do Python, então um Python mais novo espera um cocotb que o suporte (os argumentos de build `PYTHON_VERSION` e `COCOTB_VERSION` mudam os dois juntos). Todo projeto simula com o cocotb, então ele está na imagem (o cocotb 2.1.0 tem wheels para o Python 3.14 em Linux x86-64, macOS e Windows, mas não em Linux arm64, então no arm64 ele é compilado, e é por isso que a imagem tem `g++`, e o `uv sync` de um projeto também o compila lá); as outras bibliotecas Python são de cada projeto e vêm do `uv sync` dele, que encontra este Python em vez de baixar outro.

O Quartus não está em nenhuma das imagens, e um container não enxerga o USB-Blaster sem configuração extra do host. Por isso os testes de hardware real dividem o trabalho: as ROMs de teste e seus goldens são construídos dentro da imagem completa, e o Quartus e o cabo JTAG são usados a partir do runner self-hosted descrito no [RUNNER_SETUP.md](RUNNER_SETUP.md), que precisa de Docker e de acesso a ele.

## 3. Usando a imagem completa

Interativamente, com o diretório atual montado:

```bash
docker run --rm -it -v "$PWD:/workspace" ghcr.io/insper-riscv/infra-toolchain:latest
```

Num job do GitHub Actions:

```yaml
jobs:
  sim:
    runs-on: ubuntu-24.04
    container:
      image: ghcr.io/insper-riscv/infra-toolchain:latest
    steps:
      - uses: actions/checkout@v7.0.1
      - run: riscv32-unknown-elf-gcc --version
```

Para um resultado reproduzível, use a tag `sha-<commit>` da publicação desejada em vez de `latest`.

## 4. Atualizando o GHDL, o GCC ou o Spike

Cada componente tem um workflow de execução manual. Em Actions, escolha `GHDL image`, `GCC image` ou `Spike image` e clique em **Run workflow**, preenchendo:

| Campo | Significado |
| :--- | :--- |
| `confirm` | O valor do secret `IMAGE_PUBLISH_SECRET` (veja a seção 6) |
| `commit` | O commit a compilar. Vazio: o mais recente da branch padrão do projeto (no GHDL, o commit da tag de release mais recente) |
| `force` | Recompilar e republicar mesmo que a imagem desse commit já exista |

O workflow resolve o commit, confere se `infra-gcc:<commit>` (ou `infra-spike:<commit>`) já existe e, se existir e `force` estiver desligado, não compila nada. Caso contrário, compila, confere a instalação e publica com as tags `<commit>` e `latest`.

Os workflows de componente também rodam sozinhos num push na `main` que altere o próprio `Dockerfile.ghdl`, `Dockerfile.gcc` ou `Dockerfile.spike`, ou o próprio workflow. Nesse caso não há campo `commit`: eles recompilam o commit que a imagem `latest` já tem (a receita mudou, a versão não) com `force` ligado, e só usam o commit mais recente do upstream quando ainda não há imagem publicada. Por isso o merge que adiciona os `Dockerfile` já publica os componentes pela primeira vez.

Quando um desses workflows termina com sucesso, o `Toolchain image` roda sozinho: lê os commits dos rótulos das três imagens `latest` e monta e publica uma imagem completa nova. Atualizar só o Spike leva alguns minutos, e atualizar o GCC ou o GHDL leva de dezenas de minutos a mais de uma hora.

Cada arquitetura é compilada num runner dela (`ubuntu-26.04` para `linux/amd64` e `ubuntu-24.04-arm` para `linux/arm64`): os builds do GCC e do GHDL levam horas sob emulação. Um job final junta as duas imagens num só manifesto com as tags, e o `docker pull` entrega a cada máquina a sua.

O `Toolchain image` não espera um componente terminar: se, ao rodar por um push ou pelo fim de outro componente, houver um run de `GHDL image`, `GCC image` ou `Spike image` na fila ou em andamento, ele pula com um aviso, e o fim desse run o dispara de novo. O último componente a terminar faz a montagem única. Um run manual do `Toolchain image` nunca adia.

O `Toolchain image` precisa das três imagens `latest`. Se um push chegar antes de elas existirem, ele termina com um aviso, sem falhar, e roda quando os componentes terminarem. Um run manual dele sem as imagens falha, com uma mensagem que aponta os três workflows.

## 5. Construindo localmente

Os componentes não têm commit padrão, então o commit é passado no build:

```bash
docker build -f Dockerfile.ghdl -t infra-ghdl \
  --build-arg GHDL_COMMIT="$(git ls-remote https://github.com/ghdl/ghdl 'refs/tags/v6.0.0^{}' | cut -f1)" .

docker build -f Dockerfile.gcc -t infra-gcc \
  --build-arg RISCV_GNU_TOOLCHAIN_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .

docker build -f Dockerfile.spike -t infra-spike \
  --build-arg RISCV_ISA_SIM_COMMIT="$(git ls-remote https://github.com/riscv-software-src/riscv-isa-sim HEAD | cut -f1)" .

docker build -t infra-toolchain \
  --build-arg GHDL_IMAGE=infra-ghdl --build-arg GCC_IMAGE=infra-gcc --build-arg SPIKE_IMAGE=infra-spike .
```

O build do GCC leva de dezenas de minutos a mais de uma hora, conforme a máquina. Sem `GHDL_IMAGE`, `GCC_IMAGE` e `SPIKE_IMAGE`, o build da imagem completa usa as imagens `latest` publicadas no GHCR. Os outros argumentos:

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:24.04` | Imagem base de todos os builds (uma imagem multi-arquitetura) |
| `UV_VERSION` | versão fixa | Versão do `uv` (só no `Dockerfile` completo) |
| `PYTHON_VERSION` | `3.14` | Python instalado pelo `uv` (só no `Dockerfile` completo) |
| `COCOTB_VERSION` | `2.1.0` | cocotb instalado nele (só no `Dockerfile` completo) |

## 6. Publicação e segurança

Os quatro workflows publicam em `ghcr.io/<organização>/`, com o `GITHUB_TOKEN` do próprio run. A visibilidade de cada pacote (público ou privado) é definida nas configurações do pacote no GitHub, e não pelo workflow. Os quatro pacotes precisam ficar acessíveis a quem vai usá-los, e o `Toolchain image` lê os outros três.

A execução manual de qualquer um dos quatro pede o campo `confirm`, que precisa ser igual ao valor do secret `IMAGE_PUBLISH_SECRET`. É o mesmo segundo portão descrito na Fase 5 do [RUNNER_SETUP.md](RUNNER_SETUP.md): o acesso de escrita ao repositório já controla quem pode disparar o workflow, e o secret garante que só quem o conhece publique a imagem. Os quatro workflows também rodam num push na `main` que altere o `Dockerfile` correspondente ou o próprio workflow, e o `Toolchain image` roda ainda depois que um dos três workflows de componente termina. Esses caminhos não pedem `confirm`: o portão do push é a proteção de branch, e o de componente já passou pelo `confirm` ou pelo push do seu run.

Para configurar, no repositório: **Settings → Secrets and variables → Actions → New repository secret**, com o nome `IMAGE_PUBLISH_SECRET` e como valor qualquer frase (por exemplo `openssl rand -hex 32`).

## 7. Verificar

```bash
docker run --rm infra-toolchain riscv32-unknown-elf-gcc --version
docker run --rm infra-toolchain riscv32-unknown-elf-gcc -print-multi-lib
docker run --rm infra-toolchain spike --help
docker run --rm infra-toolchain ghdl --version
docker buildx imagetools inspect ghcr.io/insper-riscv/infra-gcc:latest --format '{{json .Image}}'
```

O segundo comando deve imprimir só `.;` (uma variante, a raiz). O último mostra, para cada arquitetura, o commit do GCC no rótulo `riscv-gnu-toolchain.commit`, e lista `linux/amd64` e `linux/arm64`.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../LICENSE).
