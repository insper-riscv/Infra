# base-bitwuzla

`ghcr.io/<organização>/base-bitwuzla` contém o Bitwuzla, em `/opt/bitwuzla`: o solver SMT para vetores de bits e arrays que o `sby` roda como `smtbmc bitwuzla`. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| Bitwuzla | construído a partir do código-fonte; só o executável `bitwuzla`, sem cabeçalhos nem bibliotecas |
| `/opt/bitwuzla/.tag` | o commit de que a instalação foi construída |

O executável é estático, então quem copia o diretório não instala nenhuma biblioteca.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/bitwuzla/Dockerfile` |
| Workflow | `Bitwuzla image` |
| Tags | `<commit>` e `latest` |
| Rótulo | `bitwuzla.commit` |
| Agenda | todo dia, 03:00 UTC |

O workflow segue a série 0 (`SERIES`) e usa a tag `0.N.P` mais recente. O build só termina se o executável resolver uma consulta pequena sobre vetores de bits.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit do Bitwuzla; vazio, o da tag mais recente da série |
| `force` | reconstrói e republica mesmo que a imagem desse commit já exista |

## 4. Construindo localmente

```bash
docker build -f docker/base/bitwuzla/Dockerfile -t base-bitwuzla \
  --build-arg BITWUZLA_COMMIT="$(git ls-remote https://github.com/bitwuzla/bitwuzla 'refs/tags/0.9.1^{}' 'refs/tags/0.9.1' | tail -n 1 | cut -f1)" .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `BITWUZLA_COMMIT` | nenhum | o commit do Bitwuzla a construir |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
