# Configurando um runner self-hosted (guia passo a passo)

Cobre uma workstation com acesso a hardware FPGA (Quartus + JTAG). `/opt`
em si é padrão do FHS (Filesystem Hierarchy Standard) para software
instalado manualmente/add-on, fora do gerenciador de pacotes da distro; os
nomes das subpastas abaixo dele (`actions-runner`, `altera_lite`,
`riscv-foundation`) são uma convenção sugerida. Ajuste conforme o setup da
sua máquina.

## Visão geral

```
/opt/actions-runner/      home do usuário de serviço "runner" (o runner do GitHub Actions em si)
/opt/altera_lite/         instalação real do Quartus, direto em /opt (pré-requisito, ver QUARTUS_INSTALL.md)
/opt/riscv-foundation/    cache compartilhado do que é compilado localmente para RISC-V (GCC, Spike)
```

## Pré-requisito: Instalar o Quartus Prime Lite

O Quartus precisa estar instalado direto em `/opt/altera_lite` antes de
seguir as fases abaixo: download, modo GUI/CLI, PATH global e atalho
`.desktop` estão em [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md).

## Fase 1: Usuário de serviço dedicado

O runner roda como um usuário de sistema **sem senha, sem sudo próprio, sem estar
no grupo do usuário admin**: isolamento deliberado.

```bash
sudo useradd -r -m -d /opt/actions-runner -s /usr/sbin/nologin runner
sudo passwd -l runner              # sem login por senha; só via sudo/systemd
sudo usermod -aG plugdev runner    # acesso ao USB-Blaster (defesa em profundidade)
```

- `-r` → UID/GID na faixa de sistema (normalmente abaixo de `1000`), escolhidos
  automaticamente entre os que já estão livres na máquina onde o comando roda.
- `-m -d /opt/actions-runner` → cria o home já no lugar certo, dono `runner:runner`.
- `-s /usr/sbin/nologin` → proposital: `runner` não deveria ter shell
  interativo de login algum, o que reduz a superfície de ataque de uma
  conta de serviço sem perda de funcionalidade. Detalhes de quais comandos
  isso afeta logo abaixo.

Por causa do `nologin`, `sudo -iu runner ...` e `sudo su - runner` falham:
todos os comandos deste guia usam `sudo -u runner bash -lc '...'` (sem
`-i`) em vez disso.

**Verifique, posteriormente, se a conta ficou configurada corretamente**:
o `-d` acima só garante o `HOME` certo no momento da criação. Se a conta
`runner` for recriada depois por outro caminho (outro script de
provisionamento, ou um `useradd runner` repetido sem quem o rodar saber
dessa convenção), o `/etc/passwd` passa a registrar `HOME=/home/runner`
(diretório que nunca existiu) em vez de `/opt/actions-runner`, o que
quebra silenciosamente
qualquer ferramenta que dependa de `$HOME` quando rodada manualmente via
`sudo -u runner`: por exemplo, o `uv` (ver [SPIKE_SETUP.md](SPIKE_SETUP.md))
falha com `Failed to initialize cache at /home/runner/.cache/uv: Permission denied` porque tenta criar cache num diretório inexistente/sem dono certo.

Verificar:
```bash
getent passwd runner   # confira o 6º campo (home)
```

Se estiver errado, corrigir:
```bash
sudo usermod -d /opt/actions-runner runner
```

## Fase 2: Registrar o runner no GitHub

**Onde pegar o token/URL**: no repo (ou na org, se for um runner de nível de
organização) → **Settings → Actions → Runners → New runner**. O token expira em
~1h, precisa copiar na hora.

```bash
sudo -u runner HOME=/opt/actions-runner bash -lc '
  cd /opt/actions-runner
  curl -o actions-runner.tar.gz -L <URL_DE_DOWNLOAD_DA_PAGINA>
  tar xzf actions-runner.tar.gz
  ./config.sh --url https://github.com/<org-ou-org/repo> --token <TOKEN_DA_PAGINA> \
      --labels self-hosted,quartus,fpga --name workstation-fpga --unattended
'
```

- `sudo -u runner ... bash -lc` (sem `-i`) e `HOME=/opt/actions-runner`
  explícito: ver Fase 1 (por que evitar `-i` com `nologin`, e por que
  passar `HOME=` mesmo quando a conta já está correta).
- **Se o token der erro de permissão do tipo "refusing to allow a Personal Access
  Token to create or update workflow ... without `workflow` scope"**: o token
  (fine-grained PAT) precisa da permissão **"Workflows"** habilitada (Read and
  write); é diferente de "Contents"/"Actions", e precisa ser adicionada
  explicitamente na tela de edição do token.

### Segurança: runner de nível de organização

Se o runner for registrado na ORG (não num repo específico), ele fica disponível
para **qualquer repo** que o *runner group* dele permitir: por padrão isso costuma
ser "All repositories", o que expõe essa máquina a repos públicos da mesma org.

**Obrigatório**: Org Settings → Actions → Runner groups → grupo onde esse runner
caiu → **Repository access → Selected repositories → só os repos que precisam
mesmo tocar hardware**. Sem isso, qualquer repo público da org alcança essa
máquina através do mesmo runner.

**O grupo tem que se chamar `FPGA`** (não o default "Default", nem
qualquer outro nome como "Workstation - FPGA"): é esse o grupo que os
workflows deste projeto esperam poder alcançar.

- **No registro** (`config.sh` sem `--runnergroup`): o CLI pergunta em
  qual grupo colocar o runner; escolha ou crie o grupo `FPGA` ali.
- **Se o runner já foi registrado num grupo errado**: mova-o em Org
  Settings → Actions → Runner groups → `FPGA` → **Runners → Add runner**,
  ou mude o grupo dele pela própria página do grupo em que está.

Um runner no grupo errado não dá erro claro: o job de um workflow que
precisa dele simplesmente fica preso em "Queued" para sempre, sem nenhuma
mensagem explicando por quê.

## Fase 3: Serviço systemd (autorun, sobrevive a reboot)

O script `svc.sh` que vem no pacote do runner assume que o próprio usuário do
serviço tem sudo (ele chama `sudo systemctl` internamente); como `runner` não
tem, a unit é escrita direto:

```bash
sudo tee /etc/systemd/system/gh-actions-runner.service <<'UNIT'
[Unit]
Description=GitHub Actions self-hosted runner (FPGA workstation)
After=network.target

[Service]
Type=simple
User=runner
WorkingDirectory=/opt/actions-runner
ExecStart=/opt/actions-runner/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now gh-actions-runner
sudo systemctl status gh-actions-runner --no-pager   # deve mostrar "active (running)"
```

## Fase 4: Cache compartilhado para GCC e Spike (`/opt/riscv-foundation`)

Sem esse cache, cada bateria de testes que o runner rodasse teria que
recompilar o GCC RISC-V e o Spike do zero antes mesmo de começar; com o
cache, o job só confere se o commit já compilado é o mesmo e recompila só
quando não é. Criar o diretório, clonar o código-fonte, compilar e colocar
no `PATH` global são passos específicos de cada toolchain:

- GCC RISC-V: [GCC_SETUP.md](GCC_SETUP.md).
- Spike: [SPIKE_SETUP.md](SPIKE_SETUP.md).

Para outro usuário (não precisa ser admin) também poder criar arquivos
nesse cache sem `sudo` toda vez, basta colocar ele no grupo `runner`: isso
não dá nenhum privilégio além do acesso a `/opt/riscv-foundation`, e não
garante escrita em arquivos que já existam com dono/permissão diferentes
(depende do modo de cada arquivo individual):

```bash
sudo usermod -aG runner <usuario>
```

**Nota**: mudança de grupo só vale numa sessão de shell nova. Para usar na sessão
atual sem deslogar: `sg runner -c "<comando>"`.

## Fase 5 (opcional, no GitHub): Secret para confirmar acionamento manual

Diferente das outras fases, isto se configura por repositório nas
configurações do GitHub, não na máquina: precisa ser repetido em cada repo
que usar esse runner para hardware real, e é opcional dependendo do modelo
de confiança do time.

Além do controle de acesso do repo (Fase 2), um segundo portão para disparo manual
via `workflow_dispatch`: útil se algum dia mais gente tiver acesso de escrita ao
repo sem dever poder acionar hardware físico.

- Repo → **Settings → Secrets and variables → Actions → New repository secret**
- Nome: `FPGA_RUN_SECRET`, valor: qualquer frase (ex: `openssl rand -hex 32`)
- No workflow, um `workflow_dispatch.inputs.confirm` comparado contra esse secret
  antes de qualquer passo que toque a placa (ver `real.yml` do projeto).

## Fase 6: Permissão para o runner resetar o JTAG

O workflow de hardware real do projeto (exemplo: `real.yml` em
[insper-riscv/Testes](https://github.com/insper-riscv/Testes)) tipicamente
checa `jtagconfig` antes de compilar e, se a chain estiver presa, tenta um
`killall jtagd` com recheck automático antes de falhar com uma mensagem clara
pedindo intervenção manual. Isso precisa de sudo sem senha só para esse
comando exato:

```bash
echo 'runner ALL=(root) NOPASSWD: /usr/bin/killall jtagd' | \
  sudo tee /etc/sudoers.d/runner-jtagd
```

Pegadinhas de hardware JTAG (porta USB mudando de número, autosuspend
derrubando a conexão, "chain broken" que só resolve com power-cycle) são
comportamento do hardware em si, não conteúdo de setup do runner: exemplo
documentado em
[HARDWARE_PROGRAMMING.md do insper-riscv/Testes](https://github.com/insper-riscv/Testes/blob/main/docs/HARDWARE_PROGRAMMING.md).

## Checklist final

- [ ] `sudo systemctl status gh-actions-runner` → `active (running)`
- [ ] Runner aparece **Idle** em Settings → Actions → Runners, com as labels certas
- [ ] Runner group restrito a **Selected repositories** (não "All repositories")
- [ ] Quartus no `PATH` global: `which quartus_pgm` e `quartus_pgm --version`
- [ ] GCC RISC-V e Spike compilados e no `PATH`: `which riscv32-unknown-elf-gcc` e `which spike`
- [ ] `jtagconfig` lê o device ID da placa sem erro
- [ ] Secret de confirmação manual configurado, se aplicável

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../LICENSE).
