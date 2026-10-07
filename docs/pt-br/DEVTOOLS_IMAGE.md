# Imagem de ferramentas de desenvolvimento

`ghcr.io/<organização>/dev_tools` é o ambiente de desenvolvimento para um Dev Container: a [imagem completa do toolchain](TOOLCHAIN_IMAGE.md) mais o que se precisa para trabalhar dentro dela, e o usuário `dev`. Ela é construída a partir do `Dockerfile.devtools` pelo workflow `Dev tools image` e publicada para `linux/amd64` e `linux/arm64`.

## 1. O que ela soma à imagem do toolchain

| Acréscimo | Detalhe |
| :--- | :--- |
| GTKWave | linha estável 3.3 (3.3.116, árvore GTK 3), copiado da imagem `infra-gtkwave` para `/opt/gtkwave`; roda em Wayland nativo e em X11 |
| Usuário | `dev`, com `/work` como diretório de trabalho |
| Ferramentas de compilação | `build-essential`, `pkg-config`, `gnat` |

O GHDL, o GCC RISC-V com picolibc, o Spike, o `uv`, o Python 3.14 e o cocotb 2.1.0 vêm da imagem do toolchain, que também explica por que o Python é fixado em 3.14 (o cocotb o fixa). A imagem não tem `pip`: um projeto Python instala as outras dependências com `uv sync`, que encontra esse Python.

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

O GTKWave é a árvore GTK 3 da linha estável 3.3, que tem backend Wayland. O `twinwave` e a opção `-X` embutem janelas com XEmbed, que só existe em X11, e não funcionam em Wayland; abrir um arquivo de forma de onda não usa nenhum dos dois.

O GTKWave precisa de uma tela. Em Wayland, passe o socket do compositor e o nome dele:

```bash
docker run --rm -it -v "$PWD:/work" \
  -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY" \
  -e XDG_RUNTIME_DIR=/tmp -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  --user "$(id -u):$(id -g)" \
  ghcr.io/insper-riscv/dev_tools:latest gtkwave sim.ghw
```

Numa sessão X11, onde não há socket Wayland, monte o socket do X e passe o `DISPLAY`: `-v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY`. Para forçar um backend, defina `GDK_BACKEND=wayland` ou `GDK_BACKEND=x11`.

## 3. Publicação

| Tag | Significado |
| :--- | :--- |
| `latest` | a última publicação |
| `sha-<commit do Infra>` | o commit do Infra que a construiu |

O GTKWave é construído pela imagem própria `infra-gtkwave` (Dockerfile.gtkwave, workflow `GTKWave image`), do mesmo jeito que o GCC e o Spike: um estágio de build compila o commit, e a imagem publicada guarda só o diretório de instalação. Para atualizar o GTKWave, rode o workflow `GTKWave image` à mão com o commit desejado (vazio: o último da branch padrão do upstream); a imagem `dev_tools` é então reconstruída.

O workflow roda quando o `Toolchain image` ou o `GTKWave image` termina, quando o `Dockerfile.devtools` muda no `main` e sob demanda, com o mesmo segredo de confirmação dos outros workflows de imagem. Como o `Toolchain image`, ele não falha quando falta uma entrada e não monta duas vezes. Se a imagem `infra-gtkwave` ou `infra-toolchain` ainda não foi publicada, termina com um aviso e roda quando elas terminarem. Se um run de `GTKWave image` ou `Toolchain image` estiver na fila ou em andamento, ele pula com um aviso, e o fim desse run o dispara de novo, de modo que o último a terminar faz a montagem única. Quando um run é disparado para uma combinação de commits que já tem imagem (tag `ghdl-<7>-gcc-<7>-spike-<7>-gtkwave-<7>-toolchain-<12>`, que termina com o início do digest da imagem do toolchain, porque o toolchain pode mudar sem que os commits dos componentes mudem), nada é construído. Um run manual nunca adia, e falha com uma mensagem quando as entradas não existem.

Ele constrói a imagem, confere que o usuário, o GHDL, o GCC, as bibliotecas do GTKWave, o `uv`, o Python e uma compilação nativa funcionam, e só então publica.

## 4. Arquiteturas

A imagem é publicada para `linux/amd64` e `linux/arm64` (um PC Intel ou AMD, e uma máquina ARM como um Mac), com as mesmas versões das mesmas ferramentas nas duas: o GHDL tem o backend LLVM, e o GCC, o Spike e o GTKWave são compilados dos mesmos commits.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
