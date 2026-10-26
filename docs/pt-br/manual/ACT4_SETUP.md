# Instalando o ambiente do ACT4

As dependências para rodar a suíte ACT4 (riscv-arch-test, os Architectural Certification Tests): Ruby, Bundler, as gems Ruby do UDB e os pacotes Python de um commit do ACT4. O GCC RISC-V ([GCC_SETUP.md](GCC_SETUP.md)), o `uv` e o Python ([PYTHON_SETUP.md](PYTHON_SETUP.md)) e o Sail ([SAIL_SETUP.md](SAIL_SETUP.md)) são instalados antes. A instalação gera:

| Componente | Papel |
| :--- | :--- |
| Ruby e Bundler | Ruby 3.3 da distro e Bundler 4.0.23, a versão que o `Gemfile.lock` do ACT4 registra; o `Gemfile` aceita Ruby `~> 3.2` |
| `/opt/act-bundle` | As gems Ruby do ACT4 (as gems do UDB e suas dependências) |
| `/opt/act-uv-cache` | Os pacotes Python desse commit, no cache do `uv` |
| `/opt/act-cache` | Os programas auxiliares e a biblioteca Z3 que as gems do UDB baixam na instalação |

## 1. Dependências

### 1.1. Debian-like (`apt`)

Os comandos foram executados no Ubuntu 26.04.

```bash
sudo apt-get install -y build-essential git ca-certificates ruby ruby-dev libyaml-dev \
  libffi-dev zlib1g-dev libssl-dev libz3-dev
```

### 1.2. RHEL-like (`dnf`/`yum`)

Em RHEL 8 ou mais novo, `yum` é um alias de `dnf`; os dois comandos são equivalentes. Os comandos foram executados no Rocky Linux 9.

Alguns pacotes estão nos repositórios `crb` e EPEL; habilite-os antes:

```bash
sudo dnf install -y dnf-plugins-core epel-release
sudo dnf config-manager --set-enabled crb
```

No próprio RHEL, o `epel-release` não está nos repositórios base: habilite o EPEL como descrito na [documentação dele](https://docs.fedoraproject.org/en-US/epel/).

O Rocky Linux 9 traz o Ruby 3.0 e o `Gemfile` do ACT4 aceita Ruby `~> 3.2`, então o módulo do Ruby 3.3 é habilitado antes dos pacotes.

```bash
sudo dnf module enable -y ruby:3.3
sudo dnf install -y gcc gcc-c++ make git ca-certificates ruby ruby-devel libyaml-devel \
  libffi-devel zlib-devel openssl-devel z3-devel
```

## 2. Compilar e instalar

Rode o script como root (por exemplo com `sudo -i`): ele escreve em `/opt` e, onde indicado, em `/usr/local/bin` e `/etc/profile.d`.

```bash
set -euo pipefail
ACT4_COMMIT=<commit of riscv/riscv-arch-test that the project pins>
BUNDLER_VERSION=4.0.23

gem install --no-document bundler -v "$BUNDLER_VERSION"

# fixed directories that any user can write, so a project's own checkout of ACT4 finds the
# gems and the Python packages and can still add what its commit needs
cat > /etc/profile.d/act4.sh <<'EOF'
export BUNDLE_PATH=/opt/act-bundle
export UV_CACHE_DIR=/opt/act-uv-cache
export XDG_CACHE_HOME=/opt/act-cache
EOF
. /etc/profile.d/act4.sh
mkdir -p "$BUNDLE_PATH" "$UV_CACHE_DIR" "$XDG_CACHE_HOME"

BUILD_DIR=$(mktemp -d -p /var/tmp act4-build.XXXXXX)
trap "rm -rf \"$BUILD_DIR\"" EXIT
git init "$BUILD_DIR/act4"
git -C "$BUILD_DIR/act4" fetch --depth 1 https://github.com/riscv/riscv-arch-test "$ACT4_COMMIT"
git -C "$BUILD_DIR/act4" checkout FETCH_HEAD

(cd "$BUILD_DIR/act4/framework/src/act/data" && bundle install --jobs 4)
(cd "$BUILD_DIR/act4" && uv sync --frozen --all-packages)

chmod -R a+rwX "$BUNDLE_PATH" "$UV_CACHE_DIR" "$XDG_CACHE_HOME"
```

- Defina `ACT4_COMMIT` como o commit do `riscv/riscv-arch-test` que o projeto fixa, para que as dependências instaladas sejam as que esse commit registra.
- `/etc/profile.d/act4.sh` aponta `BUNDLE_PATH`, `UV_CACHE_DIR` e `XDG_CACHE_HOME` para os três diretórios, em todo shell; os diretórios podem ser escritos por qualquer usuário, então o checkout próprio do ACT4 de um projeto encontra o que foi instalado e ainda pode acrescentar o que o commit dele precisa.

Para atualizar, rode de novo o script da seção 2.

## 3. Verificar

```bash
ruby --version
bundle --version
sail_riscv_sim --version
```

Depois, no diretório do ACT4, a suíte é gerada, compilada e executada como na documentação do ACT4. O compilador da instalação é o `riscv32-unknown-elf-gcc`, então a configuração do DUT o nomeia:

```yaml
compiler_exe: riscv32-unknown-elf-gcc
objdump_exe: riscv32-unknown-elf-objdump
ref_model_exe: sail_riscv_sim
```

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
