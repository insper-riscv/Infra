# Imagens Docker da toolchain

Três imagens Docker com o que o fluxo de testes RISC-V precisa, exceto o Quartus: uma só com o GCC, uma só com o Spike e uma completa (GHDL, GCC RISC-V com picolibc, Spike e `uv`) que copia os artefatos das duas primeiras. Os `Dockerfile` ficam na raiz deste repositório, e três workflows as publicam no GitHub Container Registry.

## 1. As três imagens

| Imagem | `Dockerfile` | Workflow | Conteúdo | Tags |
| :--- | :--- | :--- | :--- | :--- |
| `ghcr.io/<organização>/infra-gcc` | `Dockerfile.gcc` | `GCC image` | Só `/opt/riscv-foundation/riscv32-elf` | `<commit>` e `latest` |
| `ghcr.io/<organização>/infra-spike` | `Dockerfile.spike` | `Spike image` | Só `/opt/riscv-foundation/spike` | `<commit>` e `latest` |
| `ghcr.io/<organização>/infra-toolchain` | `Dockerfile` | `Toolchain image` | A imagem completa | `latest`, `sha-<commit do Infra>` e `gcc-<7 primeiros>-spike-<7 primeiros>` |

O `<commit>` das duas primeiras é o commit do `riscv-collab/riscv-gnu-toolchain` e do `riscv-software-src/riscv-isa-sim` de que foram compiladas, e fica também no rótulo `riscv-gnu-toolchain.commit` ou `riscv-isa-sim.commit` da imagem. As imagens de componente não têm sistema de arquivos além desses diretórios, então não dá para executá-las: elas existem para serem copiadas.

## 2. O que a imagem completa contém

| Componente | Detalhe | Caminho |
| :--- | :--- | :--- |
| GHDL | Backend mcode, herdado da imagem base `ghdl/ghdl` | `/opt/ghdl` |
| GCC RISC-V | Alvo `rv32im`/`ilp32` com picolibc, uma única variante de biblioteca (o que o [GCC_SETUP.md](GCC_SETUP.md) compila) | `/opt/riscv-foundation/riscv32-elf` |
| Spike | Com o módulo de debug movido do endereço `0x0` para `0x70000000` (o que o [SPIKE_SETUP.md](SPIKE_SETUP.md) compila) | `/opt/riscv-foundation/spike` |
| `uv` | Gerenciador de projetos Python | `/usr/local/bin` |

Os binários do GCC e do Spike já estão no `PATH` da imagem. Cada instalação guarda em `.tag` o commit de que foi compilada, e a imagem completa traz os dois rótulos de commit.

O Quartus não está em nenhuma das imagens, e um container não enxerga o USB-Blaster sem configuração extra do host. Os testes de hardware real continuam rodando no runner self-hosted descrito no [RUNNER_SETUP.md](RUNNER_SETUP.md).

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

## 4. Atualizando o GCC ou o Spike

Cada componente tem um workflow de execução manual. Em Actions, escolha `GCC image` ou `Spike image` e clique em **Run workflow**, preenchendo:

| Campo | Significado |
| :--- | :--- |
| `confirm` | O valor do secret `IMAGE_PUBLISH_SECRET` (veja a seção 6) |
| `commit` | O commit a compilar. Vazio: o mais recente da branch padrão do projeto |
| `force` | Recompilar e republicar mesmo que a imagem desse commit já exista |

O workflow resolve o commit, confere se `infra-gcc:<commit>` (ou `infra-spike:<commit>`) já existe e, se existir e `force` estiver desligado, não compila nada. Caso contrário, compila, confere a instalação e publica com as tags `<commit>` e `latest`.

Os dois workflows de componente também rodam sozinhos num push na `main` que altere o próprio `Dockerfile.gcc` ou `Dockerfile.spike`, ou o próprio workflow. Nesse caso não há campo `commit`: eles recompilam o commit que a imagem `latest` já tem (a receita mudou, a versão não) com `force` ligado, e só usam o commit mais recente do upstream quando ainda não há imagem publicada. Por isso o merge que adiciona os três `Dockerfile` já publica os dois componentes pela primeira vez.

Quando um desses workflows termina com sucesso, o `Toolchain image` roda sozinho: lê os commits dos rótulos das duas imagens `latest` e monta e publica uma imagem completa nova. Atualizar só o Spike leva alguns minutos, e atualizar o GCC leva de dezenas de minutos a mais de uma hora.

O `Toolchain image` não espera um componente terminar: se, ao rodar por um push ou pelo fim de outro componente, houver um run de `GCC image` ou `Spike image` na fila ou em andamento, ele pula com um aviso, e o fim desse run o dispara de novo. O último componente a terminar faz a montagem única. Um run manual do `Toolchain image` nunca adia.

O `Toolchain image` precisa das duas imagens `latest`. Se um push chegar antes de elas existirem, ele termina com um aviso, sem falhar, e roda quando os componentes terminarem. Um run manual dele sem as imagens falha, com uma mensagem que aponta os dois workflows.

## 5. Construindo localmente

Os componentes não têm commit padrão, então o commit é passado no build:

```bash
docker build -f Dockerfile.gcc -t infra-gcc \
  --build-arg RISCV_GNU_TOOLCHAIN_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .

docker build -f Dockerfile.spike -t infra-spike \
  --build-arg RISCV_ISA_SIM_COMMIT="$(git ls-remote https://github.com/riscv-software-src/riscv-isa-sim HEAD | cut -f1)" .

docker build -t infra-toolchain \
  --build-arg GCC_IMAGE=infra-gcc --build-arg SPIKE_IMAGE=infra-spike .
```

O build do GCC leva de dezenas de minutos a mais de uma hora, conforme a máquina. Sem `GCC_IMAGE` e `SPIKE_IMAGE`, o build da imagem completa usa as imagens `latest` publicadas no GHCR. Os outros argumentos:

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `GHDL_IMAGE` | `ghdl/ghdl:6.0.0-mcode-ubuntu-24.04` | Imagem base, que traz o GHDL |
| `UV_VERSION` | versão fixa | Versão do `uv` (só no `Dockerfile` completo) |

## 6. Publicação e segurança

Os três workflows publicam em `ghcr.io/<organização>/`, com o `GITHUB_TOKEN` do próprio run. A visibilidade de cada pacote (público ou privado) é definida nas configurações do pacote no GitHub, e não pelo workflow. Os três pacotes precisam ficar acessíveis a quem vai usá-los, e o `Toolchain image` lê os outros dois.

A execução manual de qualquer um dos três pede o campo `confirm`, que precisa ser igual ao valor do secret `IMAGE_PUBLISH_SECRET`. É o mesmo segundo portão descrito na Fase 5 do [RUNNER_SETUP.md](RUNNER_SETUP.md): o acesso de escrita ao repositório já controla quem pode disparar o workflow, e o secret garante que só quem o conhece publique a imagem. Os três workflows também rodam num push na `main` que altere o `Dockerfile` correspondente ou o próprio workflow, e o `Toolchain image` roda ainda depois que um dos dois workflows de componente termina. Esses caminhos não pedem `confirm`: o portão do push é a proteção de branch, e o de componente já passou pelo `confirm` ou pelo push do seu run.

Para configurar, no repositório: **Settings → Secrets and variables → Actions → New repository secret**, com o nome `IMAGE_PUBLISH_SECRET` e como valor qualquer frase (por exemplo `openssl rand -hex 32`).

## 7. Verificar

```bash
docker run --rm infra-toolchain riscv32-unknown-elf-gcc --version
docker run --rm infra-toolchain riscv32-unknown-elf-gcc -print-multi-lib
docker run --rm infra-toolchain spike --help
docker run --rm infra-toolchain ghdl --version
docker buildx imagetools inspect ghcr.io/insper-riscv/infra-gcc:latest --format '{{json .Image.Config.Labels}}'
```

O segundo comando deve imprimir só `.;` (uma variante, a raiz). O último mostra o commit do GCC no rótulo `riscv-gnu-toolchain.commit`.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../LICENSE).
