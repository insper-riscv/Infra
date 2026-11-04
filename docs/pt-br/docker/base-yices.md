# base-yices

`ghcr.io/<organização>/base-yices` contém o Yices 2, em `/opt/yices`: o solver SMT que o `sby` roda como `smtbmc yices`. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| Yices 2 | construído a partir do código-fonte; só os executáveis (`yices-smt2`, `yices`, `yices-sat` e `yices-smt`), sem cabeçalhos nem bibliotecas |
| `/opt/yices/.tag` | duas linhas. A primeira é o commit de que a instalação foi construída, e a segunda é a versão da release cuja tag aponta para ele e o commit curto (`2.6.5 (...)`) |

O `yices-smt2` liga dinamicamente com a `libgmp` e a `libc` do sistema, então quem copia o diretório instala a `libgmp10`.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/yices/Dockerfile` |
| Workflow | `Yices image` |
| Tags | `<commit>` e `latest` |
| Rótulo | `yices.commit` |
| Agenda | todo dia, 03:00 UTC |

O workflow segue a série 2 (`SERIES`) e usa a tag `Yices-2.N.P` mais recente. O build só termina se o executável resolver uma consulta pequena sobre vetores de bits.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit do Yices; vazio, o da tag mais recente da série |
| `force` | reconstrói e republica mesmo que a imagem desse commit já exista |

## 4. Construindo localmente

```bash
docker build -f docker/base/yices/Dockerfile -t base-yices \
  --build-arg YICES_COMMIT="$(git ls-remote https://github.com/SRI-CSL/yices2 'refs/tags/Yices-2.6.5^{}' 'refs/tags/Yices-2.6.5' | tail -n 1 | cut -f1)" .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `YICES_COMMIT` | nenhum | o commit do Yices a construir |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
