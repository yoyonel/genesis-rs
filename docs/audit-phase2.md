# Audit Complet de genesis-rs — Phase 2

> **Date** : 2025-07-14 (Post Phase 1 + Phase 2 partielle + Phase 3)
> **Contexte** : Ré-audit complet après 5 PRs de refactoring (#1, #12, #13, #14, #15). Comparaison avec le baseline `audit-phase1.md`.

---

## Vue d'ensemble

| Métrique | Avant (Phase 1 audit) | Maintenant |
|---|---|---|
| Fichiers source Rust | 8 (dont debian.rs, raspbian.rs) | **6** (-2 fichiers, AptPlatform consolidation) |
| LOC (src/) | ~770 | **651** (-15%) |
| Tests unitaires | 4 (détection seule) | **19** (détection + mock-based) |
| Tests intégration CLI | 0 | **5** (assert_cmd) |
| Doctests | 1 | **1** |
| **Total tests** | **5** | **25** (×5) |
| Scripts shell | 1 (setup-build-env.sh) | **10** |
| Shell LOC (scripts/) | ~50 | **710** |
| CI workflows | 1 (ci.yml partiel) | **3** (ci.yml, release.yml, docs.yml) |
| CI jobs | 2 | **7** (quality ×2, security, build, e2e ×3) |
| Documentation | README + VM_SETUP | **4 docs** + **3 instructions Copilot** |
| GitHub issues | 0 | **10** (4 fermées, 6 ouvertes) |
| Milestones | 0 | **4** (2 fermées, 2 ouvertes) |

---

## 1. Architecture — Note : A (était A-)

### Points forts
- **`SystemPlatform` trait** : abstraction solide et extensible. Le dispatch par `os_info::Type` dans `detect_from_info()` est propre et testable.
- **`AptPlatform` struct partagée** : Debian et Raspbian partagent 100% de leur implémentation. Seul le `name` diffère. Zéro duplication apt. (PR #14 : -121 LOC net)
- **`CommandExecutor` trait** : injection de dépendance propre. `RealExecutor` pour la production, `MockExecutor` avec `set_fail_on()` et `as_any()` pour les tests.
- **Séparation claire** : `lib.rs` (API publique), `main.rs` (entrée), `cli.rs` (clap derive), `executor.rs` (abstraction commandes), `platform/` (implémentations distro).
- **`ESSENTIAL_PACKAGES`** centralisé comme constante dans `mod.rs`.
- **Architecture testable** : chaque composant est injectable/mockable. Les tests unitaires n'exécutent aucune commande système.

### Points faibles (restants)
- `bootstrap()` hardcode la liste de paquets via `ESSENTIAL_PACKAGES`. Devrait être configurable (→ issue #10 TOML config).
- Pas de logging structuré : tout passe par `println!` (→ issue #8 tracing).
- Pas de dry-run (→ issue #9).
- `print_summary()` a une implémentation par défaut dans le trait qui fait des I/O via sysinfo. Non testable unitairement en l'état.

### Évolution depuis l'audit initial
| Aspect | Avant | Après | Δ |
|---|---|---|---|
| Duplication apt | 95% entre debian.rs et raspbian.rs | 0% — AptPlatform | ✅ |
| Fichiers source | 8 | 6 (-2) | ✅ |
| LOC | ~770 | 651 (-15%) | ✅ |
| Testabilité | Command directe, pas mockable | CommandExecutor injectable | ✅ |
| Extensibilité | Copier un fichier pour chaque distro | Paramétrer AptPlatform | ✅ |

---

## 2. Qualité de Code — Note : A- (était B+)

### Points forts
- **Clippy zéro warning** (`-D warnings`) en CI sur stable ET MSRV 1.85.0.
- **rustfmt** vérifié en CI (`cargo fmt --check`).
- **25 tests** passent (19 unit + 5 intégration + 1 doctest) — ×5 vs baseline.
- **Tests mockés complets** : chaque plateforme teste `display_name`, `update_system`, `install_package`, `bootstrap`, et la propagation d'erreurs (failure stops execution, error bubbles up).
- **anyhow** pour toute la propagation d'erreur — aucun `unwrap()` dans le code library.
- **MSRV 1.85.0** défini dans `Cargo.toml` et vérifié en CI (matrice Rust).
- **Edition 2024** : utilise les conventions Rust les plus récentes.
- **Pre-commit hook** disponible via `just install-hooks` (lint avant chaque commit).

### Points faibles
- **Pas de couverture de code mesurée** (llvm-cov / tarpaulin) — on ne connaît pas le % réel de couverture.
- **`print_summary()` non testé** : la méthode par défaut du trait utilise sysinfo directement, impossible à mocker sans abstraire la sortie.
- Un test faible : `test_install_failure_propagates` dans arch.rs ne vérifie pas réellement une erreur (le pattern "install" ne matche pas les args pacman → le test passe via `is_ok()`). C'est un faux positif qui devrait être corrigé.

### Évolution
| Métrique | Avant | Après | Δ |
|---|---|---|---|
| Tests | 5 | 25 | ×5 ✅ |
| Warnings clippy | 0 | 0 | = |
| MSRV vérifié en CI | Non | Oui (1.85.0) | ✅ |
| Édition Rust | 2021 | 2024 | ✅ |

---

## 3. Sécurité — Note : C+ (était C)

| Sévérité | Problème | Statut | Issue |
|---|---|---|---|
| **HAUTE** | `install_package(name: &str)` — pas de validation/sanitisation du nom de paquet | ⚠️ **Ouvert** | #3 |
| **HAUTE** | Cloud-Init `user-data` : `chpasswd: list: genesis:genesis` — mot de passe trivial en clair | ⚠️ **Ouvert** (acceptable en E2E) | — |
| **MOYENNE** | SSH `StrictHostKeyChecking=no` dans Justfile | ⚠️ **Acceptable** (E2E local uniquement) | — |
| **MOYENNE** | `sed -i` pour injection SSH dans `user-data` — risque de corruption | ✅ **Résolu** (PR #12 : injection idempotente, 2-pass sed) | — |
| **BASSE** | Pas de checksum des images QEMU téléchargées | ⚠️ **Ouvert** | #4 |
| **BASSE** | `sudo` sans audit trail | ⚠️ **Ouvert** (logging → #8) | — |
| **NOUVEAU** | ✅ `cargo audit` exécuté en CI (job dédié + cache binaire) | ✅ **Résolu** (PR #13) | — |
| **NOUVEAU** | ✅ Branch protection sur master avec required status checks | ✅ **Résolu** (PR #15) | — |

### Analyse
La sécurité a légèrement progressé grâce à :
1. `cargo audit` systématique en CI (détecte les vulnérabilités connues dans les dépendances).
2. Branch protection empêchant le merge sans CI verte.
3. SSH key injection rendue idempotente (plus de risque de corruption).

Les deux problèmes **HAUTE** restants sont les plus importants à traiter : la validation des noms de paquets (#3) est un vecteur d'injection potentiel, et le mot de passe cloud-init en clair est un mauvais pattern (même en E2E).

---

## 4. Scripts & Justfile — Note : A- (était B-)

### Points forts
- **10 scripts** bien découpés dans `scripts/` — chacun avec une responsabilité unique.
- **Justfile épuré** (177 lignes) : agit comme table des matières, délègue la logique aux scripts.
- **Recettes organisées** par sections : Variables → Quality → Build → VM Provisioning → VM Boot/Deploy → E2E/CI.
- **`scripts/provision-setup.sh`** : injection SSH idempotente avec placeholder + 2-pass sed.
- **`scripts/boot-vm.sh`** : auto-détection KVM/TCG au runtime, warning si TCG.
- **`scripts/build-arm.sh`** : fallback chain intelligent (native cross → Distrobox → podman/docker).
- **`scripts/wait-ssh.sh`** : cloud-init status + retry SSH robuste.
- **`scripts/reset-overlay.sh`** : reset overlay VM pour benchmarks/CI idempotents.
- **`scripts/ci-test.sh`** : cycle complet E2E (boot → wait → deploy → test → clean).

### Points faibles (restants)
- **`clean-vms`** utilise `killall` — non-portable et dangereux (→ issue #11 PID management).
- **Pas de `shellcheck`** sur les scripts shell en CI.
- **SSH avec `-o StrictHostKeyChecking=no`** — documenté mais pas idéal si copié en production.

### Évolution
| Métrique | Avant | Après | Δ |
|---|---|---|---|
| Scripts dans scripts/ | 1 | 10 | ×10 ✅ |
| Shell LOC | ~50 | 710 | Infrastructure complète ✅ |
| Logique inline dans Justfile | 15-30 lignes par recette | ≤5 lignes, délégué aux scripts | ✅ |
| Recettes Justfile | ~20 | ~30 (organisées par sections) | ✅ |

---

## 5. CI/CD — Note : A (était A-)

### Points forts
- **7 jobs** dans le pipeline CI, architecture parallélisée :
  - `quality` (matrice stable + MSRV 1.85.0) : fmt, clippy, test, actionlint, check-actions
  - `security` (parallèle) : cargo-audit avec cache binaire
  - `build` (après quality) : x86_64 + aarch64 static binaries
  - `e2e-test` ×3 (après build) : Debian, Arch, Raspbian avec QEMU + KVM
- **Wall-clock optimisé** : 6m33s → 4m01s (-40%) grâce à la parallélisation du security audit.
- **MSRV 1.85.0** vérifié dans la matrice — compatibilité garantie.
- **Release workflow** : tags `v*` → build multi-arch → GitHub Release avec notes auto-générées.
- **Docs workflow** : déploiement automatique Rustdoc sur GitHub Pages.
- **Branch protection** : required status checks (Quality Gate ×2, Security Audit, Build), strict mode.
- **Cache intelligent** : cargo registry, cargo-audit binary, QEMU cloud images.
- **KVM activé** sur runners CI (`sudo chmod 666 /dev/kvm`).
- **Timeout E2E** : 15 min par job pour éviter les jobs zombies.
- **fail-fast: false** sur E2E — toutes les distros sont testées même si une échoue.
- **`check-actions`** : vérifie que toutes les GitHub Actions référencées existent réellement.

### Points faibles (restants)
- Pas de SBOM ni scan avancé de sécurité (Snyk, Trivy).
- Pas de `shellcheck` sur les scripts shell.
- Pas de mesure de couverture de code dans CI.

### Évolution
| Métrique | Avant | Après | Δ |
|---|---|---|---|
| Workflows | 1 | 3 | ×3 ✅ |
| Jobs CI | 2 | 7 | ×3.5 ✅ |
| Wall-clock | ~6m33s | ~4m01s | -40% ✅ |
| MSRV vérifié | Non | Oui | ✅ |
| Release automatique | Non | Oui (tags → binaires) | ✅ |
| Branch protection | Non | Oui (4 checks requis) | ✅ |
| Security audit | Non | cargo-audit en CI | ✅ |

---

## 6. Tests — Note : B+ (était D)

### État actuel

| Type | Quantité | Couverture |
|---|---|---|
| Unit tests (platform/mod.rs) | 13 | detect ×4, AptPlatform: display_name ×2, update, install, bootstrap, failure ×3 |
| Unit tests (platform/arch.rs) | 6 (+1 faible) | display_name, update, install, bootstrap, failures ×2 (+1 faux positif) |
| Intégration CLI (tests/cli.rs) | 5 | --help, --version, no args, invalid subcommand, detect |
| Doctests | 1 | lib.rs exemple get_platform |
| **Total** | **25** | |

### Ce qui EST testé (vs audit initial)
- ✅ Détection d'OS (4 variantes : Debian, Arch, Raspbian, Unknown)
- ✅ `update_system()` — vérifie les appels mock (apt-get update+upgrade / pacman-key + pacman -Syu)
- ✅ `install_package()` — vérifie les args mock
- ✅ `bootstrap()` — vérifie la séquence complète (update + N packages)
- ✅ Propagation d'erreurs — update failure, install failure, bootstrap stops on error
- ✅ Parsing CLI — help, version, no args, invalid subcommand, detect subcommand
- ✅ Doctest — exemple d'usage lib.rs

### Ce qui N'est PAS testé
- ❌ `print_summary()` — implémentation par défaut dans le trait, I/O via sysinfo
- ❌ `app::run_bootstrap()` / `app::run_detect()` — fonctions dans lib.rs, appellent `get_platform()` réel
- ❌ `RealExecutor` — par nature, teste les commandes réelles (couvert par E2E)
- ❌ `execute_with_env()` — méthode du trait CommandExecutor, jamais appelée dans le code actuel
- ❌ Couverture de code non mesurée (pas de llvm-cov / tarpaulin)
- ⚠️ `test_install_failure_propagates` (arch.rs) — faux positif : le pattern "install" ne matche pas les args pacman, donc `is_ok()` passe sans vérifier d'erreur.

### Évolution
| Métrique | Avant | Après | Δ |
|---|---|---|---|
| Total tests | 5 | 25 | ×5 ✅ |
| Tests unitaires métier | 0 | 19 | ∞ ✅ |
| Tests CLI | 0 | 5 | ∞ ✅ |
| Mock-based testing | Impossible | CommandExecutor injectable | ✅ |
| Note | D | B+ | +3 niveaux |

### Recommandations pour atteindre A
1. Corriger le faux positif `test_install_failure_propagates` dans arch.rs.
2. Ajouter mesure de couverture (`cargo tarpaulin` ou `llvm-cov`) en CI.
3. Tester `run_bootstrap()`/`run_detect()` en intégration (injecter un mock OS).
4. Ajouter mutation testing (`cargo-mutants`) pour valider la robustesse.

---

## 7. Documentation — Note : A- (nouvelle catégorie)

### Inventaire

| Document | Contenu | LOC approx |
|---|---|---|
| `README.md` | Vue d'ensemble, features, architecture, quick start | ~100 |
| `VM_SETUP.md` | Guide setup VMs QEMU pour E2E | ~50 |
| `docs/vm-virtualization.md` | KVM vs TCG, benchmarks, troubleshooting (35+ refs) | ~530 |
| `docs/audit-phase1.md` | Audit baseline + suivi progression | ~300 |
| `docs/github-settings.md` | Labels, milestones, issues, project board | ~100 |
| `docs/benchmarks/initial_reference.md` | Benchmarks de référence | ~50 |
| `.github/copilot-instructions.md` | Guidelines projet Copilot | ~60 |
| `.github/instructions/*.md` (×3) | Commit workflow, GitHub project, testing quality | ~150 |

### Points forts
- Documentation exhaustive de l'infrastructure VM/QEMU.
- Copilot instructions pour la persistance de contexte inter-sessions.
- Audit documenté avec suivi de progression.
- Rustdoc fonctionnel avec déploiement automatique GitHub Pages.

### Points faibles
- Pas de `CONTRIBUTING.md`.
- Pas de `CHANGELOG.md` (compensé par les release notes auto-générées).
- L'architecture (trait diagram, module dependencies) n'est documentée que dans le README en Mermaid.

---

## 8. Synthèse & Comparaison

### Tableau récapitulatif des notes

| Domaine | Audit Phase 1 (baseline) | Audit Phase 2 (maintenant) | Δ |
|---|---|---|---|
| **Architecture** | A- | **A** | ↑ |
| **Qualité de Code** | B+ | **A-** | ↑ |
| **Sécurité** | C | **C+** | ↑ |
| **Scripts & Justfile** | B- | **A-** | ↑↑ |
| **CI/CD** | A- | **A** | ↑ |
| **Tests** | D | **B+** | ↑↑↑ |
| **Documentation** | — | **A-** | (nouveau) |
| **Note globale** | **B** | **A-** | ↑↑ |

### Progression par milestone

| Milestone | Statut | Issues | Résultat |
|---|---|---|---|
| Phase 1 — Testability & CI | ✅ **Fermé** | 1/1 | CommandExecutor, 25 tests, CI complète |
| Phase 2 — DRY & Security | 🔄 **En cours** | 2/4 fermées | AptPlatform ✅, cargo-audit ✅. Reste : #3 (validation paquets), #4 (checksums) |
| Phase 3 — CI Industrielle | ✅ **Fermé** | 4/4 | MSRV, release workflow, branch protection, docs CI update |
| Phase 4 — Features | 📋 **Planifié** | 0/4 | #8 tracing, #9 dry-run, #10 TOML config, #11 PID management |

### Top 5 des améliorations les plus impactantes

1. **CommandExecutor trait** : a rendu le code testable et a fait passer les tests de 5 → 25.
2. **AptPlatform consolidation** : -121 LOC, zéro duplication apt, architecture plus propre.
3. **CI parallélisée** : -40% wall-clock, MSRV, security audit, branch protection.
4. **10 scripts extraits** : Justfile lisible, logique maintenable dans scripts/.
5. **Release workflow** : tag → binaires multi-arch automatiques.

---

## 9. Roadmap — Prochaines étapes

### Priorité 1 : Terminer Phase 2 (sécurité)
- **#3** : Validation/sanitisation des noms de paquets dans `install_package()` — regex whitelist `[a-zA-Z0-9.+\-]+`.
- **#4** : Checksum SHA256 des images QEMU téléchargées.

### Priorité 2 : Phase 4 — Features
- **#8** : Remplacer `println!` par `tracing` (structured logging).
- **#9** : Mode dry-run (afficher les commandes sans les exécuter).
- **#10** : Config TOML pour les listes de paquets (remplacer `ESSENTIAL_PACKAGES`).
- **#11** : Gestion PID des VMs QEMU (remplacer `killall`).

### Priorité 3 : Qualité
- Corriger le faux positif `test_install_failure_propagates` (arch.rs).
- Ajouter `shellcheck` en CI pour les scripts shell.
- Ajouter mesure de couverture de code (`cargo tarpaulin` / `llvm-cov`).
- Ajouter `CONTRIBUTING.md` et `CHANGELOG.md`.

### Objectif final
| Domaine | Cible |
|---|---|
| Architecture | A+ (config TOML, dry-run) |
| Qualité | A (couverture mesurée, mutation testing) |
| Sécurité | B+ (validation paquets, checksums) |
| Tests | A (couverture >80%, faux positifs corrigés) |
| CI/CD | A+ (shellcheck, coverage report) |
