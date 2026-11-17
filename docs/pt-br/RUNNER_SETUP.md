# Configurando runners self-hosted

Uma workstation Linux registrada como vários runners self-hosted do GitHub Actions, separados por classe de trabalho. Um runner executa um job por vez, então o número de runners de uma classe numa máquina é o número de jobs dela que rodam juntos, e cada classe é um label. Os jobs rodam nas imagens de CI do projeto. Os que tocam numa placa FPGA recebem o Quartus do host montado somente para leitura e alcançam a placa pelo servidor JTAG (`jtagd`) do host.

| Classe | Label | O que roda | Perfil de carga |
| :--- | :--- | :--- | :--- |
| Computação | `formal`, `build` e `cert` no mesmo runner | Provas `make formal` (SymbiYosys), o build `amd64` das imagens da Infra e a certificação ACT4 simulada | CPU alta, até cerca de 15 GiB de memória por plataforma base na certificação, longo |
| Teste simulado | `sim` | cocotb, VSG, `check-tree`, estilo e testes de unidade | Leve a médio, curto |
| Placa | O nome da placa, como `DE2-115` | Teste ou certificação na placa real, incluindo a compilação do Quartus | Um job por placa, em fila |

Todo runner leva também o label `self-hosted` e o label da máquina, que é o resultado de `hostname`. O build `arm64` das imagens roda no runner hospedado do GitHub (`ubuntu-26.04-arm`), porque as workstations são x86_64.

| Componente | Onde | Papel |
| :--- | :--- | :--- |
| Programa do runner | `/opt/runners/<nome>`, usuário `runner` | recebe os jobs do GitHub, uma pasta por runner |
| Docker | host | roda o contêiner de cada job |
| Imagem de CI | contêiner | as ferramentas dos testes, das [imagens Docker](docker/README.md) |
| Quartus | `/opt/altera_lite` no host, somente leitura no contêiner | compila e programa a placa, só nas máquinas com placa |
| `jtagd` | host, porta 1309 | o servidor JTAG que é dono dos USB-Blasters, só nas máquinas com placa |

`/opt` é o lugar padrão (FHS, Filesystem Hierarchy Standard) para software instalado à mão, fora do gerenciador de pacotes da distro; os nomes abaixo dele são uma convenção, ajuste-os à máquina.

## 1. Requisitos

| Requisito | Como |
| :--- | :--- |
| Docker Engine | o [guia de instalação](https://docs.docker.com/engine/install/) da distro |
| Acesso ao GitHub e ao `ghcr.io` | HTTPS de saída |
| Um usuário com `sudo` | para rodar os passos abaixo |
| Quartus Prime Lite em `/opt/altera_lite` | [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md), só nas máquinas com placa |

## 2. Permissão para o USB-Blaster

Só nas máquinas com placa. A regra de `udev` de que o Quartus precisa para um processo abrir o USB-Blaster sem ser root tem uma linha por `idProduct` (`6001`, `6002`, `6003`, `6010`, `6810`, `6020`, `6022`, `6024`, `6025`, `6026`, `602C`, `602D` e `602E`). Um só bloco cria `/etc/udev/rules.d/92-usbblaster.rules`, recarrega as regras e lista os cabos:

```bash
for p in 6001 6002 6003 6010 6810 6020 6022 6024 6025 6026 602C 602D 602E; do
  printf 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="%s", GROUP="plugdev", MODE="0660"\n' "$p"
done | sudo tee /etc/udev/rules.d/92-usbblaster.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --action=add
lsusb -d 09fb:     # lista os USB-Blasters
```

`09fb` é o id de fabricante da Altera, e `GROUP="plugdev", MODE="0660"` deixa os membros do grupo `plugdev` abrirem o dispositivo, e mais ninguém. Um usuário que rode o `jtagconfig` à mão na máquina também precisa estar no `plugdev`.

## 3. Usuário de serviço dedicado

Todos os runners da máquina rodam como o mesmo usuário de sistema **sem senha, sem sudo próprio e fora do grupo do usuário admin**, o que o isola do resto da máquina. O grupo `docker` permite que ele inicie os contêineres dos jobs, e o `plugdev` permite que o `jtagd` dele abra o USB-Blaster.

```bash
sudo useradd -r -m -d /opt/runners -s /usr/sbin/nologin runner
sudo passwd -l runner              # sem login por senha; só via sudo/systemd
sudo usermod -aG docker runner     # inicia os contêineres dos jobs
sudo usermod -aG plugdev runner    # abre o USB-Blaster (seção 2), só nas máquinas com placa
```

Ser membro do grupo `docker` equivale a ser root na máquina, o que contraria o isolamento acima. Onde isso não for aceitável, dê ao `runner` um Docker rootless próprio em vez do grupo.

- `-r` cria o usuário com UID/GID na faixa de sistema, escolhidos entre os que estiverem livres na máquina.
- `-m -d /opt/runners` cria o home já no lugar certo, com dono `runner:runner`.
- `-s /usr/sbin/nologin` deixa a conta sem shell interativo.

Por causa do `nologin`, `sudo -iu runner ...` e `sudo su - runner` falham; todo comando deste guia usa `sudo -u runner bash -lc '...'`, sem `-i`.

Confira que o home registrado para a conta é `/opt/runners`, que é o que o `-d` define na criação:

```bash
getent passwd runner   # o 6º campo é o home
sudo usermod -d /opt/runners runner   # só se aparecer outro valor, com o jtagd parado
```

O `useradd -m` cria o home com o modo `0750` do `HOME_MODE` de `/etc/login.defs`, o que impede os outros usuários da máquina de listar e ler os runners. O comando abaixo abre a raiz e os arquivos para leitura e passagem de pasta, e deixa só a chave privada do runner restrita:

```bash
sudo chmod 755 /opt/runners
sudo find /opt/runners -xdev ! -type l ! -name '.credentials_rsaparams' -exec chmod o+rX {} +
```

O `.credentials_rsaparams` guarda a chave com que o runner se autentica no GitHub, e quem a lê consegue se passar pelo runner. O `config.sh` já o cria com modo `600`, e ele fica assim.

## 4. Servidor JTAG no host

Só nas máquinas com placa. O contêiner alcança as placas por um `jtagd` que roda no host e escuta em `localhost:1309`. Um `jtagd` por máquina enxerga todos os cabos dela.

### 4.1. Serviço do `jtagd`

Um serviço do systemd o mantém de pé e o inicia de novo se ele morrer:

```bash
sudo tee /etc/systemd/system/jtagd.service <<'UNIT'
[Unit]
Description=Quartus JTAG server (jtagd)
After=network.target

[Service]
Type=simple
User=runner
ExecStart=/opt/altera_lite/25.1std/quartus/bin/jtagd --foreground --no-config
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now jtagd
```

| Opção | Efeito |
| :--- | :--- |
| `--foreground` | mantém o `jtagd` como o processo que o systemd supervisiona, em vez de ir para segundo plano |
| `--no-config` | inicia com a configuração padrão e não grava arquivo de configuração; os USB-Blasters são detectados automaticamente |

Confira que ele escuta e responde:

```bash
sudo systemctl status jtagd --no-pager   # active (running)
ss -ltn | grep ':1309 '                  # escutando na porta 1309
sudo -u runner /opt/altera_lite/25.1std/quartus/bin/jtagconfig   # imprime cada cabo e o chip
```

Sem placa conectada, o `jtagconfig` imprime `No JTAG hardware available`. O comportamento do próprio hardware, como o número da porta USB mudar ou uma cadeia JTAG que só um power cycle resolve, está no [HARDWARE_PROGRAMMING.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/HARDWARE_PROGRAMMING.md) do TopLevel.

### 4.2. O cabo de cada placa

O nome do cabo (`USB-Blaster [1-6]`) muda quando se troca a porta USB, então o job acha o cabo pelo IDCODE da placa, que o `jtagconfig` imprime logo abaixo do cabo.

| Placa | Label | IDCODE |
| :--- | :--- | :--- |
| DE0-CV | `DE0-CV` | `02B050DD` |
| DE2-115 | `DE2-115` | `020F70DD` |
| DE0-Nano (chip EP4CE22) | `DE0-Nano` | `020F30DD` |
| DE10-Lite (chip 10M50DA) | `DE10-Lite` | `031050DD` |

```bash
cable() {  # cable <IDCODE>
  jtagconfig | awk -v id="$1" '/^[0-9]+\)/ {sub(/^[0-9]+\) /,""); c=$0} $1==id {print c; exit}'
}
cable 020F70DD     # imprime o cabo da DE2-115
```

Um IDCODE sem cabo imprime nada, e o job deve falhar nesse caso em vez de programar outra placa. Uma placa nova segue o mesmo padrão, com o nome dela como label e o IDCODE que o `jtagconfig` imprime para ela.

### 4.3. Trava por placa

Cada placa tem um arquivo de trava próprio, e todo uso da placa o toma durante a sessão inteira: o job de CI, um agente e quem roda à mão. O arquivo é o que o `riscv-tools board lock` toma, de nome `<placa sem hífen>-<host>.lock` em `/tmp` (por exemplo `de2115-<host>.lock`), em que `<host>` é o rótulo da máquina no `boards.yaml` do `riscv-tools`, por padrão o hostname curto. O `lock_dir` desse arquivo muda a pasta, e todo usuário da máquina precisa usar o mesmo valor.

Dois jobs em placas diferentes da mesma máquina rodam juntos, e na mesma placa rodam em fila, qualquer que seja o número de runners dela. Quem não usa o `riscv-tools` toma a mesma trava com um `flock` comum no mesmo arquivo:

```bash
flock -w 3600 /tmp/de2115-<host>.lock <comando>
```

Os arquivos de trava são criados uma vez, como root, com modo `666`. Com o `fs.protected_regular=2` que o Ubuntu traz, um usuário não consegue abrir em `/tmp` um arquivo que outro usuário criou, e o `runner` e quem trabalha por ssh deixariam de dividir a mesma trava. Um arquivo do `systemd-tmpfiles` cria os arquivos de novo a cada boot e os exclui da limpeza periódica de `/tmp`, com uma linha `f` e uma linha `x` por placa. O primeiro comando cria o arquivo, e cada placa seguinte entra com `tee -a`, porque o `tee` sem `-a` sobrescreve as placas já listadas:

```bash
h=$(hostname -s)
printf 'f /tmp/de2115-%s.lock 0666 root root -\nx /tmp/de2115-%s.lock\n' $h $h | sudo tee /etc/tmpfiles.d/board-locks.conf
printf 'f /tmp/de0cv-%s.lock 0666 root root -\nx /tmp/de0cv-%s.lock\n' $h $h | sudo tee -a /etc/tmpfiles.d/board-locks.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/board-locks.conf
ls -l /tmp/*.lock
```

O `ls` tem de listar um arquivo `-rw-rw-rw-` por placa da máquina, e o número de linhas `f` do arquivo de configuração é igual ao de arquivos listados.

A placa que o job programa precisa ter o IDCODE esperado pelo `.sof`. Programar o `.sof` de uma placa em outra é o erro a evitar.

## 5. Registrar um runner

O token e a URL do pacote estão na org, em **Settings → Actions → Runners → New runner**. O token expira em cerca de uma hora, então copie-o logo, e um mesmo token registra vários runners dentro desse prazo. O nome e a pasta de um runner seguem `<host>-<classe>-<n>`, em que `<host>` é o resultado de `hostname` e `<classe>` é `compute`, `sim` ou o nome da placa. Um exemplo é `D-20003265-LINUX-sim-2`.

```bash
name=$(hostname)-compute-1
sudo -u runner mkdir -p /opt/runners/$name
sudo -u runner HOME=/opt/runners bash -lc "
  cd /opt/runners/$name
  curl -o actions-runner.tar.gz -L <URL_DE_DOWNLOAD_DA_PAGINA>
  tar xzf actions-runner.tar.gz
  ./config.sh --url https://github.com/<org> --token <TOKEN_DA_PAGINA> \
      --runnergroup Workstation --labels self-hosted,$(hostname),formal,build,cert,quartus \
      --name $name --unattended
"
```

O `HOME=/opt/runners` é passado explicitamente para que o registro não dependa do home gravado na conta. Os labels de cada classe são estes:

| Runner | Labels | Quantos por máquina |
| :--- | :--- | :--- |
| `compute` | `self-hosted,<host>,formal,build,cert,quartus` | 1 |
| `sim` | `self-hosted,<host>,sim,quartus` | 2 |
| Placa | `self-hosted,<host>,<placa>,quartus` | 1 por placa |

O label `quartus` vai em todo runner de uma máquina que tem o Quartus instalado, e fica de fora nas máquinas sem ele. Um runner já registrado ganha ou perde um label pela API:

```bash
gh api -X POST   orgs/<org>/actions/runners/<id>/labels -f 'labels[]=<label>'
gh api -X DELETE orgs/<org>/actions/runners/<id>/labels/<label>
```

O `<id>` aparece em `gh api orgs/<org>/actions/runners`.

### 5.1. Grupo do runner

Um runner registrado na org fica disponível para **qualquer repo** que o *runner group* dele permita, e por padrão esse grupo é "All repositories", o que expõe a máquina aos repos públicos da org.

- **Obrigatório**: Org Settings → Actions → Runner groups → o grupo `Workstation` → **Repository access → Selected repositories** → só os repos que usam os runners.
- **O grupo se chama `Workstation`**, e não "Default". No registro, o `config.sh` sem `--runnergroup` pergunta qual grupo usar.
- Um runner já registrado no grupo errado é movido em Org Settings → Actions → Runner groups → `Workstation` → **Runners → Add runner**.

Um runner no grupo errado não dá erro: o job que precisa dele fica em "Queued" sem nenhuma mensagem.

## 6. Serviço systemd do runner

O script `svc.sh` do pacote do runner supõe que o usuário de serviço tem sudo, o que o `runner` não tem, então a unit é escrita direto. Uma unit modelo serve a todos os runners, e o nome da instância é o nome da pasta:

```bash
sudo tee /etc/systemd/system/gh-runner@.service <<'UNIT'
[Unit]
Description=GitHub Actions self-hosted runner %i
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=runner
WorkingDirectory=/opt/runners/%i
ExecStart=/opt/runners/%i/run.sh
Restart=always
RestartSec=5
CPUWeight=50

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now gh-runner@$name
sudo systemctl status gh-runner@$name --no-pager   # active (running)
```

O `CPUWeight=50`, menor que o padrão (100), deixa as sessões interativas à frente dos jobs quando a CPU está disputada.

Um runner de placa sobe depois do `jtagd`, o que um drop-in da instância declara:

```bash
sudo mkdir -p /etc/systemd/system/gh-runner@$name.service.d
printf '[Unit]\nAfter=jtagd.service\nWants=jtagd.service\n' | sudo tee /etc/systemd/system/gh-runner@$name.service.d/jtagd.conf
sudo systemctl daemon-reload
```

### 6.1. Sem teto de recurso

Nenhum runner tem `CPUQuota` nem `MemoryMax`, e cada job usa o que a máquina tiver livre. A CPU é dividida pelo escalonador do Linux. A memória não se divide, e quando ela acaba o kernel mata um processo. Para ele matar os do job, e não uma sessão ssh nem o `jtagd`, cada runner leva um drop-in de prioridade de OOM:

```bash
for u in $(systemctl list-units 'gh-runner@*' --no-legend --plain | awk '{print $1}'); do
  d=/etc/systemd/system/$u.d
  sudo mkdir -p "$d"
  printf '[Service]\nOOMScoreAdjust=500\n' | sudo tee "$d/oom.conf" >/dev/null
done
sudo systemctl daemon-reload
```

Os processos que o runner inicia herdam o `OOMScoreAdjust`, mas um contêiner Docker não, porque o `dockerd` o cria fora do serviço do runner. Para o contêiner, use `--oom-score-adj` nas opções dele. Confira o valor com `systemctl show -p OOMScoreAdjust gh-runner@<nome>`.

## 7. Reiniciando o servidor JTAG

Um `jtagd` em mau estado, por exemplo por uma sessão que não terminou, pode fazer o `jtagconfig` relatar uma cadeia quebrada, e reiniciá-lo resolve esse caso. Uma cadeia quebrada pela própria placa precisa de um power cycle dela, que nenhum restart resolve.

Como o `jtagd` roda como o usuário `runner` (seção 4.1), o runner o encerra com `killall jtagd`, sem `sudo` e sem regra no sudoers, e o systemd o inicia de novo depois dos 5 segundos do `RestartSec`. Um job pode checar a cadeia antes de usar a placa, reiniciar o `jtagd` uma vez e checar de novo antes de falhar:

```bash
killall jtagd
sleep 6          # os 5 segundos do RestartSec mais a subida
jtagconfig
```

Só os passos que rodam no host conseguem fazer isso: um passo dentro do contêiner não compartilha os processos do host. O `jtagd` é um só por máquina, então reiniciá-lo derruba também a sessão de um job em outra placa da mesma máquina.

## 8. O que o contêiner de um job de placa precisa

Um job que toca na placa roda numa imagem de CI e precisa dar ao contêiner o que está abaixo. O comando completo, com o erro que aparece quando o `jtagd` não está rodando no host, está na seção 7 do [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md).

| Necessidade | Como |
| :--- | :--- |
| Quartus | montar `/opt/altera_lite` somente para leitura no mesmo caminho e pôr `/opt/altera_lite/25.1std/quartus/bin` no `PATH` |
| O `jtagd` do host | compartilhar a rede do host (`--network host`), para que `localhost:1309` seja o servidor da seção 4.1 |
| Arquivos com o dono do usuário que invoca | `--user "$(id -u):$(id -g)"` e um `HOME` gravável, por exemplo `-e HOME=/tmp/h` |
| Um daemon do Docker que remapeia usuários | acrescentar `--userns=host`, que o daemon exige junto com `--network host` |

A imagem não precisa de Quartus próprio: ela traz a biblioteca de sistema de que as ferramentas de linha de comando do Quartus dependem.

## 9. Uma carga de computação por vez

O runner `compute` carrega os três labels `formal`, `build` e `cert`. Como um runner executa um job por vez, dois jobs dessas três classes nunca rodam juntos na mesma máquina, sem trava nem gancho, e um job de qualquer um dos três vai ao primeiro runner `compute` livre entre as máquinas. Isso importa porque a certificação de uma plataforma base ocupa cerca de 15 GiB de memória, e dois desses jobs juntos passam dos 31 GiB de uma máquina com essa memória.

Uma máquina roda dois jobs de computação ao mesmo tempo com um segundo runner `compute`, de nome `<host>-compute-2`, registrado como na seção 5.

## 10. Workflows

O `runs-on` escolhe a classe pelo label.

```yaml
formal:
  runs-on: [self-hosted, formal]

certification:
  runs-on: [self-hosted, cert]

unit-tests:
  runs-on: [self-hosted, sim]

board:
  runs-on: [self-hosted, DE2-115]

specific-machine:
  runs-on: [self-hosted, DE2-115, D-20003264-LINUX]
```

O build `arm64` usa `runs-on: ubuntu-26.04-arm`, e o `amd64` usa `[self-hosted, build]`. Com duas placas do mesmo tipo em máquinas diferentes, como a `DE2-115`, o label da máquina fixa o job numa delas. Um workflow que muda `runs-on` altera `.github/`.

## 11. Segurança

- O *runner group* `Workstation` fica restrito a **Selected repositories**, nunca "All repositories" (seção 5.1).
- Os repositórios da org são públicos. Em **Settings → Actions → General** de cada repositório, **Fork pull request workflows** exige **Require approval for all external contributors** antes de qualquer runner self-hosted rodar um PR de fora.
- Em **Org Settings → Actions → General → Runners**, **Repository self-hosted runners** fica em **Selected repositories** sem nenhum repositório marcado, para nenhum repositório registrar um runner próprio fora do grupo.
- O `_work` de um runner persistente não é limpo entre jobs. O workflow que usa o runner deve limpar o que cria.
- O grupo `docker` do usuário `runner` equivale a root na máquina (seção 3), e por isso só repositórios de confiança entram no grupo.

### 11.1. Secret para confirmar execuções manuais (opcional)

Configurado por repositório no GitHub, é um segundo portão para execuções iniciadas à mão com `workflow_dispatch`, útil se mais gente ganhar acesso de escrita ao repo sem dever disparar o hardware físico.

- Repo → **Settings → Secrets and variables → Actions → New repository secret**.
- Nome `FPGA_RUN_SECRET`, com qualquer frase como valor (por exemplo `openssl rand -hex 32`).
- O workflow compara uma entrada `confirm` com esse secret antes de qualquer passo que toque na placa.

## 12. Atualizar, remover e mover

Para remover um runner, pare o serviço, desregistre-o com o token de remoção da página do runner e apague a pasta:

```bash
sudo systemctl stop gh-runner@<nome>
sudo -u runner HOME=/opt/runners bash -lc "cd /opt/runners/<nome> && ./config.sh remove --token <TOKEN_DE_REMOCAO>"
sudo systemctl disable gh-runner@<nome>
sudo rm -rf /opt/runners/<nome>
```

O programa do runner se atualiza sozinho. Para fixar uma versão ou trocar o pacote, pare o serviço, extraia o novo `tar.gz` por cima da pasta e inicie o serviço de novo.

### 12.1. Mover uma placa

Mover uma placa de máquina é remover o runner dela na máquina antiga e registrar um novo na máquina nova. Um job em andamento falha quando o runner para, e a falha só aparece no GitHub depois de alguns minutos. Reexecute o job com **Re-run job**, e os jobs ainda na fila esperam o runner novo ficar **Idle**.

Na máquina antiga, remova o runner `<host-antigo>-<placa>-1` como na seção 12. Se a máquina ficou sem nenhuma placa, pare também o servidor JTAG com `sudo systemctl disable --now jtagd`.

Na máquina nova:

1. Se ela ainda não tinha placa, faça as seções 2, 3 e 4 e confirme que o Quartus Lite está instalado.
2. Plugue a placa e confira que `jtagconfig` lista o IDCODE dela e que `cable <IDCODE>` imprime o cabo.
3. Registre o runner pela seção 5, com o nome `<host-novo>-<placa>-1` e os labels `self-hosted,<host-novo>,<placa>,quartus` no grupo `Workstation`.
4. Ligue o serviço pela seção 6, com o drop-in do `jtagd`.
5. Rode o checklist da seção 13 para essa placa.

Um `runs-on` que lista o label da máquina, como `[self-hosted, DE2-115, D-20003264-LINUX]`, deixa de achar runner depois da mudança. Os que listam só a placa, como `[self-hosted, DE0-Nano]`, continuam certos.

## 13. Checklist final

- [ ] `systemctl status gh-runner@<nome>` mostra `active (running)` para cada runner
- [ ] Cada runner aparece como **Idle** em Settings → Actions → Runners da org, com os labels da seção 5 e no grupo `Workstation`
- [ ] O grupo `Workstation` está restrito a **Selected repositories**, e não a "All repositories"
- [ ] A aprovação de PR de fork está ligada em cada repositório do grupo
- [ ] `systemctl show -p MemoryMax,CPUQuotaPerSecUSec,OOMScoreAdjust gh-runner@<nome>` mostra `infinity`, `infinity` e `500`
- [ ] Nas máquinas com placa, `ss -ltn | grep ':1309 '` mostra o `jtagd` e `cable <IDCODE>` imprime o cabo de cada placa
- [ ] Nas máquinas com placa, `sudo -u runner killall jtagd` e, 6 segundos depois, `ss -ltn | grep ':1309 '` mostra o servidor de novo
- [ ] Um usuário sem `sudo` lista `/opt/runners` e lê os arquivos dos runners, e `stat -c %A /opt/runners/*/.credentials_rsaparams` mostra `-rw-------`
- [ ] Um job de teste por label roda e imprime o nome do runner
- [ ] O Docker funciona como `runner`: `sudo -u runner docker run --rm ghcr.io/insper-riscv/ci-elf:latest riscv32-unknown-elf-gcc --version`
- [ ] O Quartus roda no contêiner, com as opções da seção 8: `quartus_pgm --version` imprime a versão
- [ ] O secret de confirmação manual está configurado, se aplicável

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../LICENSE).
