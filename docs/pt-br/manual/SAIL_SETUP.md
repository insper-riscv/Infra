# Instalando o Sail

O modelo Sail RISC-V (`sail_riscv_sim`), do tarball da release `0.N` estável mais recente do `riscv/sail-riscv`, instalado em `/opt/riscv-foundation/sail`. As pré-releases semanais do repositório não são releases estáveis e não entram. A instalação gera:

| Componente | Papel |
| :--- | :--- |
| `sail_riscv_sim` | O executável do modelo: roda um programa RISC-V e calcula o resultado esperado de cada teste |
| `include`, `share` | Os cabeçalhos e arquivos de dados que o tarball da release traz |

## 1. Dependências

### 1.1. Debian-like (`apt`)

Os comandos foram executados no Ubuntu 26.04.

```bash
sudo apt-get install -y ca-certificates curl git jq
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
sudo dnf install -y ca-certificates git jq
```

## 2. Compilar e instalar

Rode o script como root (por exemplo com `sudo -i`): ele escreve em `/opt` e, onde indicado, em `/usr/local/bin` e `/etc/profile.d`.

```bash
set -euo pipefail
PREFIX=/opt/riscv-foundation/sail
VERSION=$(git ls-remote --tags --refs https://github.com/riscv/sail-riscv | sed 's|.*refs/tags/||' \
          | grep -E '^0\.[0-9]+$' | sort -V | tail -n 1)

if [ "$(cat "$PREFIX/.tag" 2>/dev/null)" = "$VERSION" ]; then
  echo "Sail is already at $VERSION, nothing to do"
  exit 0
fi

case "$(uname -m)" in
  x86_64)  asset=sail-riscv-Linux-x86_64.tar.gz ;;
  aarch64) asset=sail-riscv-Linux-aarch64.tar.gz ;;
  *) echo "no Sail release for $(uname -m)"; exit 1 ;;
esac

# GitHub publishes the SHA-256 of each asset of a release
sum=$(curl -fsSL "https://api.github.com/repos/riscv/sail-riscv/releases/tags/$VERSION" \
      | jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .digest')
curl -fsSL -o /tmp/sail.tar.gz "https://github.com/riscv/sail-riscv/releases/download/$VERSION/$asset"
echo "${sum#sha256:}  /tmp/sail.tar.gz" | sha256sum -c -

rm -rf "$PREFIX" && mkdir -p "$PREFIX"
tar -xzf /tmp/sail.tar.gz -C "$PREFIX" --strip-components=1
rm /tmp/sail.tar.gz
echo "$VERSION" > "$PREFIX/.tag"
```

- A release nomeia os tarballs pela arquitetura da máquina (`x86_64`, `aarch64`), e o GitHub publica o SHA-256 de cada arquivo, que o script confere antes de extrair.
- O build roda em `/var/tmp`, e não em `/tmp`, que costuma ser um tmpfs pequeno demais para a árvore de build, e o diretório é apagado ao final.
- O `.tag` é gravado por último: um build interrompido deixa a instalação sem `.tag`, então a próxima execução recompila em vez de confiar numa instalação incompleta, e uma execução na versão já instalada não faz nada.

Para atualizar, rode de novo o script da seção 2.

## 3. Verificar

```bash
/opt/riscv-foundation/sail/bin/sail_riscv_sim --version
ldd /opt/riscv-foundation/sail/bin/sail_riscv_sim | grep "not found" || echo "no missing library"
```

## 4. PATH global

Acrescenta os binários ao `PATH` global, criando um wrapper para cada um em `/usr/local/bin`:

```bash
for f in /opt/riscv-foundation/sail/bin/*; do
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
