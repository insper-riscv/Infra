# Compilando o GTKWave

GTKWave, o visualizador de formas de onda, compilado do código-fonte a partir da ponta da branch `lts` (a linha de manutenção 3.3) do `gtkwave/gtkwave`, árvore GTK 3, e instalado em `/opt/gtkwave`. O GTK 3 tem backend Wayland, então roda nativamente no Wayland e no X11. O build gera:

| Componente | Papel |
| :--- | :--- |
| `gtkwave` | O visualizador |
| `twinwave` | Dois visualizadores numa janela; usa XEmbed, que só existe no X11 |
| `rtlbrowse` | Navegador do código-fonte RTL |
| `vcd2fst`, `fst2vcd`, `vcd2lxt`, `lxt2vcd`, `vcd2lxt2`, `vcd2vzt`, `vzt2vcd`, `evcd2vcd` | Conversores entre formatos de formas de onda |
| `fstminer`, `lxt2miner`, `vztminer` | Extraem sinais de um dump |
| `json2stems`, `xml2stems` | Geram arquivos de stems para o navegador RTL |
| `shmidcat` | Lê um dump da memória compartilhada |

## 1. Dependências

### 1.1. Debian-like (`apt`)

Os comandos foram executados no Ubuntu 26.04.

```bash
sudo apt-get install -y build-essential git ca-certificates pkg-config gperf flex \
  libgtk-3-dev libbz2-dev liblzma-dev libjudy-dev zlib1g-dev
```

### 1.2. RHEL-like (`dnf`/`yum`)

Em RHEL 8 ou mais novo, `yum` é um alias de `dnf`; os dois comandos são equivalentes. Os comandos foram executados no Rocky Linux 9.

Alguns pacotes estão nos repositórios `crb` e EPEL; habilite-os antes:

```bash
sudo dnf install -y dnf-plugins-core epel-release
sudo dnf config-manager --set-enabled crb
```

No próprio RHEL, o `epel-release` não está nos repositórios base: habilite o EPEL como descrito na [documentação dele](https://docs.fedoraproject.org/en-US/epel/).

```bash
sudo dnf install -y gcc gcc-c++ make git ca-certificates pkgconf-pkg-config gperf flex \
  gtk3-devel bzip2-devel xz-devel Judy-devel zlib-devel
```

## 2. Compilar e instalar

Rode o script como root (por exemplo com `sudo -i`): ele escreve em `/opt` e, onde indicado, em `/usr/local/bin` e `/etc/profile.d`.

```bash
set -euo pipefail
PREFIX=/opt/gtkwave
COMMIT=$(git ls-remote https://github.com/gtkwave/gtkwave refs/heads/lts | cut -f1)

if [ "$(cat "$PREFIX/.tag" 2>/dev/null)" = "$COMMIT" ]; then
  echo "GTKWave is already at $COMMIT, nothing to do"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp gtkwave-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT

git clone --depth 1 --branch lts https://github.com/gtkwave/gtkwave "$BUILD_DIR/src"
cd "$BUILD_DIR/src/gtkwave3-gtk3"
CFLAGS="-O2 -std=gnu17 -Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration -Wno-error=int-conversion" \
  ./configure --prefix="$PREFIX" --enable-gtk3 --disable-tcl --disable-mime-update
make -j"$(nproc)"
rm -rf "$PREFIX"
make install
echo "$COMMIT" > "$PREFIX/.tag"
```

- `--enable-gtk3` compila a árvore GTK 3, `--disable-tcl` deixa o Tcl de fora, que não é necessário para ver uma forma de onda, e `--disable-mime-update` deixa a base MIME para o sistema.
- As `CFLAGS` mantêm três diagnósticos de um GCC atual (14 em diante) como avisos, porque o código dessa árvore usa assinaturas de callback que essas versões rejeitam por padrão.
- Uma janela precisa de uma tela: no Wayland, `libegl1`, `libegl-mesa0`, `libgl1`, `libgl1-mesa-dri`, `adwaita-icon-theme` e `shared-mime-info` são os pacotes de execução; uma instalação de desktop já os tem.
- O build roda em `/var/tmp`, e não em `/tmp`, que costuma ser um tmpfs pequeno demais para a árvore de build, e o diretório é apagado ao final.
- O `.tag` é gravado por último: um build interrompido deixa a instalação sem `.tag`, então a próxima execução recompila em vez de confiar numa instalação incompleta, e uma execução na versão já instalada não faz nada.

Para atualizar, rode de novo o script da seção 2.

## 3. Verificar

```bash
ls /opt/gtkwave/bin
ldd /opt/gtkwave/bin/gtkwave | grep "not found" || echo "no missing library"
```

## 4. PATH global

Acrescenta os binários ao `PATH` global, criando um wrapper para cada um em `/usr/local/bin`:

```bash
for f in /opt/gtkwave/bin/*; do
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

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
