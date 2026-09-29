# Compilando o Spike

O build do Spike (`riscv-software-src/riscv-isa-sim`) gera estes binários e
bibliotecas:

| Componente | Papel |
| :--- | :--- |
| `spike` | O simulador de referência RISC-V em si: executa um binário compilado e reporta o estado da memória/registradores |
| `spike-dasm` | Desmonta trechos de código de máquina RISC-V em assembly |
| `elf2hex` | Converte um binário ELF num arquivo hex, formato usado por memórias de inicialização de FPGA (BRAM) |
| `xspike` | Front-end gráfico (X11) do Spike |
| `termios-xspike` | Variante do `xspike` para terminal serial |
| `spike-log-parser` | Interpreta o log de execução que o Spike produz |
| `libfesvr` | Biblioteca do "front-end server": carrega o ELF, implementa as syscalls que o binário simulado chama |
| `libriscv` | Biblioteca central da simulação: decodifica e executa as instruções RISC-V |
| `libdisasm` | Biblioteca de desmontagem usada pelo `spike-dasm` e pelo Spike em si |
| `libsoftfloat` | Biblioteca de ponto flutuante em software, usada pela simulação das extensões F/D/Q |

## 1. Dependências

### 1.1. Instalar o `uv` globalmente

Via o instalador oficial (`https://astral.sh/uv/install.sh`), apontado para
`/usr/local/bin` em vez do padrão `~/.local/bin`: assim fica disponível para
qualquer usuário da máquina, sem precisar de PATH extra (`/usr/local/bin` já
está no `PATH` padrão de todo mundo).

```bash
curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh
chmod +x /tmp/uv-install.sh
sudo UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 /tmp/uv-install.sh
rm /tmp/uv-install.sh
```

- Baixa o script primeiro em vez de `curl | sudo sh` direto: dá para
  inspecionar antes de rodar como root.
- O instalador baixa um binário pré-compilado (não compila nada) e confere
  o SHA256 contra um hash fixo no próprio script antes de instalar.
- `UV_NO_MODIFY_PATH=1`: não é necessário alterar o `~/.bashrc` de ninguém,
  já que `/usr/local/bin` já está no `PATH`.

Verificar:
```bash
which uv        # /usr/local/bin/uv
uv --version
```

Atualizar depois, quando necessário (precisa de `sudo` pelo mesmo motivo da
instalação: `/usr/local/bin` é do `root`):
```bash
sudo uv self update
```

### 1.2. Dependências para o build do Spike

O Spike é clonado e compilado a partir do código-fonte, não vem
pré-compilado. Isso precisa de `git` para buscar o código-fonte (não vem
instalado por padrão em toda distro/imagem mínima), e `./configure` do
Spike **falha sem `device-tree-compiler`**; os pacotes do Boost evitam um
`make` mais lento/com warnings.

#### 1.2.1. Debian-like (`apt`)

```bash
sudo apt-get install -y git device-tree-compiler libboost-regex-dev libboost-system-dev
```

Verificar o que já está instalado antes de rodar o `apt-get install`:
```bash
dpkg -s git device-tree-compiler libboost-regex-dev libboost-system-dev
```

#### 1.2.2. RHEL-like (`dnf`/`yum`)

Em RHEL 8 ou mais novo, `yum` é um alias de `dnf`; os dois comandos são
equivalentes.

```bash
sudo dnf install -y git dtc boost-devel boost-regex boost-system
```

O README oficial do Spike só documenta a troca para `yum` do pacote de
`device-tree-compiler` (`dtc`); os pacotes do Boost não são citados lá para o
`yum`/`dnf`, então `boost-devel` (headers) mais `boost-regex`/`boost-system`
(bibliotecas) são os equivalentes RHEL dos pacotes `apt` acima.

Se `boost-devel` ou `dtc` não forem encontrados, o repositório que os
contém está desabilitado: habilite o `crb` (RHEL, Rocky, Alma 9) ou o
`powertools` (8) e repita:
```bash
sudo dnf config-manager --set-enabled crb   # ou powertools
```

Verificar o que já está instalado:
```bash
rpm -q git dtc boost-devel boost-regex boost-system
```

## 2. Criar o diretório do cache e o código-fonte

`/opt/riscv-foundation` é um diretório único de cache, para que ninguém
precise manter uma cópia própria dos toolchains RISC-V grandes. `/opt` em si
é padrão do FHS (Filesystem Hierarchy Standard) para software instalado
manualmente/add-on, fora do gerenciador de pacotes da distro; o nome
`riscv-foundation` da subpasta é uma convenção sugerida, ajuste conforme o
setup da sua máquina. O Spike fica em `/opt/riscv-foundation/spike`, e o
arquivo `.tag` dentro dele guarda o hash do commit do
[riscv-software-src/riscv-isa-sim](https://github.com/riscv-software-src/riscv-isa-sim)
que gerou o conteúdo; é esse arquivo que decide se o cache está atualizado.

Quem cria e mantém esse diretório muda conforme a máquina. Numa workstation
com o runner self-hosted do GitHub Actions já configurado (ver
[RUNNER_SETUP.md](RUNNER_SETUP.md), Fase 1), o cache é compartilhado por
todos os usuários e repositórios que passam por esse runner, e o próprio
usuário `runner` precisa conseguir atualizá-lo sozinho, sem `sudo`
disponível dentro de um job. Numa máquina de teste, sem esse usuário, o
caminho continua sendo `/opt/riscv-foundation`, só que criado e mantido de
outro jeito (seção 2.2).

### 2.1. Workstation com runner

O diretório precisa existir com dono `runner:runner` e setgid, para que o
usuário `runner` e quem estiver no grupo dele consigam escrever sem `sudo`.
Numa máquina que já tem o runner configurado ele já existe; caso contrário:

```bash
sudo mkdir -p /opt/riscv-foundation
sudo chown runner:runner /opt/riscv-foundation
sudo chmod 2775 /opt/riscv-foundation
```

### 2.2. Máquina de teste, sem o usuário `runner`

Sem `runner` para ser dono do diretório e sem outro processo concorrente
escrevendo nele, o esquema de grupo/setgid da seção 2.1 não tem o que
resolver: como é um binário global, o build sempre roda via `sudo` (nunca
como usuário comum), então o dono já sai `root:root` do próprio `mkdir`, sem
precisar de `chown`. `755` (dono com escrita, todo mundo com leitura e
execução) já deixa o Spike instalado utilizável por qualquer usuário da
máquina:

```bash
sudo mkdir -p /opt/riscv-foundation
sudo chmod 755 /opt/riscv-foundation
```

### 2.3. Clonar ou atualizar o código-fonte

Este script e o da seção 3 rodam de acordo com o dono escolhido nas seções
2.1/2.2:

- **Workstation (seção 2.1)**: como o usuário `runner` (ou alguém do grupo
  dele), para que o dono do cache continue consistente:
  ```bash
  sudo -u runner bash -c '<script>'
  ```
- **Máquina de teste (seção 2.2)**: como o diretório é dono de `root`, via
  `sudo`:
  ```bash
  sudo bash -c '<script>'
  ```

O código-fonte fica em `/opt/riscv-foundation/riscv-isa-sim`, ao lado do
`spike` do cache. Se `SRC_DIR` ainda não existir, o script clona o branch
padrão do repositório; se já existir de uma execução anterior, dá um `pull`
para trazer os commits novos, sem precisar reclonar. Em ambos os casos, o
script termina movendo o módulo de debug do Spike do endereço `0x0` para
`0x70000000`; antes do `pull`, ele desfaz essa edição para não conflitar com
o upstream:

```bash
set -euo pipefail
SRC_DIR=/opt/riscv-foundation/riscv-isa-sim

if [ -d "$SRC_DIR/.git" ]; then
  git -C "$SRC_DIR" checkout -- riscv/platform.h
  git -C "$SRC_DIR" pull --ff-only
else
  git clone https://github.com/riscv-software-src/riscv-isa-sim "$SRC_DIR"
fi
sed -i 's/^#define DEBUG_START .*/#define DEBUG_START        0x70000000/' "$SRC_DIR/riscv/platform.h"
```

## 3. Compilar e instalar no cache

Rode como o mesmo dono da seção 2.3. Com `SRC_DIR` já atualizado, este passo
confere se o cache precisa ser atualizado e, se sim, compila e instala:

```bash
set -euo pipefail
CACHE_DIR=/opt/riscv-foundation/spike
SRC_DIR=/opt/riscv-foundation/riscv-isa-sim
TAG="$(git -C "$SRC_DIR" rev-parse HEAD)-debug-start"

if [ "$(cat "$CACHE_DIR/.tag" 2>/dev/null)" = "$TAG" ]; then
  echo "O cache já está em $TAG, nada a fazer"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp riscv-isa-sim-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT
cd "$BUILD_DIR"

rm -rf "$CACHE_DIR" && mkdir -p "$CACHE_DIR"
"$SRC_DIR/configure" --prefix="$CACHE_DIR"
make -j"$(nproc)"
make install
echo "$TAG" > "$CACHE_DIR/.tag"
```

- `--prefix` aponta para o próprio cache: o `make` só compila; instalar os
  binários ali dentro exige rodar `make install` depois, como um segundo
  comando.
- O build roda fora da árvore do source, em `/var/tmp`: isso permite
  reconfigurar/recompilar sem sujar o `SRC_DIR` com artefatos de build;
  `/tmp` costuma ser tmpfs, pequeno demais para árvore de build.
- `DEBUG_START` (em `riscv/platform.h`) é o endereço onde o Spike coloca o
  módulo de debug. No padrão (`0x0`), o Spike aborta na inicialização com
  `devices at [0, 1000) and [0, 10000) overlap` quando a ROM do alvo começa
  em `0x0`. O sufixo `-debug-start` no `.tag` faz um cache compilado sem essa
  edição ser recompilado.
- O `.tag` é gravado por último: um build interrompido deixa o cache sem
  `.tag`, então a próxima execução recompila em vez de confiar num cache
  incompleto.

## 4. Verificar

```bash
cat /opt/riscv-foundation/spike/.tag
/opt/riscv-foundation/spike/bin/spike --help
/opt/riscv-foundation/spike/bin/spike --isa=rv32im -m0x0:0x10000 --pc=0 \
  --disable-dtb /dev/null 2>&1 | grep overlap
```

O `.tag` deve terminar em `-debug-start`, e o `grep` não deve imprimir nada.

## 5. PATH global

Adiciona os binários do Spike ao `PATH` global, criando um wrapper
para cada um em `/usr/local/bin`:

```bash
for f in /opt/riscv-foundation/spike/bin/*; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  sudo rm -f "/usr/local/bin/$name"
  sudo tee "/usr/local/bin/$name" >/dev/null <<EOF
#!/bin/sh
exec "$f" "\$@"
EOF
  sudo chmod 755 "/usr/local/bin/$name"
done
```

Verificar:
```bash
which spike
```

Precisa rodar de novo só se uma versão nova adicionar um binário com nome
novo; os já existentes continuam apontando para o mesmo caminho.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../LICENSE).
