# Instalando o Quartus Prime Lite

O Quartus precisa estar instalado direto em `/opt`, como um programa global
(`/opt/altera_lite`, em vez do home de um usuário), para ficar acessível a
qualquer usuário/serviço da máquina sem precisar de grupo especial (por
exemplo, o runner self-hosted descrito em [RUNNER_SETUP.md](RUNNER_SETUP.md)).
Como o destino é `/opt`, que pertence ao `root`, a instalação precisa de
`sudo`.

## 1. Baixar o instalador oficial

Quartus Prime Lite Edition, versão 25.1:
[página de download](https://www.altera.com/downloads)

O nome do arquivo muda a cada build (ex: `qinst-lite-linux-25.1std-1129.run`).
Os comandos abaixo usam `qinst-lite-linux-*.run` para não depender do número
exato; confira o SHA1 publicado na página de download contra o arquivo
baixado antes de instalar.

## 2. Dar permissão de execução

```bash
chmod +x qinst-lite-linux-*.run
```

## 3. Instalar

**Modo GUI** (roda o instalador direto):
```bash
sudo ./qinst-lite-linux-*.run
```
Na tela de destino, apontar para `/opt/altera_lite`. Precisa de `sudo` porque
`/opt` é do `root`; sem `sudo`, o instalador não consegue criar o diretório
de destino.

**Modo CLI** (sem display, ex: máquina headless/SSH):
```bash
sudo ./qinst-lite-linux-*.run -- --target /opt/altera_lite
sudo /opt/altera_lite/qinst.sh --cli   # --help para ver as opções
```

## 4. Resultado esperado

Binários em `/opt/altera_lite/25.1std/quartus/bin/`, dono `root:root`,
permissão `755`/`555` (leitura+execução para todo mundo, escrita só para o
root).

## 5. PATH global

Adiciona os binários do Quartus (`quartus`, `quartus_pgm`, `jtagconfig`,
etc.) ao `PATH` global, criando um wrapper para cada um em
`/usr/local/bin`:

```bash
QUARTUS_ROOTDIR=/opt/altera_lite/25.1std/quartus
for f in "$QUARTUS_ROOTDIR"/bin/*; do
  name=$(basename "$f")
  sudo rm -f "/usr/local/bin/$name"
  sudo tee "/usr/local/bin/$name" >/dev/null <<EOF
#!/bin/sh
export QUARTUS_ROOTDIR_OVERRIDE=$QUARTUS_ROOTDIR
exec "$f" "\$@"
EOF
  sudo chmod 755 "/usr/local/bin/$name"
done
```

Verificar:
```bash
which quartus
bash -c 'quartus_pgm --version'
```

## 6. (Opcional) Atalho `.desktop` global

Para o Quartus aparecer no menu de aplicativos de qualquer usuário:

```bash
sudo tee /usr/share/applications/quartus-lite.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Quartus Prime Lite
Comment=Intel/Altera Quartus Prime Lite Edition
Exec=/opt/altera_lite/25.1std/quartus/bin/quartus
Icon=/opt/altera_lite/25.1std/quartus/adm/quartusii.png
Terminal=false
Categories=Development;Electronics;
StartupWMClass=quartus
EOF
sudo update-desktop-database /usr/share/applications
```

Precisa estar em `/usr/share/applications/`, não em
`~/.local/share/applications/` (que vale só para o usuário atual).
`desktop-file-validate` confere se o arquivo está sintaticamente correto:

```bash
desktop-file-validate /usr/share/applications/quartus-lite.desktop
```

## 7. Usar o Quartus a partir de um contêiner

As imagens de CI não trazem o Quartus. Elas têm a biblioteca de sistema de que as ferramentas de linha de comando dele dependem (`libglib2.0-0t64`), então a instalação do host pode ser montada num contêiner e executada lá.

O Quartus do host (aqui `/opt/altera_lite/25.1std`) é montado somente para leitura e colocado no `PATH` dentro do container. O USB-Blaster é alcançado pelo servidor JTAG (`jtagd`) do host, que o container enxerga ao compartilhar a rede do host:

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -e HOME=/tmp/h \
  -v "$PWD:/workspace" -v /opt/altera_lite:/opt/altera_lite:ro \
  ghcr.io/insper-riscv/ci-elf:latest bash -c '
    export PATH=/opt/altera_lite/25.1std/quartus/bin:$PATH
    jtagconfig
    cd platforms/sdram-bringup/quartus && quartus_sh --flow compile sdram_bringup'
```

| Opção | Para que serve |
| :--- | :--- |
| `-v /opt/altera_lite:/opt/altera_lite:ro` | a instalação do Quartus, somente leitura; a imagem não traz nenhuma |
| `--network host` | o `jtagd` escuta em `localhost:1309` do host, e o programador e o `quartus_stp` do container se conectam a ele ali |
| `--user "$(id -u):$(id -g)"` e `-e HOME=/tmp/h` | os arquivos que o build escreve pertencem ao usuário que chamou, e o Quartus tem um home gravável |

O `jtagd` precisa estar rodando no host, e ele pode parar sozinho entre dois usos. Rode o `jtagconfig` no host logo antes do container: ele inicia o `jtagd` se nenhum estiver rodando. Sem um `jtagd` no host, o container inicia um próprio, que não enxerga o USB, e o `jtagconfig` dentro do container imprime:

```text
1) USB-Blaster variant [3-5]
  Unable to lock chain - Bad port name
```

Com o `jtagd` do host rodando, o mesmo comando imprime o cabo e o chip (`USB-Blaster [3-5]`, `02B050DD 5CE(BA4|FA4)` na DE0-CV). Num daemon do Docker com remapeamento de usuários (user namespace), o `--network host` é recusado a menos que a execução também use `--userns=host`.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../LICENSE).
