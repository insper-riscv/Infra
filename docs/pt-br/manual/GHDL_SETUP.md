# Compilando o GHDL

GHDL com o backend LLVM, compilado do código-fonte a partir da release `6.x.y` mais recente do `ghdl/ghdl` e instalado em `/opt/ghdl`. O backend LLVM roda em x86-64 e em ARM, o que o `mcode` não faz, então uma simulação se comporta igual nos dois. O build gera:

| Componente | Papel |
| :--- | :--- |
| `ghdl` | Analisador, elaborador e simulador de VHDL |
| `ghdl1-llvm` | O gerador de código LLVM que o `ghdl` chama |
| `ghwdump` | Despeja um arquivo de formas de onda GHW como texto |
| `lib` | As bibliotecas VHDL compiladas, como `ieee` e `std` |

## 1. Dependências

### 1.1. Debian-like (`apt`)

Os comandos foram executados no Ubuntu 26.04.

```bash
sudo apt-get install -y ca-certificates git make gcc g++ clang gnat llvm-dev \
  zlib1g-dev libedit-dev
```

### 1.2. RHEL-like (`dnf`/`yum`)

Em RHEL 8 ou mais novo, `yum` é um alias de `dnf`; os dois comandos são equivalentes. Os comandos foram executados no Rocky Linux 9.

O GHDL é escrito em Ada, então precisa do GNAT. No Rocky Linux 9 o pacote `gcc-gnat` do EPEL não instala (`dnf install gcc-gnat` instala só o `gcc`), e no Rocky Linux 10 ele não está nos repositórios, então este build não foi executado neles. A lista abaixo foi executada no Fedora, que não precisa do `crb` nem do EPEL; o `diffutils` fornece o `cmp` que o `configure` pede. A imagem Docker [`base-ghdl`](../docker/base-ghdl.md) já traz o GHDL compilado.

```bash
sudo dnf install -y ca-certificates git make gcc gcc-c++ clang gcc-gnat llvm-devel \
  zlib-devel libedit-devel diffutils
```

## 2. Compilar e instalar

Rode o script como root (por exemplo com `sudo -i`): ele escreve em `/opt` e, onde indicado, em `/usr/local/bin` e `/etc/profile.d`.

```bash
set -euo pipefail
PREFIX=/opt/ghdl
TAG=$(git ls-remote --tags --refs https://github.com/ghdl/ghdl 'v6.*' | sed 's|.*refs/tags/||' \
      | grep -E '^v6\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)

if [ "$(cat "$PREFIX/.tag" 2>/dev/null)" = "$TAG" ]; then
  echo "GHDL is already at $TAG, nothing to do"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp ghdl-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT

git clone --depth 1 --branch "$TAG" https://github.com/ghdl/ghdl "$BUILD_DIR/src"
mkdir "$BUILD_DIR/build" && cd "$BUILD_DIR/build"
"$BUILD_DIR/src/configure" --with-llvm-config --prefix="$PREFIX"
make -j"$(nproc)"
rm -rf "$PREFIX"
make install
echo "$TAG" > "$PREFIX/.tag"
```

- `--with-llvm-config` seleciona o backend LLVM, que elabora um design num executável: use `ghdl -a`, `ghdl -e` e `ghdl -r` (ou `ghdl --elab-run`), nunca um `ghdl -r` solto depois de só `-a`.
- O build roda em `/var/tmp`, e não em `/tmp`, que costuma ser um tmpfs pequeno demais para a árvore de build, e o diretório é apagado ao final.
- O `.tag` é gravado por último: um build interrompido deixa a instalação sem `.tag`, então a próxima execução recompila em vez de confiar numa instalação incompleta, e uma execução na versão já instalada não faz nada.

Para atualizar, rode de novo o script da seção 2.

## 3. Verificar

```bash
d=$(mktemp -d); cd "$d"
cat > t.vhd <<'EOF'
library ieee; use ieee.std_logic_1164.all;
entity t is end;
architecture a of t is signal s : std_logic_vector(3 downto 0) := (others => '1'); begin
  process begin assert s = "1111" report "bad" severity failure; report "ghdl ok"; wait; end process;
end;
EOF
/opt/ghdl/bin/ghdl --version | head -n 1
/opt/ghdl/bin/ghdl -a --std=08 t.vhd
/opt/ghdl/bin/ghdl --elab-run --std=08 t
cd /; rm -rf "$d"
```

## 4. PATH global

Acrescenta os binários ao `PATH` global, criando um wrapper para cada um em `/usr/local/bin`:

```bash
for f in /opt/ghdl/bin/*; do
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
