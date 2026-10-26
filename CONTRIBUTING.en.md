# Contribution Guide

🌐 [Português](CONTRIBUTING.md) · [English](CONTRIBUTING.en.md)

This document defines the mandatory coding, structural organization, documentation, and verification rules for any contribution to the `Infra` repository.

## 1. Container Standards

| Rule | Specification |
| :--- | :--- |
| Recipes | One image per tool, each in its own `Dockerfile.<tool>` |
| Build | Multi-stage, discarding compilers and sources from the final image |
| User | Unprivileged (non-root) final process with fixed UID/GID |
| Versions | Pinned tool and base image versions; no floating tag such as `latest` in recipes |
| Secrets | Never in image layers or in `ARG`/`ENV`; use build secrets |
| Comments | In **Portuguese**, describing what each step produces |

## 2. Markdown Documentation Rules

Every `README`, `CONTRIBUTING`, and `AUTHORS` maintains mirrored versions in Portuguese (`*.md`) and English (`*.en.md`), following these rules:

1. **Language switcher and license footer:** every `README.md` and `README.en.md` includes the `🌐 [Português](...) · [English](...)` switcher at the top, and every `.md` file ends with the copyright footer linking to `LICENSE`.
2. **Numbered progressive sections:** all sections starting at `##` must be numbered (`## 1.`, `### 1.1.`, `## 2.`) in a logical reading order.
3. **Direct punctuation:**
   - **Em-dashes are prohibited** in prose and tables; use commas, parentheses, semicolons, or colons according to the actual syntactic relationship.
   - **Chained colons are prohibited** (more than one `:` in the same sentence or table cell).
4. **Behavior explanation:** never cite an internal file, module, or signal name as if the name itself explained what the system does; always describe the operation performed.
5. **Non-redundant tables and LaTeX:** structured data belongs in Markdown tables and mathematical/boolean equations in LaTeX blocks (`$$ ... $$` or `$ ... $`), without repeating in prose what the table or equation already states.
6. **No changelog or open TODOs in technical docs:** architecture and contract documents describe exclusively the current state, without historical bugfix notes or unimplemented work lists.
7. **Usage guides only instruct:** installation and run instructions say how to do it, without justifying the choice of method.

## 3. Mandatory Verification Before Opening a Pull Request

Any change to code, configuration, or documentation must pass all commands below without errors before submission:

```bash
docker build -f Dockerfile.<recipe> -t <recipe> .  # Builds the image of the changed recipe
```

When adding, renaming, or removing any versioned file, immediately update:
- `.github/workflows/`
- `docs/`
- `README.md`, `README.en.md`, and the affected documentation

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](LICENSE).
