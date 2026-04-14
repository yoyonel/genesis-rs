# Audit Complet de genesis-rs — Phase 3

> **Date** : 2026-04-14 (Post Phase 4 + Phase 5 partielle)
> **Contexte** : Ré-audit complet après Phases 4 et 5. Toutes les features planifiées sont livrées. Phase 5 (Quality & CI Hardening) quasi complète.

---

## Vue d'ensemble

| Métrique | Phase 1 audit | Phase 2 audit | **Maintenant** |
|---|---|---|---|
| Fichiers source Rust | 8 | 6 | **7** (+config.rs) |
| LOC (src/) | ~770 | 651 | **931** (+43% — config, tracing, dry-run) |
| Tests unitaires | 4 | 19 | **30** (+58%) |
| Tests intégration CLI | 0 | 5 | **6** |
| Doctests | 1 | 1 | **1** |
| **Total tests** | **5** | **25** | **37** (×7.4 vs baseline) |
| Couverture de code | Non mesurée | Non mesurée | **45.73%** (75/164 lignes) |
| Scripts shell | 1 | 10 | **13** |
| Shell LOC (scripts/) | ~50 | 710 | **954** |
| CI workflows | 1 | 3 | **3** |
| CI jobs | 2 | 7 | **8** (+coverage) |
| Justfile recipes | ~20 | ~30 | **43** |
| Documentation (docs/) | 1 | 4 | **5** (+audit-phase3) |
| GitHub issues | 0 | 10 | **20** (19 fermées, 1 ouverte) |
| Milestones | 0 | 4 | **5** (4 fermées, 1 en cours) |
| PRs merged | 0 | 5 | **19** |

---

## 1. Architecture — Note : A+ (était A)

### Points forts
- **`SystemPlatform` trait** : abstraction solide, dispatch par `os_info::Type`.
- **`AptPlatform` struct partagée** : Debian et Raspbian partagent 100% de l'impl. Zéro duplication.
- **`CommandExecutor` trait** : injection de dépendance propre. `RealExecutor`, `DryRunExecutor`, `MockExecutor`.
- **`Config` struct** avec chargement TOML : listes de paquets configurables par plateforme, remplace le hardcoded `ESSENTIAL_PACKAGES`.
- **`DryRunExecutor`** : mode dry-run complet qui affiche les commandes sans les exécuter.
- **Structured logging** via `tracing` : subscriber configurable, output stderr, contrôlé par `RUST_LOG`.
- **`validate_package_name()`** : regex whitelist `[a-zA-Z0-9][a-zA-Z0-9.+\-]+` — prévient l'injection de commandes via noms de paquets.

### Évolution depuis Phase 2
| Aspect | Phase 2 | Maintenant | Δ |
|---|---|---|---|
| Config paquets | Hardcoded `ESSENTIAL_PACKAGES` | TOML configurable | ✅ (issue #10) |
| Logging | `println!` partout | `tracing` structuré | ✅ (issue #8) |
| Dry-run | Aucun | `DryRunExecutor` complet | ✅ (issue #9) |
| Validation paquets | Aucune | `validate_package_name()` regex | ✅ (issue #3) |

---

## 2. Qualité de Code — Note : A (était A-)

### Points forts
- **Clippy zéro warning** (`-D warnings`) sur stable ET MSRV 1.85.0.
- **rustfmt** vérifié en CI.
- **37 tests** passent (30 unit + 6 CLI + 1 doctest) — ×7.4 vs baseline.
- **Couverture mesurée** : 45.73% (cargo-tarpaulin en CI, rapport HTML en artifact).
- **shellcheck** intégré dans `just lint` — 0 finding sur les 13 scripts.
- **Pre-commit hooks** : format + lint avant chaque commit.
- **Edition 2024**, MSRV 1.85.0 vérifié en matrice CI.
- **anyhow** pour la propagation d'erreur — aucun `unwrap()` dans le code library.

### Couverture par fichier
| Fichier | Couverture | Détail |
|---|---|---|
| `config.rs` | **100%** (12/12) | Parsing TOML, defaults |
| `platform/arch.rs` | **100%** (23/23) | Pacman, mock-based |
| `platform/mod.rs` | **57%** (40/70) | AptPlatform testé, `print_summary()` et `get_platform()` non couverts |
| `executor.rs` | **0%** (0/21) | `RealExecutor` — couvert par E2E uniquement |
| `lib.rs` | **0%** (0/29) | `run_bootstrap()`/`run_detect()` — fonctions d'orchestration |
| `main.rs` | **0%** (0/9) | Point d'entrée — couvert par E2E uniquement |

### Points faibles restants
- **45.73% de couverture** : `executor.rs`, `lib.rs`, `main.rs` à 0% (fonctions d'orchestration et exécution réelle, couvertes uniquement par E2E).
- **`print_summary()` non testé** : implémentation par défaut du trait avec I/O sysinfo.

### Évolution
| Métrique | Phase 2 | Maintenant | Δ |
|---|---|---|---|
| Tests | 25 | 37 | +48% ✅ |
| Couverture | Non mesurée | 45.73% | Baseline établie ✅ |
| shellcheck | Non | Intégré dans `just lint` | ✅ |

---

## 3. Sécurité — Note : B- (était C+)

| Sévérité | Problème | Statut |
|---|---|---|
| ~~**HAUTE**~~ | ~~`install_package(name)` sans validation~~ | ✅ **Résolu** — `validate_package_name()` regex whitelist |
| **HAUTE** | Cloud-Init `user-data` : mot de passe trivial en clair | ⚠️ **Acceptable** (E2E uniquement, jamais en production) |
| **MOYENNE** | SSH `StrictHostKeyChecking=no` dans scripts | ⚠️ **Acceptable** (E2E local uniquement) |
| ~~**MOYENNE**~~ | ~~`sed -i` injection SSH — risque de corruption~~ | ✅ **Résolu** (injection idempotente) |
| ~~**BASSE**~~ | ~~Pas de checksum images QEMU~~ | ✅ **Résolu** — SHA256 vérification en CI |
| ~~**BASSE**~~ | ~~`sudo` sans audit trail~~ | ✅ **Résolu** — `tracing` log toutes les commandes |
| ✅ | `cargo audit` en CI (job dédié + cache) | ✅ |
| ✅ | Branch protection avec required status checks | ✅ |
| ✅ | Actions Node.js 24 (plus de deprecation warnings) | ✅ |

### Analyse
Progression majeure : la vulnérabilité **HAUTE** (injection de noms de paquets) est résolue par `validate_package_name()`. Les checksums QEMU et le logging structuré comblent les deux failles **BASSE**. Les seuls problèmes restants sont limités au contexte E2E (mot de passe cloud-init, SSH sans vérification) et ne sont pas pertinents en production.

---

## 4. Scripts & Justfile — Note : A (était A-)

### Points forts
- **13 scripts** dans `scripts/` — chacun avec responsabilité unique.
- **Justfile** (212 lignes, 43 recettes) : table des matières organisée, délègue aux scripts.
- **shellcheck zéro finding** — intégré dans `just lint`.
- **PID management** : gestion propre des processus QEMU (remplace `killall`).
- **`scripts/benchmark.sh`** : benchmarks reproductibles avec métriques structurées.

### Évolution
| Métrique | Phase 2 | Maintenant | Δ |
|---|---|---|---|
| Scripts | 10 | 13 | +30% ✅ |
| Shell LOC | 710 | 954 | +34% |
| shellcheck | Non intégré | 0 findings, dans `just lint` | ✅ |
| PID management | `killall` | Fichiers PID dédiés | ✅ (issue #11) |

---

## 5. CI/CD — Note : A+ (était A)

### Pipeline (8 jobs)

```
quality (stable)  ─┐
quality (MSRV)    ─┤──→ build (x86_64+aarch64) ──→ e2e ×3 (debian, arch, raspbian)
security          ─┘
coverage          ─── (parallèle, indépendant)
```

### Points forts
- **8 jobs** : quality ×2, security, coverage, build, e2e ×3.
- **Coverage CI** : cargo-tarpaulin avec cache binaire, rapport HTML en artifact.
- **`timeout-minutes: 10`** sur tous les jobs — plus de jobs zombies.
- **Cache intelligent** : cargo registry, cargo-audit, cargo-tarpaulin, APT packages, QEMU images.
- **shellcheck** + **actionlint** + **check-actions** dans le quality gate.
- **Actions Node.js 24** : checkout@v6, cache@v5, upload-artifact@v7, download-artifact@v8, setup-just@v4.
- **KVM activé** sur runners CI pour les E2E.
- **fail-fast: false** sur E2E — toutes les distros testées même si une échoue.
- **Per-OS QEMU packages** : seuls les paquets nécessaires par plateforme (arch/debian: qemu-system-x86, raspbian: qemu-system-arm).

### Timings (avec cache)
| Job | Durée |
|---|---|
| Quality (stable) | ~20s |
| Quality (MSRV) | ~22s |
| Security Audit | ~8s |
| Coverage | ~23s |
| Build Multi-Arch | ~3-4min |
| E2E (debian/arch) | ~2-3min |
| E2E (raspbian) | ~4-5min |
| **Total wall-clock** | **~8min** |

### Évolution
| Métrique | Phase 2 | Maintenant | Δ |
|---|---|---|---|
| CI jobs | 7 | 8 (+coverage) | ✅ |
| Coverage en CI | Non | cargo-tarpaulin + artifact | ✅ |
| Timeouts | Aucun | 10min sur tous les jobs | ✅ |
| APT cache | Non | Cache par job | ✅ |
| QEMU packages | Tous pour chaque OS | Per-OS split | ✅ |
| Actions Node.js | 16 (deprecation) | 24 | ✅ |

---

## 6. Tests — Note : A- (était B+)

### État actuel

| Type | Quantité | Détail |
|---|---|---|
| Unit tests (platform/mod.rs) | 16 | detect ×4, AptPlatform ×7, config ×5 |
| Unit tests (platform/arch.rs) | 8 | display_name, update, install, bootstrap, failures ×4 |
| Unit tests (config.rs) | 6 | parse, defaults, platform-specific |
| Intégration CLI (tests/cli.rs) | 6 | --help, --version, no args, invalid subcmd, detect, bootstrap --dry-run |
| Doctests | 1 | lib.rs exemple |
| **Total** | **37** | **45.73% couverture** |

### Ce qui EST testé
- ✅ Détection d'OS (4 variantes)
- ✅ `update_system()`, `install_package()`, `bootstrap()` — mock-based
- ✅ Propagation d'erreurs (update failure, install failure, bootstrap stops)
- ✅ `validate_package_name()` — regex whitelist
- ✅ Config TOML parsing et defaults
- ✅ CLI parsing (help, version, detect, bootstrap dry-run)
- ✅ `test_install_failure_propagates` (arch.rs) — corrigé, utilise `-S` correctement

### Ce qui N'est PAS testé (unitairement)
- ❌ `print_summary()` — implémentation par défaut du trait, I/O sysinfo
- ❌ `run_bootstrap()`/`run_detect()` dans lib.rs — orchestration, couvert par E2E
- ❌ `RealExecutor` — exécution système, couvert par E2E
- ❌ `main.rs` — point d'entrée, couvert par E2E

### Évolution
| Métrique | Phase 2 | Maintenant | Δ |
|---|---|---|---|
| Total tests | 25 | 37 | +48% ✅ |
| Faux positif arch.rs | Oui | Corrigé | ✅ |
| Couverture mesurée | Non | 45.73% en CI | ✅ |

---

## 7. Documentation — Note : A- (inchangé)

### Inventaire

| Document | Contenu |
|---|---|
| `README.md` | Vue d'ensemble, architecture, quick start |
| `VM_SETUP.md` | Guide setup VMs QEMU |
| `docs/vm-virtualization.md` | KVM vs TCG, benchmarks, troubleshooting |
| `docs/audit-phase1.md` | Audit baseline initial |
| `docs/audit-phase2.md` | Audit post Phase 2/3 |
| `docs/audit-phase3.md` | **Ce document** — audit post Phase 4/5 |
| `docs/github-settings.md` | Labels, milestones, project board |
| `docs/benchmarks/initial_reference.md` | Benchmarks de référence |
| `.github/copilot-instructions.md` | Guidelines projet |
| `.github/instructions/*.md` (×3) | Commit workflow, GitHub project, testing quality |

---

## 8. Synthèse & Comparaison

### Tableau récapitulatif des notes

| Domaine | Phase 1 | Phase 2 | **Phase 3** | Δ total |
|---|---|---|---|---|
| **Architecture** | A- | A | **A+** | ↑↑ |
| **Qualité de Code** | B+ | A- | **A** | ↑↑ |
| **Sécurité** | C | C+ | **B-** | ↑↑ |
| **Scripts & Justfile** | B- | A- | **A** | ↑↑↑ |
| **CI/CD** | A- | A | **A+** | ↑↑ |
| **Tests** | D | B+ | **A-** | ↑↑↑↑ |
| **Documentation** | — | A- | **A-** | = |
| **Note globale** | **B** | **A-** | **A** | ↑↑↑ |

### Progression par milestone

| Milestone | Statut | Issues |
|---|---|---|
| Phase 1 — Testability & CI | ✅ Fermé | 1/1 |
| Phase 2 — DRY & Security | ✅ Fermé | 7/7 |
| Phase 3 — CI industrielle | ✅ Fermé | 4/4 |
| Phase 4 — Features | ✅ Fermé | 8/8 |
| Phase 5 — Quality & CI Hardening | 🔄 En cours | 7/8 (reste : ce rapport) |

### Top 5 des améliorations Phase 4/5

1. **Config TOML** (`genesis.toml`) : listes de paquets par plateforme, fini le hardcoded.
2. **Structured logging** (`tracing`) : observabilité complète, contrôlé par `RUST_LOG`.
3. **Coverage CI** (cargo-tarpaulin) : baseline 45.73%, mesurée à chaque PR.
4. **shellcheck CI** : 13 scripts shell validés automatiquement.
5. **Actions Node.js 24** : plus aucun deprecation warning, pipeline futur-proof.

---

## 9. Roadmap — Prochaines étapes

### Qualité (couverture)
- Augmenter la couverture au-delà de 60% : tester `run_bootstrap()`/`run_detect()` avec mock platform injection.
- Mutation testing (`cargo-mutants`) pour valider la robustesse des tests.

### Sécurité
- Cloud-Init : utiliser `ssh_authorized_keys` seul (supprimer `chpasswd`).
- Documenter les implications sécurité du mode E2E dans `VM_SETUP.md`.

### Features
- Support de nouvelles distributions (Fedora, NixOS).
- Mode interactif (confirmation avant chaque étape).
- Reporting post-bootstrap (résumé des actions effectuées).

### Infrastructure
- SBOM generation (`cargo-cyclonedx`).
- Dependabot pour les dépendances Rust et Actions.
- `CONTRIBUTING.md` et `CHANGELOG.md`.
