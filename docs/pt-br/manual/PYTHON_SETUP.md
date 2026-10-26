# Instalando o uv, o Python e o cocotb

`uv` e um Python para todos os usuários da máquina, com o cocotb, a biblioteca que os testbenches usam, e o `click`, que o SymbiYosys importa. A instalação gera:

| Componente | Papel |
| :--- | :--- |
| `uv`, `uvx` | Gerenciador de projetos Python, em `/usr/local/bin` |
| Python | A série 3.14, instalada pelo `uv` em `/opt/uv/python`, com `python3` e `python` em `/usr/local/bin` |
| cocotb | 2.1.0, instalado nesse Python |
| `click` | 8.5.0, instalado nesse Python |

## 1. Dependências

### 1.1. Debian-like (`apt`)

Os comandos foram executados no Ubuntu 26.04.

```bash
sudo apt-get install -y ca-certificates curl git gcc g++
```

### 1.2. RHEL-like (`dnf`/`yum`)

Em RHEL 8 ou mais novo, `yum` é um alias de `dnf`; os dois comandos são equivalentes. Os comandos foram executados no Rocky Linux 9.

Alguns pacotes estão nos repositórios `crb` e EPEL; habilite-os antes:

```bash
sudo dnf install -y dnf-plugins-core epel-release
sudo dnf config-manager --set-enabled crb
```

No próprio RHEL, o `epel-release` não está nos repositórios base: habilite o EPEL como descrito na [documentação dele](https://docs.fedoraproject.org/en-US/epel/).

O comando `curl` já é fornecido pelo `curl-minimal`, que o Rocky instala, e o pacote `curl` conflita com ele, então o `curl` não está na lista.

```bash
sudo dnf install -y ca-certificates git gcc gcc-c++
```

## 2. Compilar e instalar

Rode o script como root (por exemplo com `sudo -i`): ele escreve em `/opt` e, onde indicado, em `/usr/local/bin` e `/etc/profile.d`.

```bash
set -euo pipefail
UV_SERIES=0
PYTHON_SERIES=3.14
COCOTB_VERSION=2.1.0
CLICK_VERSION=8.5.0

# uv, from the installer of the latest release of the series, in /usr/local/bin
UV_VERSION=$(git ls-remote --tags --refs https://github.com/astral-sh/uv "$UV_SERIES.*" \
             | sed 's|.*refs/tags/||' | grep -E "^$UV_SERIES\.[0-9]+\.[0-9]+$" | sort -V | tail -n 1)
curl -fsSL "https://astral.sh/uv/$UV_VERSION/install.sh" -o /tmp/uv-install.sh
UV_UNMANAGED_INSTALL=/usr/local/bin sh /tmp/uv-install.sh
rm /tmp/uv-install.sh

# Python, in a directory every user reads, with cocotb and click installed in it
export UV_PYTHON_INSTALL_DIR=/opt/uv/python UV_PYTHON_PREFERENCE=only-managed
uv python install "$PYTHON_SERIES"
python=$(uv python find "$PYTHON_SERIES")
uv pip install --break-system-packages --python "$python" \
  "cocotb==$COCOTB_VERSION" "click==$CLICK_VERSION"
ln -sf "$python" /usr/local/bin/python3
ln -sf "$python" /usr/local/bin/python
chmod -R a+rX /opt/uv

# every user's shell finds that Python instead of downloading another
cat > /etc/profile.d/uv-python.sh <<'EOF'
export UV_PYTHON_INSTALL_DIR=/opt/uv/python
export UV_PYTHON_PREFERENCE=only-managed
EOF
```

- O Python 3.14 é a versão que os projetos exigem (`>=3.14,<3.15`), e o cocotb 2.1.0 é a primeira release que o suporta; o cocotb é quem fixa a versão do Python.
- O instalador da versão escolhida do `uv` confere o binário contra o SHA-256 que ele carrega, e `UV_UNMANAGED_INSTALL` instala em `/usr/local/bin` sem mexer no `PATH` nem no perfil do shell de ninguém.
- `--break-system-packages` é necessário porque o `uv` marca o Python que instala como gerenciado externamente.
- `/etc/profile.d/uv-python.sh` faz todo shell achar esse Python, então o `uv sync` de um projeto o usa em vez de baixar outro.

Para atualizar, rode de novo o script da seção 2.

## 3. Verificar

```bash
uv --version
python3 -c "import sys, cocotb, importlib.metadata as m; print('python', sys.version.split()[0], 'cocotb', cocotb.__version__, 'click', m.version('click'))"
```

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
