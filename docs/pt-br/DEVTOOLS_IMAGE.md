# Imagem de ferramentas de desenvolvimento

`ghcr.io/<organização>/dev_tools` é o ambiente de desenvolvimento para um Dev Container: a [imagem completa do toolchain](TOOLCHAIN_IMAGE.md) mais o que se precisa para trabalhar dentro dela, e o usuário `dev`. Ela é construída a partir do `Dockerfile.devtools` pelo workflow `Dev tools image` e publicada para `linux/amd64`.

## 1. O que ela soma à imagem do toolchain

| Acréscimo | Detalhe |
| :--- | :--- |
| Usuário | `dev`, com `/work` como diretório de trabalho |
| Ferramentas de compilação | `build-essential`, `pkg-config`, `gnat` |
| Síntese e formas de onda | `yosys`, `gtkwave` |

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

## 3. Publicação

| Tag | Significado |
| :--- | :--- |
| `latest` | a última publicação |
| `sha-<commit do Infra>` | o commit do Infra que a construiu |

O workflow roda quando o workflow `Toolchain image` termina, quando o `Dockerfile.devtools` muda no `main` e sob demanda, com o mesmo segredo de confirmação dos outros workflows de imagem. Ele constrói a imagem, confere que o usuário, o GHDL, o GCC, o `yosys`, o `gtkwave`, o `uv` e uma compilação nativa funcionam, e só então publica.

## 4. Limites

A imagem é só `linux/amd64`: numa máquina ARM o Docker a roda por emulação. A imagem do toolchain em que ela se apoia tem o mesmo limite.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../LICENSE).
