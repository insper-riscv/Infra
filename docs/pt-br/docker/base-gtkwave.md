# base-gtkwave

`ghcr.io/<organização>/base-gtkwave` contém o GTKWave, o visualizador de formas de onda, em `/opt/gtkwave`. A [`dev_tools`](dev-tools.md) copia esse diretório. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| GTKWave | a ponta da branch `lts` (linha de manutenção 3.3, árvore GTK 3), que roda nativamente no Wayland e no X11 |

O GTKWave liga com o GTK 3, e a `dev_tools` instala as bibliotecas necessárias.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/gtkwave/Dockerfile` |
| Workflow | `GTKWave image` |
| Tags | `<commit>` e `latest` |
| Rótulo | `gtkwave.commit` |
| Agenda | todo dia, 03:00 UTC |

O workflow segue a branch `lts` (`BRANCH`) e constrói só se o commit da ponta ainda não tem imagem.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit a construir; vazio, a ponta da branch `lts` |
| `force` | reconstrói e republica mesmo que a imagem desse commit já exista |

## 4. Construindo localmente

```bash
docker build -f docker/base/gtkwave/Dockerfile -t base-gtkwave \
  --build-arg GTKWAVE_COMMIT="$(git ls-remote https://github.com/gtkwave/gtkwave refs/heads/lts | cut -f1)" .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `GTKWAVE_COMMIT` | nenhum | o commit do GTKWave a construir |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
