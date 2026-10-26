# Compilando o Yosys e o SymbiYosys

Yosys e SymbiYosys (`sby`), compilados do código-fonte a partir da release `v0.N` mais recente de cada repositório, que são lançados em passo, e instalados em `/opt/yosys`. Eles provam propriedades do netlist Verilog que o GHDL sintetiza do VHDL. O build gera:

| Componente | Papel |
| :--- | :--- |
| `yosys` | O framework de síntese e verificação formal |
| `yosys-abc` | O otimizador de lógica que o Yosys chama |
| `yosys-smtbmc` | Roda a verificação limitada e a indução que o `sby` pede ao solver SMT |
| `yosys-witness` | Converte e inspeciona os traços de testemunha de uma prova |
| `yosys-config` | Imprime as flags para compilar plug-ins do Yosys |
| `yosys-filterlib` | Filtra bibliotecas de células Liberty |
| `sby` | SymbiYosys: roda o Yosys e os solvers (`z3`, `boolector`) para provar propriedades de um bloco |

## 1. Dependências

### 1.1. Debian-like (`apt`)

Os comandos foram executados no Ubuntu 26.04.

```bash
sudo apt-get install -y build-essential cmake git ca-certificates python3 pkg-config gawk \
  bison flex libreadline-dev libffi-dev libfl-dev tcl-dev zlib1g-dev python3-click z3 boolector
```

### 1.2. RHEL-like (`dnf`/`yum`)

Em RHEL 8 ou mais novo, `yum` é um alias de `dnf`; os dois comandos são equivalentes. Os comandos foram executados no Rocky Linux 9.

Alguns pacotes estão nos repositórios `crb` e EPEL; habilite-os antes:

```bash
sudo dnf install -y dnf-plugins-core epel-release
sudo dnf config-manager --set-enabled crb
```

No próprio RHEL, o `epel-release` não está nos repositórios base: habilite o EPEL como descrito na [documentação dele](https://docs.fedoraproject.org/en-US/epel/).

O `boolector` não tem pacote nesses repositórios. A prova deste guia usa o `z3`, e o motor `boolector` do `sby` só roda se o `boolector` for instalado por outros meios.

```bash
sudo dnf install -y gcc gcc-c++ make cmake git ca-certificates python3 pkgconf-pkg-config \
  gawk bison flex flex-devel readline-devel libffi-devel tcl-devel zlib-devel python3-click z3
```

## 2. Compilar e instalar

Rode o script como root (por exemplo com `sudo -i`): ele escreve em `/opt` e, onde indicado, em `/usr/local/bin` e `/etc/profile.d`.

```bash
set -euo pipefail
PREFIX=/opt/yosys
TAG=$(git ls-remote --tags --refs https://github.com/YosysHQ/yosys 'v0.*' | sed 's|.*refs/tags/||' \
      | grep -E '^v0\.[0-9]+$' | sort -V | tail -n 1)

if [ "$(cat "$PREFIX/.tag" 2>/dev/null)" = "$TAG" ]; then
  echo "Yosys is already at $TAG, nothing to do"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp yosys-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT
rm -rf "$PREFIX"

# Yosys, without the Slang front end
git clone --depth 1 --branch "$TAG" https://github.com/YosysHQ/yosys "$BUILD_DIR/yosys"
git -C "$BUILD_DIR/yosys" submodule update --init --depth 1 \
  abc libs/symfpu libs/cxxopts libs/fmt libs/tomlplusplus
cd "$BUILD_DIR/yosys"
cmake -B build . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DYOSYS_USE_BUNDLED_LIBS=ON -DYOSYS_WITHOUT_SLANG=ON -DYOSYS_ENABLE_UNIT_TESTS=OFF
cmake --build build --parallel "$(nproc)"
cmake --install build --strip

# SymbiYosys, the release with the same version
git clone --depth 1 --branch "$TAG" https://github.com/YosysHQ/sby "$BUILD_DIR/sby"
make -C "$BUILD_DIR/sby" install PREFIX="$PREFIX" YOSYS_RELEASE_VERSION="SBY $TAG"

echo "$TAG" > "$PREFIX/.tag"
```

- `-DYOSYS_WITHOUT_SLANG=ON` deixa de fora o front end de SystemVerilog baseado no Slang, a maior parte do build; as propriedades são lidas com o `read_verilog -formal -sv` embutido.
- `-DYOSYS_USE_BUNDLED_LIBS=ON` usa as bibliotecas que o Yosys traz como submódulos (`cxxopts`, `fmt`, `tomlplusplus`), e `abc` e `symfpu` são os outros submódulos de que um build sem o Slang precisa.
- O `sby` é Python e se instala ao lado do Yosys; `python3-click` é a biblioteca que ele importa, e `YOSYS_RELEASE_VERSION` dá a ele a string de versão que um clone sem histórico não consegue calcular.
- O build roda em `/var/tmp`, e não em `/tmp`, que costuma ser um tmpfs pequeno demais para a árvore de build, e o diretório é apagado ao final.
- O `.tag` é gravado por último: um build interrompido deixa a instalação sem `.tag`, então a próxima execução recompila em vez de confiar numa instalação incompleta, e uma execução na versão já instalada não faz nada.

Para atualizar, rode de novo o script da seção 2.

## 3. Verificar

```bash
d=$(mktemp -d); cd "$d"; export PATH=/opt/yosys/bin:$PATH
cat > f.sv <<'EOF'
module t (input clk);
  reg [1:0] c = 0;
  always @(posedge clk) c <= c + 1;
  always @* assert(c <= 3);
endmodule
EOF
cat > f.sby <<'EOF'
[options]
mode prove
depth 5
[engines]
smtbmc z3
[script]
read_verilog -formal -sv f.sv
prep -top t
[files]
f.sv
EOF
yosys -V
sby -f f.sby | tail -n 1
cd /; rm -rf "$d"
```

## 4. PATH global

Acrescenta os binários ao `PATH` global, criando um wrapper para cada um em `/usr/local/bin`:

```bash
for f in /opt/yosys/bin/*; do
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
