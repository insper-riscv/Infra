# Compilando o GCC RISC-V

Como compilar o GCC RISC-V a partir do código-fonte e instalá-lo no cache
compartilhado `/opt/riscv-foundation`, em distros Debian-like (`apt`) e
RHEL-like (`dnf`/`yum`). O build gera estes binários (todos com o prefixo
`riscv32-unknown-elf-`, omitido abaixo) e bibliotecas:

| Componente | Papel |
| :--- | :--- |
| `as` | Montador (assembler) |
| `ld`, `ld.bfd` | Linkador |
| `ar`, `ranlib` | Cria e indexa bibliotecas estáticas (`.a`) |
| `objcopy` | Copia/converte um binário entre formatos (ex: ELF para binário puro) |
| `objdump` | Desmonta um binário em assembly, lista seções e símbolos |
| `nm` | Lista os símbolos de um binário |
| `readelf` | Inspeciona a estrutura interna de um ELF |
| `addr2line` | Traduz endereço de memória em arquivo/linha de origem |
| `elfedit` | Edita campos do cabeçalho de um ELF |
| `size` | Mostra o tamanho de cada seção de um binário |
| `strings` | Lista sequências de texto legível dentro de um binário |
| `strip` | Remove símbolos/debug info de um binário |
| `gcc`, `cpp` | Compilador C e pré-processador |
| `g++`, `c++` | Compilador C++ |
| `gcc-ar`, `gcc-nm`, `gcc-ranlib` | Variantes de `ar`/`nm`/`ranlib` cientes de LTO |
| `gcov`, `gcov-dump`, `gcov-tool` | Cobertura de código |
| `lto-dump` | Inspeciona informação de LTO dentro de um objeto |
| `gdb` | Depurador: executa passo a passo, breakpoints, leitura de registrador e memória, contra um alvo remoto (simulador ou hardware via JTAG/debug module) |
| `gdb-add-index` | Gera um índice de símbolos para o `gdb` carregar mais rápido |
| `gstack` | Imprime o stack trace de um processo em execução, via `gdb` |
| `run` | Único binário nativo do host (não RISC-V) da lista: roda um binário RISC-V compilado sob um simulador, repassando a I/O de semihosting da picolibc |
| picolibc (`libc.a` + headers) | Biblioteca C para bare-metal, compilada para cada variante da seção 3.1: cobre `printf`, `scanf`, `malloc` e `free` sem depender de um sistema operacional |

## 1. Dependências

O build precisa de um compilador C/C++, das ferramentas GNU de build, das
bibliotecas de desenvolvimento que o GCC usa (GMP, MPFR, MPC) e do `meson`,
que compila a picolibc. Os submódulos do toolchain (binutils, gcc, picolibc,
gdb) são baixados na seção 2, por isso `git` e `curl` também são
necessários.

### 1.1. Debian-like (`apt`)

```bash
sudo apt-get install -y autoconf automake autotools-dev curl python3 \
  libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo \
  gperf libtool patchutils bc zlib1g-dev libexpat1-dev meson ninja-build git \
  cmake libglib2.0-dev expect device-tree-compiler libslirp-dev libzstd-dev \
  libncurses-dev
```

Verificar o que já está instalado:
```bash
dpkg -s autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev \
  libgmp-dev gawk build-essential bison flex texinfo gperf libtool \
  patchutils bc zlib1g-dev libexpat1-dev meson ninja-build git cmake \
  libglib2.0-dev expect device-tree-compiler libslirp-dev libzstd-dev \
  libncurses-dev
```

O pacote do `expat` costuma aparecer como `libexpat-dev` na documentação do
riscv-gnu-toolchain, mas em distros baseadas em Debian quem fornece esse
arquivo é o `libexpat1-dev` (`libexpat-dev` é só um nome virtual que ele
provê); `dpkg -s libexpat-dev` não encontra o pacote mesmo com ele instalado,
por isso a verificação acima já usa o nome real.

### 1.2. RHEL-like (`dnf`/`yum`)

Em RHEL 8 ou mais novo, `yum` é um alias de `dnf`; os dois comandos são
equivalentes.

```bash
sudo dnf install -y autoconf automake curl git python3 libmpc-devel \
  mpfr-devel gmp-devel gawk bison flex texinfo patchutils gcc gcc-c++ \
  zlib-devel expat-devel libslirp-devel ncurses-devel meson ninja-build cmake
```

Se algum pacote `-devel`, `texinfo`, `meson` ou `ninja-build` não for
encontrado, o repositório que o contém está desabilitado (`ninja-build`, em
particular, pode exigir o EPEL): habilite o `crb` (RHEL, Rocky,
Alma 9) ou o `powertools` (8) e repita:
```bash
sudo dnf config-manager --set-enabled crb   # ou powertools
```

Verificar o que já está instalado:
```bash
rpm -q autoconf automake curl git python3 libmpc-devel mpfr-devel gmp-devel \
  gawk bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel \
  libslirp-devel ncurses-devel meson ninja-build cmake
```

## 2. Criar o diretório do cache e o código-fonte

`/opt/riscv-foundation` é um diretório único de cache, para que ninguém
precise manter uma cópia própria dos toolchains RISC-V grandes. `/opt` em si
é padrão do FHS (Filesystem Hierarchy Standard) para software instalado
manualmente/add-on, fora do gerenciador de pacotes da distro; o nome
`riscv-foundation` da subpasta é uma convenção sugerida, ajuste conforme o
setup da sua máquina. O GCC fica em `/opt/riscv-foundation/riscv32-elf`, e o
arquivo `.tag` dentro dele guarda o hash do commit do
[riscv-collab/riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)
que gerou o conteúdo; é esse arquivo que decide se o cache está atualizado.

Quem cria e mantém esse diretório muda conforme a máquina. Numa workstation
que tem o usuário `runner` (ver [RUNNER_SETUP.md](../RUNNER_SETUP.md),
seção 3), o cache é compartilhado pelos usuários da máquina e pertence ao
`runner`, então pode ser atualizado sem `sudo`. Numa máquina de teste, sem esse usuário, o
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
execução) já deixa o toolchain instalado utilizável por qualquer usuário da
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

O código-fonte fica em `/opt/riscv-foundation/riscv-gnu-toolchain`, ao lado
do `riscv32-elf` do cache. Se `SRC_DIR` ainda não existir, o script clona o
branch padrão do repositório; se já existir de uma execução anterior, dá um
`pull` para trazer os commits novos, sem precisar reclonar:

```bash
set -euo pipefail
SRC_DIR=/opt/riscv-foundation/riscv-gnu-toolchain

if [ -d "$SRC_DIR/.git" ]; then
  git -C "$SRC_DIR" pull --ff-only
else
  git clone https://github.com/riscv-collab/riscv-gnu-toolchain "$SRC_DIR"
fi
git -C "$SRC_DIR" submodule sync --recursive
git -C "$SRC_DIR" submodule update --init --depth 1 binutils gcc gdb picolibc
```

Só os quatro submódulos usados no build são baixados, cada um com
`--depth 1`, sem o histórico completo. Os demais (newlib, glibc, musl, llvm,
qemu, spike, pk, dejagnu, uclibc-ng) ficam de fora. O resultado ocupa cerca
de 2,9 GB e fica em disco permanentemente em `SRC_DIR`.

## 3. Compilar e instalar no cache

### 3.1. Variantes

O build gera uma biblioteca para cada uma destas variantes. Uma biblioteca feita para menos extensões roda num
núcleo com mais extensões, e o contrário não vale; o compilador pega a maior variante que seja subconjunto do
`-march` informado.

| `-march` | `-mabi` | Multiplicação e divisão inteiras | Ponto flutuante |
| :--- | :--- | :--- | :--- |
| `rv32i` | `ilp32` | em software | em software |
| `rv32i_zmmul` | `ilp32` | multiplicação em hardware, divisão em software | em software |
| `rv32im` (o padrão) | `ilp32` | em hardware | em software |
| `rv32imf` | `ilp32f` | em hardware | precisão simples em hardware |
| `rv32imfd` | `ilp32d` | em hardware | precisão simples e dupla em hardware |

### 3.2. Build

Rode com o mesmo dono da seção 2.3. Com o `SRC_DIR` já atualizado, este passo confere se o cache precisa de
atualização e, se precisar, compila e instala:

```bash
set -euo pipefail
CACHE_DIR=/opt/riscv-foundation/riscv32-elf
SRC_DIR=/opt/riscv-foundation/riscv-gnu-toolchain
MULTILIB="rv32i-ilp32--;rv32i_zmmul-ilp32--;rv32im-ilp32--;rv32imf-ilp32f--;rv32imfd-ilp32d--"
COMMIT=$(git -C "$SRC_DIR" rev-parse HEAD)

if [ "$(cat "$CACHE_DIR/.tag" 2>/dev/null)" = "$COMMIT" ]; then
  echo "Cache is already at $COMMIT, nothing to do"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp riscv-gcc-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT
cd "$BUILD_DIR"

rm -rf "$CACHE_DIR" && mkdir -p "$CACHE_DIR"

# binutils and GDB, with the Makefile of riscv-gnu-toolchain
"$SRC_DIR/configure" --prefix="$CACHE_DIR" --with-arch=rv32im --enable-picolibc
make -j"$(nproc)" stamps/build-binutils-picolibc stamps/build-gdb-picolibc

# the compiler, and libgcc for every variant
mkdir gcc && cd gcc
"$SRC_DIR/gcc/configure" --target=riscv32-unknown-elf --prefix="$CACHE_DIR" \
  --disable-shared --disable-threads --with-system-zlib --enable-tls \
  --with-newlib --with-picolibc --with-sysroot="$CACHE_DIR/riscv32-unknown-elf" \
  --disable-libmudflap --disable-libssp --disable-libquadmath --disable-libgomp \
  --disable-nls --disable-tm-clone-registry --src="$SRC_DIR/gcc" \
  --with-multilib-generator="$MULTILIB" \
  --with-arch=rv32im --with-abi=ilp32 --with-isa-spec=20191213 \
  --enable-languages=c,c++ \
  CFLAGS_FOR_TARGET="-Os -mcmodel=medlow" CXXFLAGS_FOR_TARGET="-Os -mcmodel=medlow"
make -j"$(nproc)" all-gcc
make install-gcc
make -j"$(nproc)" all-target-libgcc
make install-target-libgcc
cd ..

# picolibc, compiled with that compiler for every variant
export PATH="$CACHE_DIR/bin:$PATH"
tool=riscv32-unknown-elf
cat > cross.txt <<EOF
[binaries]
c = ['$tool-gcc', '-nostdlib']
cpp = ['$tool-g++', '-nostdlib']
ar = '$tool-ar'
as = '$tool-as'
nm = '$tool-nm'
strip = '$tool-strip'
[host_machine]
system = 'unknown'
cpu_family = 'riscv32'
cpu = 'riscv32'
endian = 'little'
[properties]
c_args = ['-msave-restore', '-fno-common', '-mcmodel=medlow']
cpp_args = ['-msave-restore', '-fno-common', '-mcmodel=medlow']
skip_sanity_check = true
EOF
meson setup picolibc "$SRC_DIR/picolibc" --cross-file cross.txt --buildtype=minsize \
  --prefix="$CACHE_DIR/$tool" -Dincludedir=include -Dlibdir=lib \
  -Dsysroot-install=true -Dsystem-libc=true -Dtests=false
ninja -C picolibc install

echo "$COMMIT" > "$CACHE_DIR/.tag"
```

O script tem quatro etapas.

| Etapa | O que faz |
| :--- | :--- |
| binutils e GDB | O Makefile do riscv-gnu-toolchain os compila e instala para o alvo `riscv32-unknown-elf`; `--with-arch=rv32im` faz ele derivar esse alvo e o ABI `ilp32`, e sem ele o alvo padrão é RV64GC (`riscv64-unknown-elf-*`) |
| compilador | O `gcc/configure` é executado diretamente, porque a regra da picolibc do Makefile desliga o multilib; `--with-multilib-generator` recebe as variantes como `<arch>-<abi>--` separadas por `;` e implica multilib, e `--with-arch`/`--with-abi` definem a variante padrão |
| `libgcc` | Compilada com o compilador da etapa anterior, uma vez para cada variante |
| picolibc | Compilada pelo `meson` com esse compilador; ele lê as variantes do compilador e constrói uma biblioteca para cada uma, instalando-as no sysroot |

- O build roda fora da árvore do source, em `/var/tmp`: isso permite reconfigurar/recompilar sem sujar o
  `SRC_DIR`; `/tmp` costuma ser tmpfs, pequeno demais para árvore de build.
- O `.tag` é gravado por último: um build interrompido deixa o cache sem `.tag`, então a próxima execução
  recompila em vez de confiar num cache incompleto.
- O `-mcmodel=medlow` do `CFLAGS_FOR_TARGET` é o modelo de código do compilador e da picolibc; os dois
  precisam usar o mesmo.

O build acrescenta a árvore de compilação, apagada ao final em `/var/tmp`. Para adotar uma release nova do
riscv-gnu-toolchain, rode de novo os comandos das seções 2.3 e 3.2.

### 3.3. Reduzir o tamanho (opcional)

Os programas do host na instalação (compilador, linker e o resto) carregam seus símbolos, que são a maior parte
do tamanho. Removê-los leva a instalação de cerca de 2,5 GB para menos de 0,5 GB e não muda o que o toolchain
produz:

```bash
CACHE_DIR=/opt/riscv-foundation/riscv32-elf
find "$CACHE_DIR/bin" "$CACHE_DIR/libexec" "$CACHE_DIR/riscv32-unknown-elf/bin" -type f -perm /111 \
  -exec sh -c 'for f; do [ "$(head -c 4 "$f" | tail -c 3)" = ELF ] && strip --strip-unneeded "$f"; done; true' sh {} +
```

## 4. Verificar

```bash
CACHE=/opt/riscv-foundation/riscv32-elf
cat "$CACHE/.tag"
"$CACHE/bin/riscv32-unknown-elf-gcc" --version
"$CACHE/bin/riscv32-unknown-elf-gcc" -print-multi-lib
```

O último comando deve imprimir cinco linhas, uma para cada variante da seção 3.1 (o padrão é a raiz, `.`).
Para ver qual biblioteca um `-march` pega:

```bash
"$CACHE/bin/riscv32-unknown-elf-gcc" -march=rv32i -mabi=ilp32 --specs=picolibc.specs -print-file-name=libc.a
```

Para conferir que nenhum código da picolibc da variante padrão usa instruções que o core RV32IM não implementa
(CSR, atômicas), o `objdump` do próprio toolchain lê o `crt0.o` (o runtime de inicialização) e a `libc.a`:

```bash
"$CACHE/bin/riscv32-unknown-elf-objdump" -d "$CACHE/riscv32-unknown-elf/lib/crt0.o" \
  | grep -E 'csrr|csrw|lr\.w|sc\.w|amo'
"$CACHE/bin/riscv32-unknown-elf-objdump" -d "$CACHE/riscv32-unknown-elf/lib/libc.a" \
  | grep -E 'csrr|csrw|lr\.w|sc\.w|amo'
```

Nenhuma das duas buscas deve retornar nada: um `rv32im` simples não exige nem o Zicsr nem a extensão A
(atômicas).

## 5. PATH global

Adiciona os binários do GCC ao `PATH` global, criando um wrapper
para cada um em `/usr/local/bin`:

```bash
for f in /opt/riscv-foundation/riscv32-elf/bin/riscv32-unknown-elf-*; do
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
which riscv32-unknown-elf-gcc
```

Precisa rodar de novo só se uma release nova adicionar um binário com nome
novo; os já existentes continuam apontando para o mesmo caminho.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
