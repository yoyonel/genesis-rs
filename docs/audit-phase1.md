# Audit Complet de genesis-rs

> **Date** : 2026-04-11 (Phase 1)
> **Contexte** : Audit initial du projet avant refactoring. Sert de baseline pour mesurer la progression.

---

## 1. Architecture — Note : B

### Points forts
- Le trait `SystemPlatform` est une bonne abstraction pour supporter plusieurs distros. Le dispatch via `os_info::Type` dans `detect_from_info()` est clean.
- Séparation correcte : `lib.rs` (logique métier) / `main.rs` (point d'entrée) / `cli.rs` (parsing CLI).
- Le pattern `Box<dyn SystemPlatform>` permet l'extensibilité.

### Points faibles
- **Duplication massive** : `debian.rs` et `raspbian.rs` sont identiques à 95% (même apt-get, même bootstrap, même `install_package`). Il faut extraire un `AptPlatform` commun et ne laisser dans chaque impl que ce qui diverge réellement (`display_name`).
- `bootstrap()` hardcode la liste de paquets `["git", "curl", "vim", "htop"]` dans chacune des 3 impls. Ça devrait être configurable (fichier TOML/YAML ou au minimum une constante partagée).
- Pas de logging structuré : tout passe par `println!`. Pour un outil de provisioning, il faut un vrai framework de log (`tracing` ou `env_logger`) avec des niveaux (info, debug, warn, error).
- Pas de dry-run : aucun moyen de voir ce qui serait exécuté sans l'exécuter. Critique pour un outil qui lance `sudo apt-get`.

---

## 2. Qualité de Code — Note : B+

### Points forts
- Clippy et fmt passent à 0 warning/erreur.
- Les 4 tests unitaires + 1 doctest passent.
- Bonne utilisation de `anyhow` pour la propagation d'erreur.
- Documentation Rustdoc correcte sur le module `platform`.

### Points faibles
- **Couverture de test dérisoire** : 4 tests unitaires qui ne testent que la détection d'OS. Aucun test sur :
  - Le parsing CLI (clap)
  - Les méthodes `bootstrap`, `update_system`, `install_package` (même mockées)
  - `print_summary()`
  - Les cas d'erreur (commande qui échoue, OS non supporté via CLI)
- **Pas de trait mockable** pour les commandes système : `std::process::Command` est appelé directement, rendant le code impossible à tester unitairement sans exécuter `sudo apt-get` pour de vrai. Il faut une abstraction `CommandRunner` injectable.
- `print_summary()` a une implémentation par défaut dans le trait qui fait des I/O. Difficile à tester, impossible à customiser.

---

## 3. Sécurité — Note : C

| Sévérité | Problème | Localisation |
|---|---|---|
| **HAUTE** | `install_package(name: &str)` passe `name` directement à `Command::new("sudo").args(["apt-get", "install", name])`. Pas de validation/sanitisation du nom de paquet. Un input malveillant pourrait être problématique. | `debian.rs:51`, `arch.rs:33`, `raspbian.rs:51` |
| **HAUTE** | Cloud-Init `user-data` contient `chpasswd: list: genesis:genesis` — mot de passe en clair trivial. Même pour du E2E, c'est un mauvais pattern si ce fichier est commité. | `user-data:10` |
| **MOYENNE** | SSH avec `StrictHostKeyChecking=no` dans tout le Justfile — acceptable en E2E local, mais dangereux si copié en production. | `Justfile:140-170` |
| **MOYENNE** | `sed -i` pour injecter la clé SSH dans `user-data` — risque de corruption si exécuté deux fois. | `provision-setup` |
| **BASSE** | Pas de vérification d'intégrité (checksum) des images QEMU téléchargées via `wget`. | `Justfile:85-110` |
| **BASSE** | L'exécution de `sudo` se fait sans aucun audit trail ni confirmation utilisateur. | Toutes les impls platform |

---

## 4. Scripts & Justfile — Note : B-

### Points forts
- Bonne couverture fonctionnelle : build, lint, provision, boot, deploy, benchmark, ci-local.
- Support multi-arch (x86_64 + ARM64 via Distrobox).
- Recettes `ci-test` et `benchmark` avec métriques de performance.

### Points faibles
- **Complexité excessive inline** : les recettes `provision-raspbian`, `benchmark`, `ci-test` sont des scripts shell de 15-30 lignes directement dans le Justfile. Ça viole la règle « extraire la logique dans `scripts/*.sh` ».
- Un seul script dans `scripts/` : `setup-build-env.sh`. Les recettes de provisioning lourdes devraient y être extraites.
- `clean-vms` utilise `killall` — non-portable et dangereux (pourrait tuer des QEMU qui ne sont pas du projet).
- Pas de gestion de PID pour les VMs QEMU daemonisées. Impossible de savoir quelles VMs sont running.
- `provision-setup` modifie `user-data` in-place avec `sed -i` — risque de corruption si exécuté deux fois.

---

## 5. CI/CD — Note : B-

### Points forts
- Pipeline fonctionnel : build multi-arch → E2E sur 3 distros en parallèle.
- Cache des images QEMU.
- Workflow docs séparé pour GitHub Pages.
- Timeout de 15 min sur les jobs E2E.

### Points faibles
- Pas de job lint dans la CI. Clippy et fmt ne sont vérifiés que localement (pre-commit hook). Un commit direct sur master bypasse tout.
- Pas de job test (`cargo test`) dans la CI. Les tests unitaires ne tournent nulle part en CI.
- Pas de matrice de versions Rust (MSRV non défini).
- Pas de `cargo audit` pour les vulnérabilités des dépendances.
- Pas de SBOM ni scan de sécurité.
- Pas de release workflow (pas de tags, pas de binaires publiés).
- Pas de PR checks : le workflow ne tourne que sur push et pull_request sur master mais sans checks requis.

---

## 6. Tests — Note : D (le plus gros chantier)

### État initial (pré-refactoring)
- 4 tests unitaires : uniquement `detect_from_info()` sur les 4 variantes d'OS.
- 1 doctest dans `lib.rs`.
- 0 test d'intégration Rust.
- 0 test fonctionnel automatisé.
- E2E : existe via QEMU mais teste uniquement la commande `detect` (pas `bootstrap`).

### Plan de tests recommandé

| Niveau | Quoi tester | Comment | Priorité |
|---|---|---|---|
| Unitaire | `install_package` / `update_system` / `bootstrap` | Abstraire Command derrière un trait mockable (`CommandExecutor`), injecter des mocks | P0 |
| Unitaire | Parsing CLI (clap) | Tests des variantes de commandes, arguments invalides | P1 |
| Unitaire | `print_summary()` | Capturer stdout, ou abstraire la sortie | P2 |
| Intégration | `app::run_detect()` / `app::run_bootstrap()` | Tests en `tests/` Rust, mock de l'OS | P1 |
| Fonctionnel | Vérifier que le binaire compile + s'exécute avec `--help`, `detect` | `assert_cmd` + `predicates` crates | P0 |
| Fonctionnel | Vérifier les messages d'erreur (OS non supporté, commande manquante) | `assert_cmd` | P1 |
| E2E | `bootstrap` sur 3 distros (seul `detect` était testé) | QEMU existant, ajouter `bootstrap` dans la matrice CI | P1 |
| E2E | Vérifier post-bootstrap que les paquets sont bien installés | SSH + `dpkg -l` / `pacman -Q` après bootstrap | P2 |
| Sécurité | `cargo audit` dans CI | GitHub Action `rustsec/audit-check` | P0 |
| Mutation | Valider la robustesse des tests | `cargo-mutants` | P3 |

---

## 7. Synthèse & Roadmap

| Phase | Actions | Impact |
|---|---|---|
| **Phase 1 — Fondations test** | Ajouter trait `CommandExecutor`, refactorer les impls, ajouter `assert_cmd` pour les tests fonctionnels du binaire, ajouter `cargo test` + clippy + fmt en CI | Tests: D → B |
| **Phase 2 — DRY & sécurité** | Extraire `AptPlatform` partagé (Debian/Raspbian), ajouter validation des noms de paquets, `cargo audit` en CI, vérification checksum des images | Architecture: A, Sécurité: B |
| **Phase 3 — CI industrielle** | Ajouter jobs lint/test/audit, MSRV, release workflow (tags → binaires), matrice Rust versions | CI/CD: A |
| **Phase 4 — Features** | Logging structuré (`tracing`), dry-run mode, config TOML pour la liste de paquets, gestion PID des VMs | Prod-ready |

---

## 8. Suivi de progression

### Phase 1 — Réalisé (branche `refactor/phase1-testability`)

- [x] Trait `CommandExecutor` + `MockExecutor` (`src/executor.rs`)
- [x] Refactoring des 3 plateformes pour injecter l'executor
- [x] DRY apt : `apt_update_system()` / `apt_install_package()` partagés dans `mod.rs`
- [x] Constante `ESSENTIAL_PACKAGES` centralisée
- [x] Fix `DEBIAN_FRONTEND=noninteractive` passé via arg `sudo` (et non env var)
- [x] 24 tests unitaires (7 Debian + 7 Arch + 7 Raspbian + 3 détection)
- [x] 5 tests fonctionnels CLI (`assert_cmd` + `predicates`)
- [x] 1 doctest
- [x] Job CI `quality` : `just lint-rust`, `just format-check`, `just test`, `cargo audit`
- [x] Justfile restructuré + 8 scripts extraits dans `scripts/`
- [x] `scripts/setup-dev-env.sh` : setup one-command (Debian/Fedora/Arch)
- [x] `scripts/build-arm.sh` : auto-detect native cross > Distrobox > podman/docker
- [x] `scripts/boot-vm.sh` : KVM auto-detect runtime (`[ -r /dev/kvm ] && [ -w /dev/kvm ]`)
- [x] `scripts/wait-ssh.sh` : `cloud-init status --wait` + retry on SSH drop
- [x] CI : KVM activé sur runners (`sudo chmod 666 /dev/kvm`), cargo cache
- [x] Documentation complète : `README.md`, `VM_SETUP.md` réécrits
- [x] E2E validé sur 3 distros (Debian, Arch, Raspbian ARM64)

### Phases 2-4 — À faire (futures PRs)

- [ ] Extraire `AptPlatform` partagé (Debian/Raspbian) — réduit encore la duplication
- [ ] Validation/sanitisation des noms de paquets dans `install_package`
- [ ] Checksum des images QEMU téléchargées
- [ ] Logging structuré (`tracing`)
- [ ] Mode dry-run
- [ ] Config TOML pour la liste de paquets
- [ ] Gestion PID des VMs (remplacer `killall`)
- [ ] MSRV défini + matrice Rust en CI
- [ ] Release workflow (tags → binaires GitHub)
