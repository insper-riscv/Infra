# Imagens Docker da toolchain

Imagens Docker com o que o fluxo de testes RISC-V precisa, exceto o Quartus: uma para cada componente (GHDL, GCC, picolibc, Spike, e Yosys com SymbiYosys) e uma completa (esses, mais `uv`, Python e cocotb) que copia os artefatos dos componentes. Os `Dockerfile` ficam na raiz deste repositório, e um workflow por imagem as publica no GitHub Container Registry. Toda imagem é publicada para `linux/amd64` e `linux/arm64`, e as duas arquiteturas têm as mesmas versões das mesmas ferramentas: o GHDL tem o backend LLVM nas duas, então uma simulação se comporta igual num PC e numa máquina ARM, como um Mac.

## 1. As imagens

| Imagem | `Dockerfile` | Workflow | Conteúdo | Tags |
| :--- | :--- | :--- | :--- | :--- |
| `ghcr.io/<organização>/infra-ghdl` | `Dockerfile.ghdl` | `GHDL image` | Só `/opt/ghdl` | `<commit>` e `latest` |
| `ghcr.io/<organização>/infra-gcc` | `Dockerfile.gcc` | `GCC image` | Só `/opt/riscv-foundation/riscv32-elf` | `<commit do GCC>-<commit da picolibc>` e `latest` |
| `ghcr.io/<organização>/infra-picolibc` | `Dockerfile.picolibc` | `Picolibc image` | Só os arquivos que a picolibc instala no sysroot do GCC, em `/opt/riscv-foundation/riscv32-elf` (a entrada do build da imagem do GCC) | `<commit da picolibc>-<commit do GCC>` e `latest` |
| `ghcr.io/<organização>/infra-spike` | `Dockerfile.spike` | `Spike image` | Só `/opt/riscv-foundation/spike` | `<commit>` e `latest` |
| `ghcr.io/<organização>/infra-yosys` | `Dockerfile.yosys` | `Yosys image` | Só `/opt/yosys` (Yosys e SymbiYosys) | `<commit do Yosys>-<commit do sby>` e `latest` |
| `ghcr.io/<organização>/infra-toolchain` | `Dockerfile` | `Toolchain image` | A imagem completa | `latest`, `sha-<commit do Infra>` e `ghdl-<7 primeiros>-gcc-<7 primeiros>-spike-<7 primeiros>-yosys-<7 primeiros>-sby-<7 primeiros>-uv-<versão>` |

O `<commit>` das três primeiras é o commit do `ghdl/ghdl` (o da tag de release), do `riscv-collab/riscv-gnu-toolchain` e do `riscv-software-src/riscv-isa-sim` de que foram compiladas, e fica também no rótulo `ghdl.commit`, `riscv-gnu-toolchain.commit` ou `riscv-isa-sim.commit` da imagem. As imagens de componente não têm sistema de arquivos além desses diretórios, então não dá para executá-las: elas existem para serem copiadas.

Toda imagem leva os rótulos `org.opencontainers.image.title`, `description`, `source`, `revision` (o commit deste repositório que a construiu) e `created` (quando foi construída), definidos pelo workflow, e os rótulos de commit dos seus componentes (`ghdl.commit`, `riscv-gnu-toolchain.commit`, `riscv-isa-sim.commit`, `gtkwave.commit`, `uv.version`). Eles são definidos explicitamente porque uma imagem construída sobre a base Ubuntu herdaria o título, a descrição e a data da imagem do Ubuntu.

## 2. O que a imagem completa contém

| Componente | Detalhe | Caminho |
| :--- | :--- | :--- |
| GHDL | Backend LLVM, compilado do código-fonte (o backend mcode das imagens `ghdl/ghdl` é só x86, e as duas arquiteturas precisam rodar o mesmo GHDL) | `/opt/ghdl` |
| GCC RISC-V | Alvo `rv32im`/`ilp32`, uma única variante de biblioteca (o que o [GCC_SETUP.md](GCC_SETUP.md) compila) | `/opt/riscv-foundation/riscv32-elf` |
| picolibc | A biblioteca C desse GCC, compilada pela própria imagem e instalada no sysroot antes do segundo estágio do build do GCC, então o libgcc e o libstdc++ do GCC são compilados contra ela | `/opt/riscv-foundation/riscv32-elf/riscv32-unknown-elf` |
| Spike | Com o módulo de debug movido do endereço `0x0` para `0x70000000` (o que o [SPIKE_SETUP.md](SPIKE_SETUP.md) compila) | `/opt/riscv-foundation/spike` |
| `uv` | Gerenciador de projetos Python | `/usr/local/bin` |
| Python | 3.14, instalado pelo `uv` para todos os usuários, com `python3` e `python` no `PATH` | `/opt/uv/python` |
| cocotb | 2.1.0, instalado nesse Python | `/opt/uv/python` |
| Yosys | 0.69, compilado do código-fonte; lê o netlist Verilog que o GHDL sintetiza a partir do VHDL | `/opt/yosys` |
| SymbiYosys (`sby`) | v0.69, compilado do código-fonte com o Yosys; executa o Yosys e os solvers | `/opt/yosys` |
| `z3` e `boolector` | os solvers SMT que o SymbiYosys usa, do Ubuntu | `/usr/bin` |

O GHDL, o GCC e o Spike já estão no `PATH` da imagem. O `gcc` do host também está na imagem, porque o backend LLVM liga com ele o projeto que elabora; o do RISC-V mantém os próprios nomes `riscv32-unknown-elf-`. Com o backend LLVM o `ghdl -r` precisa de um `ghdl -e` antes (ou use `ghdl --elab-run`); os Makefiles e o runner de simulação já fazem isso. Cada instalação guarda em `.tag` o commit de que foi compilada, e a imagem completa traz os três rótulos de commit.

O Python é fixado em 3.14 porque é a versão que os projetos exigem (`>=3.14,<3.15`), e o cocotb 2.1.0 é a primeira versão que a suporta: o cocotb é quem fixa a versão do Python, então um Python mais novo espera um cocotb que o suporte (os argumentos de build `PYTHON_VERSION` e `COCOTB_VERSION` mudam os dois juntos). Todo projeto simula com o cocotb, então ele está na imagem (o cocotb 2.1.0 tem wheels para o Python 3.14 em Linux x86-64, macOS e Windows, mas não em Linux arm64, então no arm64 ele é compilado, e é por isso que a imagem tem `g++`, e o `uv sync` de um projeto também o compila lá); as outras bibliotecas Python são de cada projeto e vêm do `uv sync` dele, que encontra este Python em vez de baixar outro.

O Quartus não está em nenhuma das imagens. A imagem completa tem a biblioteca de sistema que as ferramentas de linha de comando de uma instalação do Quartus usam (`libglib2.0-0t64`), então uma instalação do host pode ser montada nela e executada ali (seção 3.1). Os testes de hardware real de um projeto dividem o trabalho: as ROMs de teste e seus goldens são construídos dentro da imagem completa, e o Quartus e o cabo JTAG são usados a partir do runner self-hosted descrito no [RUNNER_SETUP.md](RUNNER_SETUP.md), que precisa de Docker e de acesso a ele.

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

### 3.1. Quartus do host

O Quartus do host (aqui `/opt/altera_lite/25.1std`) é montado somente para leitura e colocado no `PATH` dentro do container. O USB-Blaster é alcançado pelo servidor JTAG (`jtagd`) do host, que o container enxerga ao compartilhar a rede do host:

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -e HOME=/tmp/h \
  -v "$PWD:/workspace" -v /opt/altera_lite:/opt/altera_lite:ro \
  ghcr.io/insper-riscv/infra-toolchain:latest bash -c '
    export PATH=/opt/altera_lite/25.1std/quartus/bin:$PATH
    jtagconfig
    cd platforms/sdram-bringup/quartus && quartus_sh --flow compile sdram_bringup'
```

| Opção | Para que serve |
| :--- | :--- |
| `-v /opt/altera_lite:/opt/altera_lite:ro` | a instalação do Quartus, somente leitura; a imagem não traz nenhuma |
| `--network host` | o `jtagd` escuta em `localhost:1309` do host, e o programador e o `quartus_stp` do container se conectam a ele ali |
| `--user "$(id -u):$(id -g)"` e `-e HOME=/tmp/h` | os arquivos que o build escreve pertencem ao usuário que chamou, e o Quartus tem um home gravável |

O `jtagd` precisa estar rodando no host, e ele pode parar sozinho entre dois usos. Rode o `jtagconfig` no host logo antes do container: ele inicia o `jtagd` se nenhum estiver rodando. Sem um `jtagd` no host, o container inicia um próprio, que não enxerga o USB, e o `jtagconfig` dentro do container imprime:

```text
1) USB-Blaster variant [3-5]
  Unable to lock chain - Bad port name
```

Com o `jtagd` do host rodando, o mesmo comando imprime o cabo e o chip (`USB-Blaster [3-5]`, `02B050DD 5CE(BA4|FA4)` na DE0-CV). Num daemon do Docker com remapeamento de usuários (user namespace), o `--network host` é recusado a menos que a execução também use `--userns=host`.

### 3.2. Verificação formal

O GHDL transforma uma entidade VHDL num netlist Verilog, que o Yosys lê e sobre o qual o SymbiYosys prova propriedades. As propriedades são escritas em SystemVerilog em volta do netlist, então nenhum plugin do GHDL para o Yosys é necessário:

```bash
ghdl -a --std=08 --workdir=work meu_bloco.vhd
ghdl --synth --std=08 --workdir=work --out=verilog meu_bloco > meu_bloco.v
sby -f meu_bloco.sby
```

O arquivo `.sby` informa o modo (`prove` para uma prova ilimitada por indução, `bmc` para uma checagem limitada, `cover` para confirmar que as propriedades não são vazias), a profundidade, o motor (`smtbmc z3`) e os arquivos. Uma prova que falha grava uma forma de onda do contraexemplo ao lado do log.

## 4. Atualizando o GHDL, o GCC ou o Spike

Cada componente tem um workflow de execução manual. Em Actions, escolha `GHDL image`, `GCC image`, `Picolibc image`, `Spike image` ou `Yosys image` e clique em **Run workflow**, preenchendo:

| Campo | Significado |
| :--- | :--- |
| `confirm` | O valor do secret `IMAGE_PUBLISH_SECRET` (veja a seção 6) |
| `commit` | O commit a compilar. Vazio: o mais recente da branch padrão do projeto (no GHDL, o commit da tag de release mais recente) |
| `force` | Recompilar e republicar mesmo que a imagem desse commit já exista |

O `Picolibc image` recebe um `commit` da picolibc (vazio: a tag de release mais recente da série definida em `SERIES`, `1`, ou seja `1.x.y`) e a compila com o GCC da imagem mais recente do GCC. O `GCC image` é construído a partir dessa picolibc, então uma picolibc nova faz a imagem do GCC ser construída de novo: ele roda sozinho quando o `Picolibc image` termina, mantém o commit do GCC que já tem e executa só o segundo estágio do build, com a picolibc compilada já no sysroot; o primeiro compilador, que só existia para compilar a picolibc, é pulado. Um GCC novo (um run manual do `GCC image`) reaproveita a picolibc que já existe e não a compila de novo. A imagem do GCC leva no rótulo `picolibc.commit` a picolibc contra a qual foi construída, e o `Toolchain image` só monta quando ela é a picolibc mais recente, esperando o build da imagem do GCC caso contrário.

O GCC com que a picolibc é compilada é o publicado antes dela, então a biblioteca vem do GCC do build anterior, e não daquele com que é instalada.

O `Spike image` não tem release para seguir (a última, `v1.1.0`, é de 2021), então um `commit` vazio pega o commit mais recente da branch `master` do `riscv-isa-sim` em que os workflows dele, `Continuous Integration` e `Debug Quick Test`, passaram. Um commit mais novo cujos workflows ainda estão rodando é aguardado, por até 60 minutos; um que falhou é pulado, e também um sem execução deles; um re-run que passou conta. O campo extra `ignore_ci` pega o topo da branch, seja qual for o resultado dos workflows. A escolha, com o estado de cada commit que olhou, vai para o resumo do run.

O `Yosys image` tem mais um campo, `sby_commit` (vazio: a tag do `sby` com a mesma versão da release do Yosys), porque a imagem guarda os dois e o campo `commit` é o commit do Yosys. O `commit` vazio pega a tag de release mais recente da série definida em `SERIES` (`0`, ou seja `v0.N`, nunca uma branch em movimento).

O workflow resolve o commit, confere se `infra-gcc:<commit do GCC>-<commit da picolibc>` (ou `infra-spike:<commit>`, ou `infra-picolibc:<commit da picolibc>-<commit do GCC>`, ou `infra-yosys:<commit do Yosys>-<commit do sby>`) já existe e, se existir e `force` estiver desligado, não compila nada. Caso contrário, compila, confere a instalação e publica com as tags `<commit>` e `latest`.

Os workflows de componente também rodam sozinhos, uma vez por dia (UTC), sem nenhum campo a preencher:

| Workflow | Quando | O que olha |
| :--- | :--- | :--- |
| `GHDL image` | todo dia, 03:00 | a release `6.x.y` mais recente |
| `Picolibc image` | todo dia, 03:10 | a release `1.x.y` mais recente |
| `Yosys image` | todo dia, 03:20 | a release `v0.N` mais recente do Yosys, com o `sby` da mesma versão |
| `GTKWave image` | todo dia, 03:30 | a release `3.3.x` mais recente |
| `Spike image` | todo dia, 03:40 | o commit mais recente do upstream com CI verde (pode esperar até 60 minutos por um que esteja rodando) |
| `GCC image` | toda segunda-feira, 04:00 | o HEAD do `riscv-gnu-toolchain` |
| `Toolchain image` | todo dia, 05:00 | o `uv` mais recente da série 0, e a combinação dos componentes |

Um run agendado constrói **só se a imagem dessa versão ainda não existir**; quando nada mudou, termina em segundos com um aviso. O `GCC image` também roda quando o `Picolibc image` termina, e o `Toolchain image` e o `Dev tools image` rodam quando um componente termina, como descrito abaixo.

**Uma mudança num `Dockerfile` ou num workflow não constrói nada.** Uma imagem é construída quando uma versão muda, não quando a receita muda, então uma mudança de receita que não é uma versão nova não reconstrói uma imagem à toa (o GCC e o GHDL levam quase uma hora). O workflow `Recipe changed` roda no merge dessa mudança, escreve um aviso no run e comenta no commit, listando as imagens que a mudança afeta. Para publicá-las com a receita nova, rode à mão o workflow de cada uma com `force` ligado.

Quando um desses workflows termina com sucesso, o `Toolchain image` roda sozinho: lê os commits dos rótulos das três imagens `latest` e monta e publica uma imagem completa nova. Atualizar só o Spike leva alguns minutos, e atualizar o GCC ou o GHDL leva de dezenas de minutos a mais de uma hora.

Cada arquitetura é compilada num runner dela (`ubuntu-26.04` para `linux/amd64` e `ubuntu-24.04-arm` para `linux/arm64`): os builds do GCC e do GHDL levam horas sob emulação. Um job final junta as duas imagens num só manifesto com as tags, e o `docker pull` entrega a cada máquina a sua.

O `uv` é o único componente sem imagem nossa: a imagem completa o copia da imagem oficial `ghcr.io/astral-sh/uv`. Ele segue a mesma regra dos outros, no `Toolchain image`: um run disparado por um push ou pelo fim de um componente mantém o `uv` que a imagem `latest` já tem (o rótulo `uv.version`), e um run manual usa o campo `uv_version`, que vazio significa a última release estável do `astral-sh/uv`. A versão entra também na tag de combinação (`ghdl-<7>-gcc-<7>-spike-<7>-uv-<versão>`). Para atualizar o `uv`, rode o `Toolchain image` à mão com `confirm` e o `uv_version` vazio.

O `Toolchain image` não espera um componente terminar: se, ao rodar por um agendamento ou pelo fim de outro componente, houver um run de `GHDL image`, `GCC image`, `Picolibc image`, `Spike image` ou `Yosys image` na fila ou em andamento, ele pula com um aviso, e o fim desse run o dispara de novo. O último componente a terminar faz a montagem única. Um run manual do `Toolchain image` nunca adia.

O `Toolchain image` precisa da imagem `latest` de cada componente. Se um run começar antes de elas existirem, ele termina com um aviso, sem falhar, e roda quando os componentes terminarem. Um run manual dele sem as imagens falha, com uma mensagem que aponta os workflows dos componentes.

## 5. Construindo localmente

Os componentes não têm commit padrão, então o commit é passado no build:

```bash
docker build -f Dockerfile.ghdl -t infra-ghdl \
  --build-arg GHDL_COMMIT="$(git ls-remote https://github.com/ghdl/ghdl 'refs/tags/v6.0.0^{}' | cut -f1)" .

docker build -f Dockerfile.gcc -t infra-gcc \
  --build-arg PICOLIBC_IMAGE=ghcr.io/<organização>/infra-picolibc:latest \
  --build-arg PICOLIBC_COMMIT="<o rótulo picolibc.commit dessa imagem>" \
  --build-arg RISCV_GNU_TOOLCHAIN_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .

docker build -f Dockerfile.picolibc -t infra-picolibc \
  --build-arg GCC_IMAGE=infra-gcc \
  --build-arg PICOLIBC_COMMIT="$(git ls-remote https://github.com/picolibc/picolibc 'refs/tags/1.8.12^{}' | cut -f1)" \
  --build-arg GCC_COMMIT="$(git ls-remote https://github.com/riscv-collab/riscv-gnu-toolchain HEAD | cut -f1)" .

docker build -f Dockerfile.spike -t infra-spike \
  --build-arg RISCV_ISA_SIM_COMMIT="$(git ls-remote https://github.com/riscv-software-src/riscv-isa-sim HEAD | cut -f1)" .

docker build -f Dockerfile.yosys -t infra-yosys \
  --build-arg YOSYS_COMMIT="$(git ls-remote https://github.com/YosysHQ/yosys 'refs/tags/v0.69^{}' | cut -f1)" \
  --build-arg SBY_COMMIT="$(git ls-remote https://github.com/YosysHQ/sby 'refs/tags/v0.69^{}' | cut -f1)" .

docker build -t infra-toolchain \
  --build-arg GHDL_IMAGE=infra-ghdl --build-arg GCC_IMAGE=infra-gcc --build-arg SPIKE_IMAGE=infra-spike \
  --build-arg YOSYS_IMAGE=infra-yosys .
```

O build do GCC leva de dezenas de minutos a mais de uma hora, conforme a máquina. Sem `GHDL_IMAGE`, `GCC_IMAGE`, `SPIKE_IMAGE` e `YOSYS_IMAGE`, o build da imagem completa usa as imagens `latest` publicadas no GHCR. Os outros argumentos:

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | Imagem base de todos os builds (uma imagem multi-arquitetura) |
| `UV_VERSION` | versão fixa | Versão do `uv` (só no `Dockerfile` completo) |
| `PYTHON_VERSION` | `3.14` | Python instalado pelo `uv` (só no `Dockerfile` completo) |
| `COCOTB_VERSION` | `2.1.0` | cocotb instalado nele (só no `Dockerfile` completo) |

## 6. Publicação e segurança

Os workflows de imagem publicam em `ghcr.io/<organização>/`, com o `GITHUB_TOKEN` do próprio run. A visibilidade de cada pacote (público ou privado) é definida nas configurações do pacote no GitHub, e não pelo workflow. Todos os pacotes precisam ficar acessíveis a quem vai usá-los, e o `Toolchain image` lê os pacotes dos componentes.

A execução manual de qualquer um dos workflows de imagem pede o campo `confirm`, que precisa ser igual ao valor do secret `IMAGE_PUBLISH_SECRET`. É o mesmo segundo portão descrito na Fase 5 do [RUNNER_SETUP.md](RUNNER_SETUP.md): o acesso de escrita ao repositório já controla quem pode disparar o workflow, e o secret garante que só quem o conhece publique a imagem. Eles também rodam num push na `main` que altere o `Dockerfile` correspondente ou o próprio workflow, e o `Toolchain image` roda ainda depois que um dos três workflows de componente termina. Esses caminhos não pedem `confirm`: o portão do push é a proteção de branch, e o de componente já passou pelo `confirm` ou pelo push do seu run.

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

## 8. Por que cada versão

Tudo é fixado por nós, exceto os pacotes do próprio Ubuntu. O workflow que atualiza cada item fixado está na seção 4.

### 8.1 O que escolhemos

| Item | Versão | Por quê |
| :--- | :--- | :--- |
| Ubuntu | 26.04 LTS | a última versão de suporte longo, uma base multi-arquitetura (`amd64` e `arm64`), e a em que o GHDL 6.0.0 foi compilado e testado com o LLVM 21 |
| GHDL | 6.0.0 | a última release estável; a série é fixada em 6 (`SERIES` no workflow), então a 7.0.0, ainda em desenvolvimento, não entra sozinha |
| Backend do GHDL | LLVM | o backend `mcode` só roda em x86, e o mesmo simulador precisa se comportar igual num PC e numa máquina ARM, como um Mac |
| GCC RISC-V | 16.1.0, commit `d118e53` | compilado do fonte com a nossa configuração da picolibc (`rv32im`, `ilp32`, uma variante, sem CSR, sem ponto flutuante em hardware); segue o HEAD do `riscv-gnu-toolchain`, porque as releases dele são um instantâneo noturno do HEAD, e não um ponto estável; o build parte da picolibc compilada e executa só o segundo estágio, já que o primeiro compilador existia só para compilar a picolibc |
| picolibc | 1.8.12 | a release mais recente da série 1 (`SERIES` no workflow); compilada pela própria imagem com o GCC publicado antes dela, e o GCC é então construído contra ela a partir do segundo estágio, então o libgcc e o libstdc++ dele combinam com ela. Ela é compilada com as opções do build que o `riscv-gnu-toolchain` roda para ela (meson, tamanho mínimo, instalada no sysroot) |
| Spike | commit `89c7471` | o commit mais recente do `riscv-isa-sim` cujo CI próprio passou (`Continuous Integration` e `Debug Quick Test`), porque a última release (`v1.1.0`) é de 2021; o módulo de debug dele é movido do endereço `0x0` para `0x70000000`, para não se sobrepor à boot ROM |
| `uv` | 0.13.0 | a última release estável da série 0 (`UV_SERIES`); instala o Python e as dependências de cada projeto, e substitui o `pip` e os ambientes virtuais |
| Python | 3.14.8 | a versão que os projetos exigem (`>=3.14,<3.15`); o patch é o mais recente que o `uv` conhece |
| cocotb | 2.1.0 | a primeira release que suporta o Python 3.14 e a mais recente; todo projeto simula com ele, então está na imagem, e ele fixa a versão do Python: um Python mais novo espera um cocotb que o suporte. No `arm64` não há wheel e ele é compilado, por isso o `g++` |
| Yosys | 0.69 | a release mais recente da série 0 (`SERIES` no workflow), compilada do código-fonte porque o Ubuntu 26.04 tem a 0.52, mais antiga; a mais nova evita fundir propriedades formais (`opt_merge`, desde a 0.61) e acompanha o `sby` de mesmo número. O front-end de SystemVerilog baseado no Slang fica fora do build |
| SymbiYosys (`sby`) | v0.69 | lançado em passo com o Yosys (a `v0.N` de um com a `v0.N` do outro), então a imagem pega a tag com a versão do Yosys. Ele importa o `click`, que o `uv` instala no Python da imagem (8.5.0) |
| GTKWave (`dev_tools`) | 3.3.116 | a última release estável da série 3 (`SERIES`); a linha 4.0.0 é pré-alfa e sem release. Compilado da árvore GTK 3, que tem backend Wayland |

### 8.2 O que vem do Ubuntu

| Item | Versão | Por que está na imagem |
| :--- | :--- | :--- |
| LLVM | 21.1.8 | a biblioteca em que o backend LLVM do GHDL liga; é a que o `llvm-dev` instala no 26.04, e a com que o GHDL 6.0.0 foi testado aqui (o LLVM 22 existe e não foi testado) |
| `gcc` e `g++` (do host) | 15.2.0 | ligam o executável que o GHDL elabora e compilam o cocotb no `arm64`; o GCC RISC-V mantém os próprios nomes `riscv32-unknown-elf-`, então não conflitam |
| `git` | 2.53.0 | o checkout de um workflow |
| `make` | 4.4.1 | os Makefiles dos projetos e o `make` do próprio ACT4 |
| `curl` | 8.18.0 | instaladores e downloads |
| `libglib2.0-0t64` | 2.88.0 | `libglib-2.0` e `libgthread-2.0`, que as ferramentas de linha de comando de uma instalação do Quartus montada do host usam |
| `libreadline8t64`, `libtcl8.6` e `libffi8` | 8.3, 8.6.17 e 3.5.2 | as bibliotecas com que o Yosys da imagem é ligado |
| `z3` | 4.13.3 | o solver SMT que o SymbiYosys executa por padrão |
| `boolector` | 1.5.118 | um segundo solver SMT que o SymbiYosys pode usar |
| GTK 3 (`dev_tools`) | 3.24.52 | o que o GTKWave usa, com os backends Wayland e X11 |
| `gnat` (`dev_tools`) | 14 | o runtime e o compilador de Ada para compilar o GHDL ou código Ada no ambiente de desenvolvimento |

## 9. Limpando versões antigas

Cada publicação acrescenta versões ao pacote, e nenhum workflow nosso as remove. O `scripts/cleanup-images.sh` apaga as antigas e mantém o que a tag `latest` alcança: o manifesto com a tag `latest` e todos os manifestos abaixo dele (a imagem de cada arquitetura e a atestação). Esses manifestos não têm tag própria e são o que mantém o `latest` baixável, então um simples "apagar as versões sem tag" o quebraria. Todo o resto é apagado, com tag ou sem, incluindo as tags de commits anteriores.

```bash
scripts/cleanup-images.sh                        # todos os pacotes, só listando
scripts/cleanup-images.sh infra-gcc dev_tools    # só estes, só listando
scripts/cleanup-images.sh --delete infra-gcc     # apaga de verdade
```

| Salvaguarda | O que faz |
| :--- | :--- |
| Listar primeiro | só apaga com `--delete` (no workflow: o campo `delete`, desligado por padrão) |
| Idade mínima | uma versão mais nova que `MIN_AGE_MINUTES` (120 por padrão) nunca é apagada, porque uma publicação envia a imagem de cada arquitetura sem tag e só no fim põe a tag no manifesto acima delas |
| Sem `latest` | um pacote sem versão com a tag `latest`, ou cujo manifesto não pode ser lido, não é tocado |
| Manifesto ausente | um manifesto que o `latest` referencia e que não está mais no registro vira um aviso e não interrompe a execução |

O workflow `Clean up old image versions` o roda à mão, com o mesmo campo `confirm` das publicações. Com `delete` ligado, ele também se recusa a rodar enquanto algum workflow de imagem estiver na fila ou em execução.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../LICENSE).
