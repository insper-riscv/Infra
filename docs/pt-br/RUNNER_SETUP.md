# Configurando um runner self-hosted

Uma workstation com uma placa FPGA e um USB-Blaster, registrada como runner self-hosted do GitHub Actions. Os jobs que tocam na placa rodam num contêiner Docker, uma imagem de CI do projeto, que recebe o Quartus do host montado somente para leitura e alcança a placa pelo servidor JTAG (`jtagd`) do host. O host, portanto, tem o Quartus, o Docker, o `jtagd` e o runner, e nenhuma das ferramentas das imagens de CI (GHDL, o GCC RISC-V, o Spike e o resto).

| Componente | Onde | Papel |
| :--- | :--- | :--- |
| Programa do runner | `/opt/actions-runner`, usuário `runner` | recebe os jobs do GitHub |
| Docker | host | roda o contêiner de cada job |
| Imagem de CI | contêiner | as ferramentas dos testes, das [imagens Docker](docker/README.md) |
| Quartus | `/opt/altera_lite` no host, somente leitura no contêiner | compila e programa a placa |
| `jtagd` | host, porta 1309 | o servidor JTAG que é dono do USB-Blaster |

`/opt` é o lugar padrão (FHS, Filesystem Hierarchy Standard) para software instalado à mão, fora do gerenciador de pacotes da distro; os nomes abaixo dele são uma convenção, ajuste-os à máquina.

## 1. Requisitos

| Requisito | Como |
| :--- | :--- |
| Quartus Prime Lite em `/opt/altera_lite` | [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md) |
| Docker Engine | o [guia de instalação](https://docs.docker.com/engine/install/) da distro |
| Acesso ao GitHub e ao `ghcr.io` | HTTPS de saída |
| Um usuário com `sudo` | para rodar os passos abaixo |

## 2. Permissão para o USB-Blaster

A regra de `udev` de que o Quartus precisa para um processo abrir o USB-Blaster sem ser root. Crie `/etc/udev/rules.d/92-usbblaster.rules`:

```text
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6001", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6002", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6003", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6010", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6810", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6020", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6022", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6024", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6025", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6026", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="602C", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="602D", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="602E", GROUP="plugdev", MODE="0660"
```

Depois recarregue as regras e conecte o cabo de novo:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
lsusb -d 09fb:     # lista o USB-Blaster
```

`09fb` é o id de fabricante da Altera, e `GROUP="plugdev", MODE="0660"` deixa os membros do grupo `plugdev` abrirem o dispositivo, e mais ninguém. Um usuário que rode o `jtagconfig` à mão na máquina também precisa estar no `plugdev`.

## 3. Usuário de serviço dedicado

O runner roda como um usuário de sistema **sem senha, sem sudo próprio e fora do grupo do usuário admin**, o que o isola do resto da máquina. O grupo `docker` permite que ele inicie os contêineres dos jobs, e o `plugdev` permite que o `jtagd` dele abra o USB-Blaster.

```bash
sudo useradd -r -m -d /opt/actions-runner -s /usr/sbin/nologin runner
sudo passwd -l runner              # sem login por senha; só via sudo/systemd
sudo usermod -aG docker runner     # inicia os contêineres dos jobs
sudo usermod -aG plugdev runner    # abre o USB-Blaster (seção 2)
```

Ser membro do grupo `docker` equivale a ser root na máquina, o que contraria o isolamento acima. Onde isso não for aceitável, dê ao `runner` um Docker rootless próprio em vez do grupo.

- `-r` cria o usuário com UID/GID na faixa de sistema, escolhidos entre os que estiverem livres na máquina.
- `-m -d /opt/actions-runner` cria o home já no lugar certo, com dono `runner:runner`.
- `-s /usr/sbin/nologin` deixa a conta sem shell interativo.

Por causa do `nologin`, `sudo -iu runner ...` e `sudo su - runner` falham; todo comando deste guia usa `sudo -u runner bash -lc '...'`, sem `-i`.

Confira que o home registrado para a conta é `/opt/actions-runner`, que é o que o `-d` define na criação:

```bash
getent passwd runner   # o 6º campo é o home
sudo usermod -d /opt/actions-runner runner   # só se aparecer outro valor
```

## 4. Servidor JTAG no host

O contêiner alcança a placa por um `jtagd` que roda no host e escuta em `localhost:1309`. Um serviço do systemd o mantém de pé e o inicia de novo se ele morrer:

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
| `--no-config` | inicia com a configuração padrão e não grava arquivo de configuração; o USB-Blaster é detectado automaticamente |

Confira que ele escuta e responde:

```bash
sudo systemctl status jtagd --no-pager   # active (running)
ss -ltn | grep ':1309 '                  # escutando na porta 1309
jtagconfig                               # com a placa conectada, imprime o cabo e o chip
```

Sem placa conectada, o `jtagconfig` imprime `No JTAG hardware available`. O comportamento do próprio hardware, como o número da porta USB mudar ou uma cadeia JTAG que só um power cycle resolve, está no [HARDWARE_PROGRAMMING.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/HARDWARE_PROGRAMMING.md) do TopLevel.

## 5. Registrar o runner no GitHub

**Onde pegar o token e a URL**: no repo (ou na org, para um runner de org) → **Settings → Actions → Runners → New runner**. O token expira em cerca de uma hora, então copie-o logo.

```bash
sudo -u runner HOME=/opt/actions-runner bash -lc '
  cd /opt/actions-runner
  curl -o actions-runner.tar.gz -L <URL_DE_DOWNLOAD_DA_PAGINA>
  tar xzf actions-runner.tar.gz
  ./config.sh --url https://github.com/<org-ou-org/repo> --token <TOKEN_DA_PAGINA> \
      --labels self-hosted,quartus,fpga --name workstation-fpga --unattended
'
```

O `HOME=/opt/actions-runner` é passado explicitamente para que o registro não dependa do home gravado na conta.

### 5.1. Runner de org

Um runner registrado na org fica disponível para **qualquer repo** que o *runner group* dele permita, e por padrão esse grupo é "All repositories", o que expõe a máquina aos repos públicos da org.

- **Obrigatório**: Org Settings → Actions → Runner groups → o grupo do runner → **Repository access → Selected repositories** → só os repos que precisam do hardware.
- **O grupo precisa se chamar `FPGA`**, e não "Default".
- No registro, o `config.sh` sem `--runnergroup` pergunta qual grupo usar: escolha ou crie o `FPGA`.
- Um runner já registrado no grupo errado é movido em Org Settings → Actions → Runner groups → `FPGA` → **Runners → Add runner**.

Um runner no grupo errado não dá erro: o job que precisa dele fica em "Queued" sem nenhuma mensagem.

## 6. Serviço systemd do runner

O script `svc.sh` do pacote do runner supõe que o usuário de serviço tem sudo, o que o `runner` não tem, então a unit é escrita direto. Ela sobe depois do Docker e do `jtagd`:

```bash
sudo tee /etc/systemd/system/gh-actions-runner.service <<'UNIT'
[Unit]
Description=GitHub Actions self-hosted runner (FPGA workstation)
After=network.target docker.service jtagd.service
Wants=docker.service jtagd.service

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
sudo systemctl status gh-actions-runner --no-pager   # active (running)
```

## 7. Reiniciando o servidor JTAG

Um `jtagd` em mau estado, por exemplo por uma sessão que não terminou, pode fazer o `jtagconfig` relatar uma cadeia quebrada, e reiniciá-lo resolve esse caso. Uma cadeia quebrada pela própria placa precisa de um power cycle dela, que nenhum restart resolve.

Como o `jtagd` roda como o usuário `runner` (seção 4), o runner o encerra com `killall jtagd`, sem `sudo` e sem regra no sudoers, e o systemd o inicia de novo depois dos 5 segundos do `RestartSec`. Um job pode checar a cadeia antes de usar a placa, reiniciar o `jtagd` uma vez e checar de novo antes de falhar:

```bash
killall jtagd
sleep 6          # os 5 segundos do RestartSec mais a subida
jtagconfig
```

Só os passos que rodam no host conseguem fazer isso: um passo dentro do contêiner não compartilha os processos do host.

## 8. O que o contêiner de um job precisa

Um job que toca na placa roda numa imagem de CI e precisa dar ao contêiner o que está abaixo. O comando completo, com o erro que aparece quando o `jtagd` não está rodando no host, está na seção 7 do [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md).

| Necessidade | Como |
| :--- | :--- |
| Quartus | montar `/opt/altera_lite` somente para leitura no mesmo caminho e pôr `/opt/altera_lite/25.1std/quartus/bin` no `PATH` |
| O `jtagd` do host | compartilhar a rede do host (`--network host`), para que `localhost:1309` seja o servidor da seção 4 |
| Arquivos com o dono do usuário que invoca | `--user "$(id -u):$(id -g)"` e um `HOME` gravável, por exemplo `-e HOME=/tmp/h` |
| Um daemon do Docker que remapeia usuários | acrescentar `--userns=host`, que o daemon exige junto com `--network host` |

A imagem não precisa de Quartus próprio: ela traz a biblioteca de sistema de que as ferramentas de linha de comando do Quartus dependem.

## 9. Secret para confirmar execuções manuais (opcional)

Ao contrário das seções anteriores, esta é configurada por repositório no GitHub, e é opcional conforme o modelo de confiança do time. Além do controle de acesso do repo, é um segundo portão para execuções iniciadas à mão com `workflow_dispatch`, útil se mais gente ganhar acesso de escrita ao repo sem dever disparar o hardware físico.

- Repo → **Settings → Secrets and variables → Actions → New repository secret**.
- Nome `FPGA_RUN_SECRET`, com qualquer frase como valor (por exemplo `openssl rand -hex 32`).
- O workflow compara uma entrada `confirm` com esse secret antes de qualquer passo que toque na placa.

## 10. Checklist final

- [ ] `sudo systemctl status jtagd gh-actions-runner` mostra os dois `active (running)`
- [ ] `ss -ltn | grep ':1309 '` mostra o `jtagd` escutando
- [ ] `jtagconfig` imprime o cabo e o chip da placa
- [ ] `sudo -u runner killall jtagd` e, 6 segundos depois, `ss -ltn | grep ':1309 '` mostra o servidor de novo
- [ ] O runner aparece como **Idle** em Settings → Actions → Runners, com os labels certos
- [ ] O runner group está restrito a **Selected repositories**, e não a "All repositories"
- [ ] O Docker funciona como `runner`: `sudo -u runner docker run --rm ghcr.io/insper-riscv/ci-asm:latest riscv32-unknown-elf-gcc --version`
- [ ] O Quartus roda no contêiner, com as opções da seção 8: `quartus_pgm --version` imprime a versão
- [ ] O secret de confirmação manual está configurado, se aplicável

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../LICENSE).
