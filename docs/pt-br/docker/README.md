# Imagens Docker: visão geral

As imagens Docker do projeto reúnem o que o fluxo de testes RISC-V precisa. Há três tipos.

| Tipo | Nome | O que é |
| :--- | :--- | :--- |
| Base | `base-*` | uma ferramenta por imagem (GHDL, Yosys com SymbiYosys, GCC, picolibc, Spike, Sail, GTKWave) e mais nada; existem para serem copiadas |
| CI | `ci-*` | as imagens em que o CI de um projeto roda; cada uma é a anterior mais outras ferramentas, em níveis |
| Final | `dev_tools` | o último nível, para o Dev Container |

Os `Dockerfile`s ficam na pasta `docker` do repositório (`base/`, `ci/` e `dev-tools/`) e um workflow por imagem as publica no GitHub Container Registry, em `ghcr.io/<organização>/`. Toda imagem é publicada para `linux/amd64` e `linux/arm64`, com as mesmas versões das mesmas ferramentas; o GHDL usa o backend LLVM nas duas, então uma simulação se comporta igual num PC e num ARM como o Mac.

## 1. Os níveis

```text
base-ghdl    base-yosys    uv
     └───────────┴──────────┘
                 ▼
            ci-vhdl            GHDL, Yosys, uv, Python, cocotb
                 │
                 │      base-gcc → base-picolibc      base-spike
                 │              └────────┬─────────────────┘
                 ▼                       ▼
            ci-asm   = ci-vhdl + GCC com picolibc + Spike
                 │
                 │      base-sail
                 │          │
                 ▼          ▼
            ci-elf   = ci-asm + Sail + dependências do ACT4
                 │
                 │      base-gtkwave
                 │          │
                 ▼          ▼
            dev_tools = ci-elf + GTKWave + usuário dev
```

| Nível | Imagem | Serve para | Acrescenta ao nível anterior |
| :--- | :--- | :--- | :--- |
| 1 | [`ci-vhdl`](ci-vhdl.md) | testes VHDL (cocotb, provas formais) | GHDL, Yosys com SymbiYosys, `uv`, Python 3.14, cocotb |
| 2 | [`ci-asm`](ci-asm.md) | testes em assembly e em C | GCC RISC-V com picolibc, Spike |
| 3 | [`ci-elf`](ci-elf.md) | testes ELF (ACT4) | Sail, Ruby, Bundler, dependências de um commit do ACT4 |
| 4 | [`dev_tools`](dev-tools.md) | Dev Container | GTKWave, usuário `dev` |

Cada nível contém todos os de baixo, então um job de CI usa o menor nível que tenha o que ele precisa.

As imagens base, uma por ferramenta:

| Imagem | Contém | Arquivo |
| :--- | :--- | :--- |
| `base-ghdl` | `/opt/ghdl` | [base-ghdl.md](base-ghdl.md) |
| `base-yosys` | `/opt/yosys` (Yosys e SymbiYosys) | [base-yosys.md](base-yosys.md) |
| `base-gcc` | `/opt/riscv-foundation/riscv32-elf` (binutils, GCC e libgcc) | [base-gcc.md](base-gcc.md) |
| `base-picolibc` | os arquivos que a picolibc instala no sysroot do GCC | [base-picolibc.md](base-picolibc.md) |
| `base-spike` | `/opt/riscv-foundation/spike` | [base-spike.md](base-spike.md) |
| `base-sail` | `/opt/riscv-foundation/sail` | [base-sail.md](base-sail.md) |
| `base-gtkwave` | `/opt/gtkwave` | [base-gtkwave.md](base-gtkwave.md) |

Uma imagem base não tem sistema de arquivos além do diretório de instalação, então não pode ser executada.

## 2. Tags e rótulos

| Imagem | Tags |
| :--- | :--- |
| `base-*` | o commit (ou a versão) da ferramenta e `latest`; o formato exato está no arquivo de cada uma |
| `ci-*` e `dev_tools` | `latest`, `sha-<commit do Infra>` e uma tag de combinação que nomeia tudo o que entrou na imagem |

A tag de combinação de um nível acima nomeia o início do digest da imagem abaixo e os commits dos componentes que ele acrescenta. Qualquer mudança em qualquer nível de baixo gera, portanto, uma combinação nova.

Toda imagem leva os rótulos `org.opencontainers.image.title`, `description`, `source`, `revision` (o commit deste repositório que a construiu) e `created`, definidos pelo workflow, e os rótulos de commit dos seus componentes (`ghdl.commit`, `riscv-gnu-toolchain.commit`, `picolibc.commit`, `riscv-isa-sim.commit`, `yosys.commit`, `sby.commit`, `sail-riscv.commit`, `gtkwave.commit`, `act4.commit`, `uv.version`). Os rótulos são definidos explicitamente porque uma imagem construída sobre a base Ubuntu herdaria o título, a descrição e a data da imagem do Ubuntu.

## 3. Usando as imagens de CI

Escolha o nível que tem as ferramentas do job. Interativamente, com o diretório atual montado:

```bash
docker run --rm -it -v "$PWD:/workspace" ghcr.io/insper-riscv/ci-asm:latest
```

Num job do GitHub Actions:

```yaml
jobs:
  sim:
    runs-on: ubuntu-26.04
    container:
      image: ghcr.io/insper-riscv/ci-asm:latest
    steps:
      - uses: actions/checkout@v7.0.1
      - run: riscv32-unknown-elf-gcc --version
```

Para um resultado reproduzível, use a tag `sha-<commit>` da publicação desejada no lugar de `latest`.

## 4. Atualização automática

Cada imagem base tem um workflow que roda todo dia (UTC), sem campo a preencher. As quatro imagens montadas (`ci-vhdl`, `ci-asm`, `ci-elf` e `dev_tools`) são construídas por um workflow só, o `CI images`, cujos jobs rodam um depois do outro, do nível 1 ao 4. Ele roda todo dia, o que também consulta o `uv` (que não tem imagem base) e pega o GTKWave mais recente, e quando uma imagem base que ele usa termina. Uma imagem base que não acha novidade ainda termina com sucesso, então o workflow roda todo dia depois das bases.

| Workflow | Quando | O que observa |
| :--- | :--- | :--- |
| `GHDL image` | todo dia, 03:00 | a release `6.x.y` mais recente |
| `Picolibc image` | todo dia, 03:10, e quando a `GCC image` termina | a release `1.x.y` mais recente, compilada com o GCC mais recente |
| `Yosys image` | todo dia, 03:00 | a release `v0.N` mais recente do Yosys, com o `sby` da mesma versão |
| `GTKWave image` | todo dia, 03:00 | a ponta da branch `lts` |
| `Spike image` | todo dia, 03:00 | o commit mais recente do upstream com CI verde (pode esperar até 60 minutos por um CI em andamento) |
| `GCC image` | todo dia, 03:00 | o commit mais recente do `riscv-gnu-toolchain` cujo `Build` passou |
| `Sail image` | todo dia, 03:00 | a release `0.N` estável mais recente |
| `CI images` | todo dia, 03:00, e quando `GHDL image`, `Yosys image`, `GCC image`, `Picolibc image`, `Spike image` ou `Sail image` termina | o `uv` mais recente da série 0, as seis bases acima, o GTKWave e, em cada nível, a imagem do nível abaixo |

Um run constrói **só se a imagem para aquela versão ainda não existir**; sem novidade, termina em segundos com um aviso.

As regras que valem para as imagens montadas (`ci-*` e `dev_tools`), que o `CI images` aplica em cada nível:

1. Ele lê os commits nos rótulos dos componentes que copia e, em cada nível, o digest da imagem do nível abaixo (a que acabou de ser construída no run, ou a publicada para a combinação).
2. Se algum componente ainda não foi publicado, termina com um aviso, sem falhar, e roda quando eles terminarem. Um run manual sem eles falha, com uma mensagem que aponta os workflows a rodar antes.
3. Se um workflow de que ela depende está na fila ou em execução, ela pula com um aviso, e o fim desse run a dispara de novo; o último a terminar faz a única montagem. Um run manual nunca adia.
4. Cada nível publica só para uma combinação que ainda não existe. Um nível pulado por esse motivo não impede o seguinte, porque a imagem abaixo dele pode ter mudado; um nível que falha impede os de cima.

**Mudar um `Dockerfile` ou um workflow não constrói nada.** Uma imagem é construída quando uma versão muda, não quando a receita muda, para que uma mudança de receita sem versão nova não reconstrua para nada imagens que levam até uma hora. Quando uma receita muda na `main`, o workflow `Recipe changed` lista as imagens afetadas, e a reconstrução é um run manual (`force` num componente, `from_level` no `CI images`).

Cada arquitetura é construída num runner próprio (`ubuntu-26.04` para `linux/amd64` e `ubuntu-24.04-arm` para `linux/arm64`), porque os builds do GCC e do GHDL levam horas sob emulação. Um job final junta as duas imagens num manifesto único com as tags, e `docker pull` entrega a cada máquina a sua.

### 4.1. Execução manual

Todo workflow de imagem pode ser disparado em **Actions → Run workflow**. O campo `confirm` é obrigatório (ver a seção 5). Os componentes têm ainda `commit` (vazio: o mais recente) e `force` (reconstrói e republica mesmo que a imagem daquele commit já exista). O `CI images` tem `from_level` no lugar de `force`: reconstrói esse nível e os de cima, seja o que estiver publicado; os demais campos estão no arquivo de cada imagem.

## 5. Publicação e segurança

Os workflows de imagem publicam em `ghcr.io/<organização>/`, com o `GITHUB_TOKEN` do próprio run. A visibilidade de cada pacote (público ou privado) é definida nas configurações do pacote no GitHub, e não pelo workflow. Todos os pacotes precisam ficar acessíveis a quem vai usá-los, e o `Toolchain image` lê os pacotes dos componentes.

A execução manual de qualquer um dos workflows de imagem pede o campo `confirm`, que precisa ser igual ao valor do secret `IMAGE_PUBLISH_SECRET`. É o mesmo segundo portão descrito na seção 9 do [RUNNER_SETUP.md](../RUNNER_SETUP.md): o acesso de escrita ao repositório já controla quem pode disparar o workflow, e o secret garante que só quem o conhece publique a imagem. As imagens montadas rodam ainda depois que o que elas copiam termina. Esses caminhos não pedem `confirm`; o portão do agendamento é a proteção de branch, e o run que segue outro já passou pelo `confirm` dele.

Para configurar, no repositório: **Settings → Secrets and variables → Actions → New repository secret**, com o nome `IMAGE_PUBLISH_SECRET` e como valor qualquer frase (por exemplo `openssl rand -hex 32`).

## 6. Limpando versões antigas

Cada publicação acrescenta versões ao pacote, e nenhum workflow nosso as remove. O `scripts/cleanup-images.sh` apaga as antigas e mantém o que a tag `latest` alcança: o manifesto com a tag `latest` e todos os manifestos abaixo dele (a imagem de cada arquitetura e a atestação). Esses manifestos não têm tag própria e são o que mantém o `latest` baixável, então um simples "apagar as versões sem tag" o quebraria. Todo o resto é apagado, com tag ou sem, incluindo as tags de commits anteriores.

```bash
scripts/cleanup-images.sh                        # todos os pacotes, só listando
scripts/cleanup-images.sh base-gcc dev_tools    # só estes, só listando
scripts/cleanup-images.sh --delete base-gcc     # apaga de verdade
```

| Salvaguarda | O que faz |
| :--- | :--- |
| Listar primeiro | só apaga com `--delete` (no workflow: o campo `delete`, desligado por padrão) |
| Idade mínima | uma versão mais nova que `MIN_AGE_MINUTES` (120 por padrão) nunca é apagada, porque uma publicação envia a imagem de cada arquitetura sem tag e só no fim põe a tag no manifesto acima delas |
| Sem `latest` | um pacote sem versão com a tag `latest`, ou cujo manifesto não pode ser lido, não é tocado |
| Manifesto ausente | um manifesto que o `latest` referencia e que não está mais no registro vira um aviso e não interrompe a execução |

O workflow `Clean up old image versions` o roda à mão, com o mesmo campo `confirm` das publicações. Com `delete` ligado, ele também se recusa a rodar enquanto algum workflow de imagem estiver na fila ou em execução.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
