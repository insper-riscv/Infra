# Configurando um runner self-hosted (guia passo a passo)

Cobre uma workstation com acesso a hardware FPGA (Quartus + JTAG). `/opt`
em si é padrão do FHS (Filesystem Hierarchy Standard) pra software
instalado manualmente/add-on, fora do gerenciador de pacotes da distro; os
nomes das subpastas abaixo dele (`actions-runner`, `altera_lite`,
`riscv-foundation`) são uma convenção sugerida. Ajuste conforme o setup da
sua máquina.

## Visão geral

```
/opt/actions-runner/      home do usuário de serviço "runner" (o runner do GitHub Actions em si)
/opt/altera_lite/         instalação real do Quartus, direto em /opt (pré-requisito, ver QUARTUS_INSTALL.md)
/opt/riscv-foundation/    cache compartilhado de toolchains RISC-V (workstation inteira, não só um repo)
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

**O `nologin` quebra qualquer comando que force o shell de login
registrado**: `sudo -iu runner ...` (a flag `-i`, "simular login") ou
`sudo su - runner` sem `-s` tentam executar `nologin` como o shell em si,
que recusa e sai sem rodar nada. Prefira sempre `sudo -u runner bash -lc
'...'` (sem `-i`), que passa `bash` diretamente e nunca consulta o shell
registrado; é o padrão usado em todos os comandos deste guia. Pra um
shell interativo de depuração pontual, force explicitamente: `sudo su -s
/bin/bash - runner`.

**Confira depois que a conta bateu certo**: é comum o `/etc/passwd` acabar
registrando `HOME=/home/runner` (diretório que nunca existiu) em vez de
`/opt/actions-runner`, caso o `-d` seja omitido ou perdido em algum momento
depois da criação original (ex: um `usermod` posterior sem `-d`, ou a conta
recriada por outro caminho). Isso não afeta o serviço `systemd` (Fase 3 já
fixa `WorkingDirectory=/opt/actions-runner` explicitamente), mas quebra
silenciosamente qualquer ferramenta que dependa de `$HOME` quando rodada
manualmente via `sudo -u runner`: por exemplo, o `uv` (ver
[SPIKE_SETUP.md](SPIKE_SETUP.md)) falha com `Failed to initialize cache at
/home/runner/.cache/uv: Permission denied` porque tenta criar cache num
diretório inexistente/sem dono certo.

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
pra **qualquer repo** que o *runner group* dele permitir: por padrão isso costuma
ser "All repositories", o que expõe essa máquina a repos públicos da mesma org.

**Obrigatório**: Org Settings → Actions → Runner groups → grupo onde esse runner
caiu → **Repository access → Selected repositories → só os repos que precisam
mesmo tocar hardware**. Sem isso, qualquer repo público da org alcança essa
máquina através do mesmo runner.

**O grupo tem que se chamar `FPGA`** (não o default "Default", nem qualquer outro
nome tipo "Workstation - FPGA"): é esse o grupo que os workflows deste projeto
esperam poder alcançar. Durante o registro interativo (`config.sh` sem
`--runnergroup`), o CLI pergunta em qual grupo colocar o runner; escolha/crie o
grupo `FPGA` ali. Se o runner já foi registrado num grupo errado, mova-o depois em
Org Settings → Actions → Runner groups → `FPGA` → **Runners → Add runner** (ou
mude o grupo do runner existente pela própria página do grupo). Um runner no
grupo errado não dá erro claro; o job de um workflow que precisa dele
simplesmente fica preso em "Queued" pra sempre, sem nenhuma mensagem explicando
por quê.

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

## Fase 4: PATH do Quartus dentro do workflow

O `/etc/profile.d/quartus.sh` ([QUARTUS_INSTALL.md](QUARTUS_INSTALL.md), passo 5) resolve o `PATH` pra
**shells interativos/login**: ou seja, qualquer usuário abrindo um terminal
normal já tem `quartus`/`quartus_pgm`/`jtagconfig` disponíveis.

Isso **não** cobre o `runner`: o serviço roda via `systemd` (Fase 3), que não
passa por `/etc/profile` nem por nenhum shell de login. O processo herda só o
ambiente que o `systemd` monta pra unit, sem sourcing de rc files, então o
workflow precisa adicionar o caminho manualmente ao `$GITHUB_PATH`:

```yaml
run: echo "/opt/altera_lite/25.1std/quartus/bin" >> "$GITHUB_PATH"
```

(exemplo real: `.github/workflows/real.yml` no repo
[insper-riscv/Testes](https://github.com/insper-riscv/Testes))

## Fase 5: Cache compartilhado de toolchains (`/opt/riscv-foundation`)

Em vez de cada repo/usuário baixar sua própria cópia de toolchains grandes
(GCC RISC-V, Spike, etc.), um cache único pra workstation inteira:

```bash
sudo mkdir -p /opt/riscv-foundation
sudo chown runner:runner /opt/riscv-foundation
sudo chmod 2775 /opt/riscv-foundation   # setgid: arquivos novos herdam o grupo "runner"
```

Pra outro usuário (não precisa ser admin) também poder escrever nesse cache
sem `sudo` toda vez, basta colocar ele no grupo `runner`: isso não dá
nenhum privilégio além do acesso a `/opt/riscv-foundation`:

```bash
sudo usermod -aG runner <usuario>
```

É a direção oposta (`runner` no grupo de outro usuário) que teria que ser
evitada: isso sim daria ao `runner` acesso a tudo que aquele usuário tem,
não só ao cache.

**Nota**: mudança de grupo só vale numa sessão de shell nova. Pra usar na sessão
atual sem deslogar: `sg runner -c "<comando>"`.

O workflow então usa esse cache com verificação de versão (só baixa de novo se a
tag/versão mudou desde a última vez; ver `real.yml` do projeto que consome esse
runner, exemplo [insper-riscv/Testes](https://github.com/insper-riscv/Testes),
pro padrão exato usado com o GCC).

## Fase 6: Secret pra confirmar acionamento manual

Além do controle de acesso do repo (Fase 2), um segundo portão pra disparo manual
via `workflow_dispatch`: útil se algum dia mais gente tiver acesso de escrita ao
repo sem dever poder acionar hardware físico.

- Repo → **Settings → Secrets and variables → Actions → New repository secret**
- Nome: `FPGA_RUN_SECRET`, valor: qualquer frase (ex: `openssl rand -hex 32`)
- No workflow, um `workflow_dispatch.inputs.confirm` comparado contra esse secret
  antes de qualquer passo que toque a placa (ver `real.yml` do projeto).

## Fase 7: Permissão pro runner resetar o JTAG

O workflow de hardware real do projeto (exemplo: `real.yml` em
[insper-riscv/Testes](https://github.com/insper-riscv/Testes)) tipicamente
checa `jtagconfig` antes de compilar e, se a chain estiver presa, tenta um
`killall jtagd` com recheck automático antes de falhar com uma mensagem clara
pedindo intervenção manual. Isso precisa de sudo sem senha só pra esse
comando exato:

```bash
echo 'runner ALL=(root) NOPASSWD: /usr/bin/killall jtagd' | \
  sudo tee /etc/sudoers.d/runner-jtagd
```

Pegadinhas de hardware JTAG (porta USB mudando de número, autosuspend
derrubando a conexão, "chain broken" que só resolve com power-cycle) são
comportamento do hardware em si, não conteúdo de setup do runner: exemplo
documentado em
[HARDWARE_PROGRAMMING.md do insper-riscv/Testes](https://github.com/insper-riscv/Testes/blob/main/HARDWARE_PROGRAMMING.md).

## Checklist final

- [ ] `sudo systemctl status gh-actions-runner` → `active (running)`
- [ ] Runner aparece **Idle** em Settings → Actions → Runners, com as labels certas
- [ ] Runner group restrito a **Selected repositories** (não "All repositories")
- [ ] `jtagconfig` lê o device ID da placa sem erro
- [ ] `cat /sys/bus/usb/devices/usb1/power/control` → `on` (ajuste o nome do hub)
- [ ] Secret de confirmação manual configurado, se aplicável
