# base-boolector

`ghcr.io/<organização>/base-boolector` contém o Boolector, em `/opt/boolector`: o solver SMT para vetores de bits e arrays que o `sby` roda como `smtbmc boolector`, com o `btormc`, o verificador de modelos do engine `btor`. A visão geral das imagens está em [README.md](README.md).

## 1. O que contém

| Item | Detalhe |
| :--- | :--- |
| Boolector | construído a partir do código-fonte, com o SAT solver CaDiCaL; só os executáveis, sem cabeçalhos nem bibliotecas |
| `boolector` e `btormc` | o solver e o verificador de modelos, ambos estáticos |
| `btorsim` | o simulador de BTOR2 que o `sby` chama para reproduzir um contraexemplo do engine `btor` |
| `/opt/boolector/.tag` | duas linhas. A primeira é o commit de que a instalação foi construída, e a segunda é a versão da release cuja tag aponta para ele a data do commit e o commit curto (`3.2.4 2024-08-23 (393cdfb)`) |

O Boolector é construído aqui porque o pacote do Ubuntu é o Boolector 1.5, que não roda no modo SMT-LIB incremental (`--smt2 -i`) que o `yosys-smtbmc` usa. O `btorsim` liga dinamicamente com a `libstdc++` e a `libgcc_s` do sistema, então quem copia o diretório as instala.

## 2. Publicação

| Item | Valor |
| :--- | :--- |
| Receita | `docker/base/boolector/Dockerfile` |
| Workflow | `Boolector image` |
| Tags | `<commit>` e `latest` |
| Rótulo | `boolector.commit` |
| Agenda | todo dia, 03:00 UTC |

O workflow segue a série 3 (`SERIES`) e usa a tag `3.N.P` mais recente. O build só termina se o `boolector` resolver uma consulta pequena sobre vetores de bits no modo incremental.

## 3. Execução manual

| Campo | Significado |
| :--- | :--- |
| `confirm` | o valor do secret `IMAGE_PUBLISH_SECRET` |
| `commit` | o commit do Boolector; vazio, o da tag mais recente da série |
| `force` | reconstrói e republica mesmo que a imagem desse commit já exista |

## 4. Construindo localmente

```bash
docker build -f docker/base/boolector/Dockerfile -t base-boolector \
  --build-arg BOOLECTOR_COMMIT="$(git ls-remote https://github.com/Boolector/boolector 'refs/tags/3.2.4^{}' 'refs/tags/3.2.4' | tail -n 1 | cut -f1)" .
```

| Argumento | Padrão | Significado |
| :--- | :--- | :--- |
| `BASE_IMAGE` | `ubuntu:26.04` | imagem base (multi-arquitetura) |
| `BOOLECTOR_COMMIT` | nenhum | o commit do Boolector a construir |

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
