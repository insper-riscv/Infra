# dev_tools

`ghcr.io/<organização>/dev_tools` é o ambiente de desenvolvimento para um Dev Container: o último nível das imagens, a [`ci-elf`](ci-elf.md) (e portanto os níveis VHDL, assembly e ELF) mais o que se precisa para trabalhar dentro dela, e o usuário `dev`. A visão geral das imagens está em [README.md](README.md). Ela é construída a partir do `Dockerfile.devtools` pelo workflow `Dev tools image` e publicada para `linux/amd64` e `linux/arm64`.

## 1. O que ela soma à ci-elf

| Acréscimo | Detalhe |
| :--- | :--- |
| GTKWave | a ponta do branch `lts` (linha de manutenção 3.3, árvore GTK 3), copiado da imagem `base-gtkwave` para `/opt/gtkwave`; roda em Wayland nativo e em X11 |
| Usuário | `dev`, com `/work` como diretório de trabalho |
| Ferramentas de compilação | `build-essential`, `pkg-config`, `gnat` |

O GHDL, o Yosys, o GCC RISC-V com picolibc, o Spike, o Sail, as dependências do ACT4, o `uv`, o Python 3.14 e o cocotb 2.1.0 vêm da `ci-elf`, que também explica por que o Python é fixado em 3.14 (o cocotb o fixa). A imagem não tem `pip`: um projeto Python instala as outras dependências com `uv sync`, que encontra esse Python.

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

O GTKWave é a árvore GTK 3 da linha de manutenção 3.3, que tem backend Wayland. O `twinwave` e a opção `-X` embutem janelas com XEmbed, que só existe em X11, e não funcionam em Wayland; abrir um arquivo de forma de onda não usa nenhum dos dois.

O GTKWave precisa de uma tela. Em Wayland, passe o socket do compositor e o nome dele:

```bash
docker run --rm -it -v "$PWD:/work" \
  -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY" \
  -e XDG_RUNTIME_DIR=/tmp -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  --user "$(id -u):$(id -g)" \
  ghcr.io/insper-riscv/dev_tools:latest gtkwave sim.ghw
```

Numa sessão X11, onde não há socket Wayland, monte o socket do X e passe o `DISPLAY`: `-v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY`. Para forçar um backend, defina `GDK_BACKEND=wayland` ou `GDK_BACKEND=x11`.

Num daemon do Docker que remapeia user namespaces (`userns-remap`), o usuário do host aparece como `nobody` dentro do contêiner e não consegue usar o socket nem o diretório montado: acrescente `--userns=host` ao comando.

## 3. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `Dockerfile.devtools` |
| Workflow | `Dev tools image` |
| Tags | `latest`, `sha-<commit do Infra>` e `elf-<12 do digest da ci-elf>-gtkwave-<7>` |
| Rótulo | `gtkwave.commit` |
| Agenda | quando `ELF image` ou `GTKWave image` termina |

A imagem é montada a partir da `ci-elf` mais recente e da `base-gtkwave` mais recente, então uma versão nova de qualquer uma gera uma imagem nova. A tag longa nomeia o digest da `ci-elf` porque qualquer nível abaixo dela pode mudar sem que o commit do GTKWave mude, e uma combinação que já tem imagem não é construída de novo. As regras que toda imagem montada segue, como esperar o que ela copia e um workflow em andamento, estão na seção 4 da [visão geral das imagens](README.md).

O GTKWave vem da [`base-gtkwave`](base-gtkwave.md); para atualizá-lo, rode o workflow `GTKWave image`, e a `dev_tools` é reconstruída quando esse run termina.

Antes de publicar, o workflow confere que a imagem roda como o usuário `dev` em `/work`, que o GHDL, o Sail, o Ruby, o GCC RISC-V, o `uv`, o Python com cocotb e uma compilação nativa funcionam, e que o GTKWave tem todas as suas bibliotecas.

## 4. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |

## 5. Construindo localmente

```bash
docker build -f Dockerfile.devtools -t dev_tools \
  --build-arg ELF_IMAGE=ci-elf --build-arg GTKWAVE_IMAGE=base-gtkwave .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `ELF_IMAGE` | `ci-elf:latest` | o nível abaixo |
| `GTKWAVE_IMAGE` | `base-gtkwave:latest` | de onde vem o GTKWave |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
