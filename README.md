# Infra

Documentação dos requisitos e de como instalar/configurar a infraestrutura
da organização (workstations com hardware FPGA, runners self-hosted do
GitHub Actions, toolchains compartilhadas). Este README não descreve nada
sozinho: é só um índice, cada assunto tem seu próprio arquivo, e os
arquivos linkam entre si onde há dependência.

## Docs

- [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md): instalar o Quartus Prime Lite
  globalmente numa workstation (pré-requisito do runner).
- [RUNNER_SETUP.md](RUNNER_SETUP.md): configurar um runner self-hosted do
  GitHub Actions com acesso a hardware FPGA (Quartus + JTAG).
- [SPIKE_SETUP.md](SPIKE_SETUP.md): instalar `uv` globalmente e compilar o
  simulador de referência RISC-V no cache compartilhado da workstation.

## Ordem sugerida

Cada doc já linka seus próprios pré-requisitos, mas a ordem natural pra uma
workstation nova é:

1. [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md)
2. [RUNNER_SETUP.md](RUNNER_SETUP.md)
3. [SPIKE_SETUP.md](SPIKE_SETUP.md)

## Escopo

Sem o Quartus (`QUARTUS_INSTALL.md`), não tem como sintetizar nem programar
o hardware que o `RV32IM` implementa; sem o runner (`RUNNER_SETUP.md`), não
tem como rodar os testes de hardware real do `Testes`; sem o Spike
(`SPIKE_SETUP.md`), os testes de memória do `Testes` não têm golden de
referência. As três docs juntas são a base da qual `RV32IM`, `Testes` e
`Tools` dependem pra funcionar como pretendido.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](LICENSE).
