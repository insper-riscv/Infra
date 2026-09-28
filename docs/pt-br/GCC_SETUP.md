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
| picolibc (`libc.a` + headers) | Biblioteca C para bare-metal, compilada para `rv32im`: cobre `printf`, `scanf`, `malloc` e `free` sem depender de um sistema operacional |

## 1. Dependências

O build precisa de um compilador C/C++, das ferramentas GNU de build, das
bibliotecas de desenvolvimento que o GCC usa (GMP, MPFR, MPC) e do `meson`,
que compila a picolibc. Os submódulos do toolchain (binutils, gcc, picolibc,
gdb) são baixados pelo próprio `./configure`, por isso `git` e `curl` também
são necessários.

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
git -C "$SRC_DIR" submodule update --init --recursive
```

O clone inicial ocupa a maior parte dos cerca de 6,65 GB que o upstream cita
para o repositório com submódulos, e fica em disco permanentemente em
`SRC_DIR` depois disso.

## 3. Compilar e instalar no cache

Rode como o mesmo dono da seção 2.3. Com `SRC_DIR` já atualizado, este passo
confere se o cache precisa ser atualizado e, se sim, compila e instala:

```bash
set -euo pipefail
CACHE_DIR=/opt/riscv-foundation/riscv32-elf
SRC_DIR=/opt/riscv-foundation/riscv-gnu-toolchain
COMMIT=$(git -C "$SRC_DIR" rev-parse HEAD)

if [ "$(cat "$CACHE_DIR/.tag" 2>/dev/null)" = "$COMMIT" ]; then
  echo "O cache já está em $COMMIT, nada a fazer"
  exit 0
fi

BUILD_DIR=$(mktemp -d -p /var/tmp riscv-gcc-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT
cd "$BUILD_DIR"

rm -rf "$CACHE_DIR" && mkdir -p "$CACHE_DIR"
"$SRC_DIR/configure" --prefix="$CACHE_DIR" --with-arch=rv32im --enable-picolibc
make -j"$(nproc)"
echo "$COMMIT" > "$CACHE_DIR/.tag"
```

O `./configure` recebe `--with-arch=rv32im`, que faz o próprio script
derivar `--with-abi=ilp32` (soft-float) e o prefixo `riscv32-unknown-elf-`
dos binários, e `--enable-picolibc`, que faz o `make` sozinho compilar
binutils, GCC (em dois estágios) e a picolibc para esse alvo, sem multilib.

| Flag | Efeito |
| :--- | :--- |
| `--prefix` no próprio cache | O `make` já instala no prefixo durante o build; não existe um `make install` separado |
| `--with-arch=rv32im` | Faz o `./configure` derivar `--with-abi=ilp32` e o prefixo `riscv32-unknown-elf-`; sem ele o alvo padrão é RV64GC (`riscv64-unknown-elf-*`) |
| `--enable-picolibc`, sem `--enable-multilib` | picolibc só compila uma variante por build; o `--enable-multilib` do toolchain é rejeitado junto com ela |

- O build roda fora da árvore do source, em `/var/tmp`: isso permite
  reconfigurar/recompilar sem sujar o `SRC_DIR`; `/tmp` costuma ser tmpfs,
  pequeno demais para árvore de build.
- O `.tag` é gravado por último: um build interrompido deixa o cache sem
  `.tag`, então a próxima execução recompila em vez de confiar num cache
  incompleto.

O build acrescenta a árvore de compilação, apagada ao final em `/var/tmp`.
Levou por volta de dez minutos numa máquina com 22 núcleos. Para adotar uma
release nova do riscv-gnu-toolchain, rode de novo os comandos das seções
2.3 e 3.

## 4. Verificar

```bash
cat /opt/riscv-foundation/riscv32-elf/.tag
/opt/riscv-foundation/riscv32-elf/bin/riscv32-unknown-elf-gcc --version
/opt/riscv-foundation/riscv32-elf/bin/riscv32-unknown-elf-gcc -print-multi-lib
```

A última linha deve imprimir só `.;` (uma variante, a raiz), confirmando que
não há multilib. Para conferir que nenhum código da picolibc usa instruções
que o core RV32IM não implementa (CSR, atômicas), o `objdump` do próprio
toolchain lê o `crt0.o` (o runtime de inicialização) e a `libc.a`:

```bash
CACHE=/opt/riscv-foundation/riscv32-elf
"$CACHE/bin/riscv32-unknown-elf-objdump" -d "$CACHE/riscv32-unknown-elf/lib/crt0.o" \
  | grep -E 'csrr|csrw|lr\.w|sc\.w|amo'
"$CACHE/bin/riscv32-unknown-elf-objdump" -d "$CACHE/riscv32-unknown-elf/lib/libc.a" \
  | grep -E 'csrr|csrw|lr\.w|sc\.w|amo'
```

As duas buscas não devem retornar nada: nem o Zicsr nem a extensão A
(atômicas) são exigidos por um `rv32im` puro.

## 5. PATH global

Adiciona os binários do GCC ao `PATH` global, symlinkando para
`/usr/local/bin`:

```bash
for f in /opt/riscv-foundation/riscv32-elf/bin/riscv32-unknown-elf-*; do
  sudo ln -sf "$f" /usr/local/bin/
done
```

Verificar:
```bash
which riscv32-unknown-elf-gcc
```

Precisa rodar de novo só se uma release nova adicionar um binário com nome
novo; os já existentes continuam apontando para o mesmo caminho.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../LICENSE).
