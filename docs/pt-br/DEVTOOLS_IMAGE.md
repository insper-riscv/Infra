# Imagem de ferramentas de desenvolvimento

`ghcr.io/<organização>/dev_tools` é o ambiente de desenvolvimento para um Dev Container: a [imagem completa do toolchain](TOOLCHAIN_IMAGE.md) mais o que se precisa para trabalhar dentro dela, e o usuário `dev`. Ela é construída a partir do `Dockerfile.devtools` pelo workflow `Dev tools image` e publicada para `linux/amd64`.

## 1. O que ela soma à imagem do toolchain

| Acréscimo | Detalhe |
| :--- | :--- |
| GTKWave | linha de desenvolvimento 4.0.0 (GTK 3 e 4), copiado da imagem `infra-gtkwave` para `/opt/gtkwave`; roda em Wayland nativo e em X11 |
| Usuário | `dev`, com `/work` como diretório de trabalho |
| Ferramentas de compilação | `build-essential`, `pkg-config`, `gnat` |
| Python | 3.14, instalado para o `dev` com `uv python install` |

O GHDL, o GCC RISC-V com picolibc, o Spike e o `uv` vêm da imagem do toolchain. A imagem não tem ambiente virtual nem `pip`: um projeto Python instala as dependências com `uv sync`, e o `uv` busca o Python de que precisa.

## 2. Como usar

Interativamente, com o diretório atual montado:

```bash
docker run --rm -it -v "$PWD:/work" ghcr.io/insper-riscv/dev_tools:latest
```

Em um `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/insper-riscv/dev_tools:latest",
  "remoteUser": "dev",
  "workspaceFolder": "/work",
  "workspaceMount": "source=${localWorkspaceFolder},target=/work,type=bind,consistency=cached"
}
```

### 2.1 Abrir o GTKWave

O GTKWave precisa de uma tela. Em Wayland, passe o socket do compositor e o nome dele:

```bash
docker run --rm -it -v "$PWD:/work" \
  -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY" \
  -e XDG_RUNTIME_DIR=/tmp -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  --user "$(id -u):$(id -g)" \
  ghcr.io/insper-riscv/dev_tools:latest gtkwave sim.ghw
```

Em X11 (ou Wayland pelo XWayland), monte o socket do X e passe o `DISPLAY`: `-v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY`.

## 3. Publicação

| Tag | Significado |
| :--- | :--- |
| `latest` | a última publicação |
| `sha-<commit do Infra>` | o commit do Infra que a construiu |

O GTKWave é construído pela imagem própria `infra-gtkwave` (Dockerfile.gtkwave, workflow `GTKWave image`), do mesmo jeito que o GCC e o Spike: um estágio de build compila o commit, e a imagem publicada guarda só o diretório de instalação. Para atualizar o GTKWave, rode o workflow `GTKWave image` à mão com o commit desejado (vazio: o último da branch padrão do upstream); a imagem `dev_tools` é então reconstruída.

O workflow roda quando o `Toolchain image` ou o `GTKWave image` termina, quando o `Dockerfile.devtools` muda no `main` e sob demanda, com o mesmo segredo de confirmação dos outros workflows de imagem. Ele constrói a imagem, confere que o usuário, o GHDL, o GCC, as bibliotecas do GTKWave, o `uv`, o Python e uma compilação nativa funcionam, e só então publica.

## 4. Limites

A imagem é só `linux/amd64`: numa máquina ARM o Docker a roda por emulação. A imagem do toolchain em que ela se apoia tem o mesmo limite.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
