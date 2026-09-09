# Infra

Documentação dos requisitos e de como instalar/configurar a infraestrutura
da organização (workstations com hardware FPGA, runners self-hosted do
GitHub Actions, toolchains compartilhadas). Este README não descreve nada
sozinho — é só um índice: cada assunto tem seu próprio arquivo, e os
arquivos linkam entre si onde há dependência.

## Docs

- [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md) — instalar o Quartus Prime Lite
  globalmente numa workstation (pré-requisito do runner).
- [RUNNER_SETUP.md](RUNNER_SETUP.md) — configurar um runner self-hosted do
  GitHub Actions com acesso a hardware FPGA (Quartus + JTAG).
- [SPIKE_SETUP.md](SPIKE_SETUP.md) — instalar `uv` globalmente e compilar o
  Spike (`golden_generator`) no cache compartilhado da workstation.

## Ordem sugerida

Cada doc já linka seus próprios pré-requisitos, mas a ordem natural pra uma
workstation nova é:

1. [QUARTUS_INSTALL.md](QUARTUS_INSTALL.md)
2. [RUNNER_SETUP.md](RUNNER_SETUP.md)
3. [SPIKE_SETUP.md](SPIKE_SETUP.md)

## Escopo

Documentação genérica, reutilizável por qualquer projeto/repo da
organização que precise dessa infra — não é log de status de uma máquina
específica nem específica de um repositório consumidor. Onde um doc cita um
projeto real como exemplo (ex: `insper-riscv/Testes`), é só ilustração de
como um consumidor usa a infra — não faz esse doc pertencer àquele repo.
