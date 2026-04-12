# GitHub Settings — genesis-rs

Configuration de référence du repo [yoyonel/genesis-rs](https://github.com/yoyonel/genesis-rs).

---

## Labels

15 labels organisés par catégorisation sémantique.

### Labels génériques (conservés)

| Label | Couleur | Description |
|-------|---------|-------------|
| `bug` | ![#d73a4a](https://via.placeholder.com/12/d73a4a/d73a4a.png) `#d73a4a` | Something isn't working |
| `documentation` | ![#0075ca](https://via.placeholder.com/12/0075ca/0075ca.png) `#0075ca` | Improvements or additions to documentation |
| `enhancement` | ![#a2eeef](https://via.placeholder.com/12/a2eeef/a2eeef.png) `#a2eeef` | New feature or request |

### Labels `platform:*`

| Label | Couleur | Description |
|-------|---------|-------------|
| `platform:arch` | ![#1d76db](https://via.placeholder.com/12/1d76db/1d76db.png) `#1d76db` | Arch Linux (pacman) |
| `platform:debian` | ![#b60205](https://via.placeholder.com/12/b60205/b60205.png) `#b60205` | Debian/Ubuntu (apt) |
| `platform:raspbian` | ![#0e8a16](https://via.placeholder.com/12/0e8a16/0e8a16.png) `#0e8a16` | Raspbian ARM64 (apt + cross-emulation) |

### Labels `infra:*`

| Label | Couleur | Description |
|-------|---------|-------------|
| `infra:qemu` | ![#333333](https://via.placeholder.com/12/333333/333333.png) `#333333` | QEMU, KVM, TCG, virtualisation |
| `infra:ci` | ![#fbca04](https://via.placeholder.com/12/fbca04/fbca04.png) `#fbca04` | GitHub Actions, workflows CI/CD |
| `infra:cloud-init` | ![#795548](https://via.placeholder.com/12/795548/795548.png) `#795548` | Cloud-Init, provisioning VM |

### Labels `scope:*`

| Label | Couleur | Description |
|-------|---------|-------------|
| `scope:bootstrap` | ![#5319e7](https://via.placeholder.com/12/5319e7/5319e7.png) `#5319e7` | Bootstrapping, package install logic |
| `scope:executor` | ![#006b75](https://via.placeholder.com/12/006b75/006b75.png) `#006b75` | CommandExecutor trait, abstraction layer |
| `scope:benchmark` | ![#e36209](https://via.placeholder.com/12/e36209/e36209.png) `#e36209` | Performance, benchmarks, métriques |

### Labels transversaux

| Label | Couleur | Description |
|-------|---------|-------------|
| `quality` | ![#bfdadc](https://via.placeholder.com/12/bfdadc/bfdadc.png) `#bfdadc` | Lint, fmt, clippy, tests, hooks |
| `refactor` | ![#c5def5](https://via.placeholder.com/12/c5def5/c5def5.png) `#c5def5` | Restructuration, architecture |
| `security` | ![#d93f0b](https://via.placeholder.com/12/d93f0b/d93f0b.png) `#d93f0b` | Sécurité, GPG keys, SSH |

### Labels supprimés (defaults GitHub)

Les labels par défaut suivants ont été supprimés car non pertinents pour le projet :
`duplicate`, `good first issue`, `help wanted`, `invalid`, `question`, `wontfix`.

---

## Milestones

4 milestones correspondant aux phases du refactoring roadmap.

| # | Milestone | État | Description |
|---|-----------|------|-------------|
| 1 | **Phase 1 — Testability & CI** | ✅ Closed | CommandExecutor trait, unit tests, CLI tests, CI quality gate, dev environment setup. |
| 2 | **Phase 2 — DRY & Security** | 🔵 Open | Extract AptPlatform (Debian/Raspbian DRY), package name validation, QEMU image checksums, cargo audit in CI. |
| 3 | **Phase 3 — CI industrielle** | 🔵 Open | MSRV policy, Rust version matrix, release workflow (tags → GitHub binaries), PR checks. |
| 4 | **Phase 4 — Features** | 🔵 Open | Structured logging (tracing), dry-run mode, TOML config for packages, VM PID management. |

---

## Issues

### Phase 2 — DRY & Security

| # | Titre | Labels |
|---|-------|--------|
| [#2](https://github.com/yoyonel/genesis-rs/issues/2) | Extract AptPlatform shared between Debian and Raspbian | `platform:debian`, `platform:raspbian`, `scope:bootstrap`, `refactor` |
| [#3](https://github.com/yoyonel/genesis-rs/issues/3) | Validate/sanitize package names in install_package | `platform:arch`, `platform:debian`, `platform:raspbian`, `scope:bootstrap`, `security` |
| [#4](https://github.com/yoyonel/genesis-rs/issues/4) | Verify checksums of downloaded QEMU cloud images | `infra:qemu`, `infra:cloud-init`, `security` |

### Phase 3 — CI industrielle

| # | Titre | Labels |
|---|-------|--------|
| [#5](https://github.com/yoyonel/genesis-rs/issues/5) | Define MSRV policy and add Rust version matrix to CI | `infra:ci`, `quality` |
| [#6](https://github.com/yoyonel/genesis-rs/issues/6) | Add release workflow (tags → GitHub release binaries) | `enhancement`, `infra:ci` |
| [#7](https://github.com/yoyonel/genesis-rs/issues/7) | Enforce PR checks as required status checks on master | `infra:ci`, `quality` |

### Phase 4 — Features

| # | Titre | Labels |
|---|-------|--------|
| [#8](https://github.com/yoyonel/genesis-rs/issues/8) | Add structured logging with tracing | `enhancement`, `scope:bootstrap` |
| [#9](https://github.com/yoyonel/genesis-rs/issues/9) | Implement dry-run mode for bootstrap | `enhancement`, `scope:bootstrap`, `scope:executor` |
| [#10](https://github.com/yoyonel/genesis-rs/issues/10) | Add TOML configuration for package lists | `enhancement`, `scope:bootstrap` |
| [#11](https://github.com/yoyonel/genesis-rs/issues/11) | Replace killall with PID-based VM management | `enhancement`, `infra:qemu` |

---

## Project Board

| Champ | Valeur |
|-------|--------|
| **Nom** | genesis-rs Refactoring Roadmap |
| **Numéro** | #2 |
| **Type** | GitHub Projects v2 (user-scoped, linked au repo) |
| **URL** | https://github.com/users/yoyonel/projects/2 |

Le projet contient 11 items : PR #1 (merged) + issues #2–#11.

> **Note** : Les GitHub Projects v2 sont créés au niveau utilisateur/organisation,
> pas au niveau repo. Pour qu'un projet apparaisse dans l'onglet **Projects** d'un repo,
> il doit être explicitement lié via l'API GraphQL `linkProjectV2ToRepository`.

---

## Pull Requests

| # | Titre | État | Labels |
|---|-------|------|--------|
| [#1](https://github.com/yoyonel/genesis-rs/pull/1) | refactor: Phase 1 — Testability, DRY, CI quality gate, dev environment & E2E | ✅ Merged | `documentation`, `platform:arch`, `platform:debian`, `platform:raspbian`, `infra:qemu`, `infra:ci`, `scope:bootstrap`, `scope:executor`, `quality`, `refactor` |

---

## Reproduction

Commandes `gh` pour recréer cette configuration sur un repo vierge :

```bash
# --- Labels ---
# Supprimer les defaults inutiles
for label in "duplicate" "good first issue" "help wanted" "invalid" "question" "wontfix"; do
  gh label delete "$label" --yes
done

# Créer les labels projet
gh label create "platform:arch"      --color "1d76db" --description "Arch Linux (pacman)"
gh label create "platform:debian"    --color "b60205" --description "Debian/Ubuntu (apt)"
gh label create "platform:raspbian"  --color "0e8a16" --description "Raspbian ARM64 (apt + cross-emulation)"
gh label create "infra:qemu"         --color "333333" --description "QEMU, KVM, TCG, virtualisation"
gh label create "infra:ci"           --color "fbca04" --description "GitHub Actions, workflows CI/CD"
gh label create "infra:cloud-init"   --color "795548" --description "Cloud-Init, provisioning VM"
gh label create "scope:bootstrap"    --color "5319e7" --description "Bootstrapping, package install logic"
gh label create "scope:executor"     --color "006b75" --description "CommandExecutor trait, abstraction layer"
gh label create "scope:benchmark"    --color "e36209" --description "Performance, benchmarks, métriques"
gh label create "quality"            --color "bfdadc" --description "Lint, fmt, clippy, tests, hooks"
gh label create "refactor"           --color "c5def5" --description "Restructuration, architecture"
gh label create "security"           --color "d93f0b" --description "Sécurité, GPG keys, SSH"

# --- Milestones ---
gh api repos/:owner/:repo/milestones -f title="Phase 1 — Testability & CI" \
  -f description="CommandExecutor trait, unit tests, CLI tests, CI quality gate, dev environment setup."
gh api repos/:owner/:repo/milestones -f title="Phase 2 — DRY & Security" \
  -f description="Extract AptPlatform (Debian/Raspbian DRY), package name validation, QEMU image checksums, cargo audit in CI."
gh api repos/:owner/:repo/milestones -f title="Phase 3 — CI industrielle" \
  -f description="MSRV policy, Rust version matrix, release workflow (tags → GitHub binaries), PR checks."
gh api repos/:owner/:repo/milestones -f title="Phase 4 — Features" \
  -f description="Structured logging (tracing), dry-run mode, TOML config for packages, VM PID management."

# --- Project ---
gh project create --owner @me --title "genesis-rs Refactoring Roadmap"
# Puis lier au repo via GraphQL (voir note ci-dessus)
```

---

## Branch Protection

| Règle | Valeur |
|-------|--------|
| **Branch** | `master` |
| **Required status checks** | `Quality Gate (fmt, lint, test) (stable)`, `Quality Gate (fmt, lint, test) (1.85.0)`, `Security Audit`, `Build Multi-Arch binaries` |
| **Strict** | Oui (branch must be up-to-date before merge) |
| **Enforce admins** | Non |
| **Required reviews** | Non |
| **Force push** | Interdit |
| **Delete branch** | Interdit |

```bash
# Reproduction
gh api repos/:owner/:repo/branches/master/protection -X PUT \
  -H "Accept: application/vnd.github+json" \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Quality Gate (fmt, lint, test) (stable)",
      "Quality Gate (fmt, lint, test) (1.85.0)",
      "Security Audit",
      "Build Multi-Arch binaries"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null
}
EOF
```
