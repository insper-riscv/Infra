# Imagem Docker da toolchain

Uma imagem Docker com tudo o que o fluxo de testes RISC-V precisa, exceto o Quartus: GHDL, o GCC RISC-V com picolibc, o Spike e o `uv`. O `Dockerfile` na raiz deste repositório a constrói, e o workflow `toolchain image` a publica no GitHub Container Registry.

## 1. O que a imagem contém

| Componente | Detalhe | Caminho |
| :--- | :--- | :--- |
| GHDL | Backend mcode, herdado da imagem base `ghdl/ghdl` | `/opt/ghdl` |
| GCC RISC-V | Alvo `rv32im`/`ilp32` com picolibc, uma única variante de biblioteca (o que o [GCC_SETUP.md](GCC_SETUP.md) compila) | `/opt/riscv-foundation/riscv32-elf` |
| Spike | Com o módulo de debug movido do endereço `0x0` para `0x70000000` (o que o [SPIKE_SETUP.md](SPIKE_SETUP.md) compila) | `/opt/riscv-foundation/spike` |
| `uv` | Gerenciador de projetos Python | `/usr/local/bin` |

Os binários do GCC e do Spike já estão no `PATH` da imagem. Cada instalação guarda em `.tag` o commit de que foi compilada.

O Quartus não está na imagem, e um container não enxerga o USB-Blaster sem configuração extra do host. Os testes de hardware real continuam rodando no runner self-hosted descrito no [RUNNER_SETUP.md](RUNNER_SETUP.md).

## 2. Usando a imagem

Interativamente, com o diretório atual montado:

```bash
docker run --rm -it -v "$PWD:/workspace" ghcr.io/insper-riscv/infra-toolchain:latest
```

Num job do GitHub Actions:

```yaml
jobs:
  sim:
    runs-on: ubuntu-24.04
    container:
      image: ghcr.io/insper-riscv/infra-toolchain:latest
    steps:
      - uses: actions/checkout@v7.0.1
      - run: riscv32-unknown-elf-gcc --version
```

Para um resultado reproduzível, use a tag `sha-<commit>` da publicação desejada em vez de `latest`.

## 3. Construindo localmente

```bash
docker build -t infra-toolchain .
```

O build compila o GCC, o que leva de dezenas de minutos a mais de uma hora, conforme a máquina. Os argumentos de build fixam o que é compilado:

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `RISCV_GNU_TOOLCHAIN_COMMIT` | commit fixo | Commit do `riscv-collab/riscv-gnu-toolchain` a compilar |
| `RISCV_ISA_SIM_COMMIT` | commit fixo | Commit do `riscv-software-src/riscv-isa-sim` a compilar |
| `GHDL_IMAGE` | `ghdl/ghdl:6.0.0-mcode-ubuntu-24.04` | Imagem base, que traz o GHDL |
| `UV_VERSION` | versão fixa | Versão do `uv` |

Por exemplo, para compilar outro commit do Spike:

```bash
docker build --build-arg RISCV_ISA_SIM_COMMIT=<commit> -t infra-toolchain .
```

## 4. Publicação

O workflow `.github/workflows/toolchain-image.yml` roda a cada push na `main` que altera o `Dockerfile` ou o próprio workflow, e sob demanda (`workflow_dispatch`). Ele:

1. Constrói a imagem com cache de camadas do GitHub Actions.
2. Confere a imagem antes de publicar: GHDL, GCC com picolibc, uma única variante de biblioteca, Spike sem sobreposição do módulo de debug e `uv`.
3. Publica em `ghcr.io/<organização>/infra-toolchain` com as tags `latest` e `sha-<commit>`.

A visibilidade do pacote (pública ou privada) é definida nas configurações do pacote no GitHub, e não pelo workflow.

### 4.1. Execução manual

A execução manual (Actions → `toolchain image` → **Run workflow**) pede o campo `confirm`, que precisa ser igual ao valor do secret `IMAGE_PUBLISH_SECRET`. É o mesmo segundo portão descrito na Fase 5 do [RUNNER_SETUP.md](RUNNER_SETUP.md): o acesso de escrita ao repositório já controla quem pode disparar o workflow, e o secret garante que só quem o conhece publique a imagem. Um push na `main` não passa por essa checagem, porque o portão desse caminho é a proteção de branch.

Para configurar, no repositório: **Settings → Secrets and variables → Actions → New repository secret**, com o nome `IMAGE_PUBLISH_SECRET` e como valor qualquer frase (por exemplo `openssl rand -hex 32`).

## 5. Verificar

```bash
docker run --rm infra-toolchain riscv32-unknown-elf-gcc --version
docker run --rm infra-toolchain riscv32-unknown-elf-gcc -print-multi-lib
docker run --rm infra-toolchain spike --help
docker run --rm infra-toolchain ghdl --version
```

O segundo comando deve imprimir só `.;` (uma variante, a raiz).

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../LICENSE).
