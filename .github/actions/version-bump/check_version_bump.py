"""Exige o bump de versao de um pull request que muda o repositorio.

Compara o checkout atual (HEAD, o merge do PR) com a ponta da base. O PR
passa quando:

1. todo caminho alterado e ponteiro de submodulo (modo 160000) ou casa com um
   dos globs isentos (documentacao, licenca, CI); ou
2. a versao de ``pyproject.toml`` e maior que a da base e a entrada do proprio
   projeto em ``uv.lock`` traz essa mesma versao.

Repositorio sem ``pyproject.toml`` na base nao tem versao a exigir.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tomllib
from typing import Optional

GITLINK = "160000"
VERSION = re.compile(r"^(\d+)\.(\d+)\.(\d+)")


def git(*args: str) -> bytes:
    """Roda o git e devolve a saida; um erro encerra com mensagem."""
    done = subprocess.run(["git", *args], capture_output=True, check=False)
    if done.returncode != 0:
        sys.exit(f"::error::git {' '.join(args)}: {done.stderr.decode().strip()}")
    return done.stdout


def glob_regex(pattern: str) -> re.Pattern[str]:
    """Traduz um glob com ``**`` (qualquer profundidade) e ``*`` (um nivel)."""
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pattern.startswith("**", i):
            out += ".*"
            i += 2
        elif pattern[i] == "*":
            out += "[^/]*"
            i += 1
        else:
            out += re.escape(pattern[i])
            i += 1
    return re.compile(out + r"\Z")


def changed(base: str) -> list[tuple[str, bool]]:
    """Caminhos que o HEAD muda em relacao a base, com a marca de ponteiro."""
    raw = git("diff", "--raw", "-z", "--no-renames", base, "HEAD").split(b"\0")
    paths = []
    i = 0
    while i + 1 < len(raw) and raw[i]:
        meta = raw[i].decode().lstrip(":").split()
        paths.append((raw[i + 1].decode(), GITLINK in (meta[0], meta[1])))
        i += 2
    return paths


def version_of(text: str) -> tuple[str, str]:
    """Nome e versao do projeto em um pyproject.toml."""
    project = tomllib.loads(text)["project"]
    return project["name"], project["version"]


def show(ref: str, path: str) -> Optional[str]:
    """Conteudo de um arquivo em um commit, ou None se nao existir."""
    done = subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True, check=False)
    return done.stdout.decode() if done.returncode == 0 else None


def triple(version: str) -> tuple[int, int, int]:
    """Os tres numeros da versao x.y.z."""
    found = VERSION.match(version)
    if not found:
        sys.exit(f"::error::The version '{version}' is not x.y.z.")
    return tuple(int(n) for n in found.groups())  # type: ignore[return-value]


def lock_version(lock: str, name: str) -> Optional[str]:
    """Versao do proprio projeto dentro do uv.lock."""
    norm = re.sub(r"[-_.]+", "-", name).lower()
    for package in tomllib.loads(lock).get("package", []):
        if re.sub(r"[-_.]+", "-", package["name"]).lower() == norm:
            return package.get("version")
    return None


def main() -> int:
    """Aplica a regra e devolve o codigo de saida."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--exempt", default="")
    args = parser.parse_args()

    base_toml = show(args.base, "pyproject.toml")
    if base_toml is None:
        print("::notice::The base has no pyproject.toml: no version to require.")
        return 0

    exempt = [glob_regex(p.strip()) for p in args.exempt.splitlines() if p.strip()]
    required = [
        path for path, pointer in changed(args.base)
        if not pointer and not any(rx.match(path) for rx in exempt)
    ]
    if not required:
        print("::notice::Only submodule pointers and exempt paths changed: no bump required.")
        return 0

    head_toml = show("HEAD", "pyproject.toml")
    if head_toml is None:
        sys.exit("::error::pyproject.toml was removed.")
    name, new = version_of(head_toml)
    old = version_of(base_toml)[1]
    errors = []
    if triple(new) <= triple(old):
        errors.append(
            f"pyproject.toml version {new} is not greater than {old} of {args.base}. "
            "Run `uv version --bump patch` (or minor/major)."
        )
    lock = show("HEAD", "uv.lock")
    if lock is None:
        errors.append("uv.lock is missing.")
    elif lock_version(lock, name) != new:
        errors.append(
            f"uv.lock holds {lock_version(lock, name)} for {name}, not {new}. Run `uv lock`."
        )
    if errors:
        print(f"{len(required)} changed path(s) ask for a bump, for example {required[0]}.")
        for error in errors:
            print(f"::error::{error}")
        return 1
    print(f"Version {old} -> {new} in pyproject.toml and uv.lock.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
