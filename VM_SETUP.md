# Environnement de Déploiement et Test (E2E Automatisé)

Pour garantir la valeur de cet outil, il faut le tester *in situ* sur ses cibles ! Étant donné que des solutions interactives type `quickemu` demandent une installation graphique manuelle bloquante (LiveCD), nous utilisons un banc de test QEMU natif complet et **totalement automatisé** basé sur des "Cloud Images".

## 1. Installation des dépendances

Tout est automatisé via un script qui détecte votre distribution et installe les paquets nécessaires :

```bash
just setup          # Installe tout (QEMU, firmware, toolchains, Rust targets)
just setup-check    # Vérifie que tout est en place (sans rien installer)
```

### Détail de ce qui est installé

Le script [`scripts/setup-dev-env.sh`](scripts/setup-dev-env.sh) installe :

| Catégorie | Debian/Ubuntu | Fedora/Bazzite | Arch |
|:---|:---|:---|:---|
| **QEMU x86** | `qemu-system-x86` | `qemu-system-x86-core` | `qemu-system-x86` |
| **QEMU ARM** | `qemu-system-arm` | `qemu-system-aarch64-core` | `qemu-system-aarch64` |
| **Images QEMU** | `qemu-utils` | `qemu-img` | `qemu-img` |
| **ISO Cloud-Init** | `genisoimage` | `genisoimage` | `cdrtools` |
| **EFI ARM64** | `qemu-efi-aarch64` | `edk2-aarch64` | `edk2-aarch64` |
| **Cross-compile** | `gcc-aarch64-linux-gnu` | `gcc-aarch64-linux-gnu` | `aarch64-linux-gnu-gcc` |
| **Static linking** | `musl-tools` | `musl-gcc` | `musl` |

**Rust targets** ajoutés automatiquement :
- `x86_64-unknown-linux-musl` (build statique x86)
- `aarch64-unknown-linux-musl` (build statique ARM64)

### Installation manuelle (si nécessaire)

Si vous êtes sur une distribution non supportée par le script, voici les commandes équivalentes :

```bash
# Debian / Ubuntu
sudo apt-get update
sudo apt-get install -y \
    qemu-system-x86 qemu-system-arm qemu-utils \
    genisoimage qemu-efi-aarch64 \
    musl-tools gcc-aarch64-linux-gnu

# Fedora / Bazzite
sudo dnf install -y \
    qemu-system-x86-core qemu-system-aarch64-core qemu-img \
    genisoimage edk2-aarch64 \
    musl-gcc gcc-aarch64-linux-gnu

# Arch Linux
sudo pacman -S --noconfirm \
    qemu-system-x86 qemu-system-aarch64 qemu-img \
    cdrtools edk2-aarch64 \
    musl aarch64-linux-gnu-gcc

# Rust targets (toutes distros)
rustup target add x86_64-unknown-linux-musl aarch64-unknown-linux-musl
```

## 2. Architecture des Cibles

Le banc de test simule 3 distributions via des Cloud Images officielles, bootées en headless avec QEMU :

| OS | Architecture | Port SSH | Image source | Commande |
|:---|:---|:---|:---|:---|
| **Debian 12** | x86_64 | 22221 | [debian-12-genericcloud-amd64](https://cloud.debian.org/images/cloud/bookworm/latest/) | `just boot-debian` |
| **Arch Linux** | x86_64 | 22222 | [Arch-Linux-x86_64-cloudimg](https://geo.mirror.pkgbuild.com/images/latest/) | `just boot-arch` |
| **Raspbian** | ARM64 | 22223 | [debian-12-genericcloud-arm64](https://cloud.debian.org/images/cloud/bookworm/latest/) | `just boot-raspbian` |

> **Note** : Raspbian utilise une Cloud Image Debian ARM64 émulée via QEMU TCG (pas de KVM). Le boot est sensiblement plus lent (~60-70s vs ~10-15s).

## 3. Provisionnement (téléchargement & préparation)

Le provisionnement télécharge les images Cloud officielles, crée un overlay copy-on-write, génère une clé SSH dédiée et package le seed Cloud-Init :

```bash
just provision-vms            # Prépare les 3 distros
just provision-debian         # Prépare uniquement Debian
just provision-arch           # Prépare uniquement Arch
just provision-raspbian       # Prépare uniquement Raspbian (+ firmware EFI)
```

**Ce qui se passe en détail** (orchestré par [`scripts/provision-vm.sh`](scripts/provision-vm.sh)) :

1. **Téléchargement** : l'image `.qcow2` officielle est téléchargée dans `tests/e2e/` (~500 MB par image).
2. **Overlay** : un fichier `*-test.qcow2` est créé par-dessus (copy-on-write). L'image de base n'est jamais modifiée.
3. **Clé SSH** : une paire `e2e_key` (ed25519) est générée pour l'accès sans mot de passe.
4. **Cloud-Init** : le fichier `tests/e2e/cloud-init/user-data` est packagé en ISO (`seed.iso`), injectant l'utilisateur `genesis` + la clé SSH.
5. **ARM64 uniquement** : le firmware EFI AAVMF est pré-padded à 64 MB (requis par QEMU `virt` machine).

> Les images téléchargées sont cachées dans `tests/e2e/*.qcow2` (dans le `.gitignore`). Relancer `provision-*` est idempotent — il ne re-télécharge pas si l'image existe déjà.

## 4. Démarrage des VMs (Headless)

Toutes les VMs démarrent en arrière-plan (`-daemonize`), sans fenêtre graphique :

```bash
just boot-debian    # x86_64, port 22221
just boot-arch      # x86_64, port 22222
just boot-raspbian  # ARM64 (émulation TCG), port 22223
```

Cloud-Init configure automatiquement durant le boot :
- Utilisateur `genesis` avec sudo sans mot de passe
- Clé SSH injectée depuis `e2e_key.pub`
- Réseau via QEMU user-mode networking (port forwarding SSH)

Pour vérifier que la VM est prête :
```bash
just wait-ssh 22221    # Attend que SSH réponde (polling, timeout 10 min)
```

Pour arrêter toutes les VMs :
```bash
just clean-vms
```

## 5. Build & Déploiement

Le déploiement compile en statique (musl) puis pousse le binaire via SCP :

### x86_64 (Debian / Arch)
```bash
just build                    # Compile x86_64-unknown-linux-musl
just deploy-debian detect     # Déploie et exécute "detect" sur Debian
just deploy-arch bootstrap    # Déploie et exécute "bootstrap" sur Arch
```

### ARM64 (Raspbian)
```bash
# Via Distrobox (dev local sur machine x86_64 immutable comme Bazzite)
just build-arm
just deploy-raspbian detect

# Nativement (CI ou machine ARM64)
just build-arm-native
just deploy-raspbian detect
```

## 6. Benchmarking & Profiling ⏱️

Pour mesurer la performance brute (boot + deploy complet) :
```bash
just benchmark debian         # Benchmark Debian
just benchmark arch           # Benchmark Arch
just benchmark raspbian       # Benchmark Raspbian (lent: émulation ARM64)
```

Le script [`scripts/benchmark.sh`](scripts/benchmark.sh) mesure :
- **Boot Time** : du lancement QEMU jusqu'à SSH disponible
- **Deploy Time** : SCP du binaire + exécution de `bootstrap`
- **Total E2E** : temps total du cycle

Résultats de référence : voir [`docs/benchmarks/initial_reference.md`](docs/benchmarks/initial_reference.md).

## 7. Pipeline CI/CD (GitHub Actions) 🤖

La pipeline (`.github/workflows/ci.yml`) s'exécute à chaque push/PR sur `master` :

```
quality  →  build  →  e2e-test (3 distros en parallèle)
```

| Étape | Description | Recettes utilisées |
|:---|:---|:---|
| **quality** | Formatage, clippy, tests, audit sécurité | `just format-check`, `just lint`, `just test`, `cargo audit` |
| **build** | Build statique x86_64 + ARM64 | `just build`, `just build-arm-native` |
| **e2e-test** | Boot QEMU + deploy + detect sur chaque OS | `just ci-test <os> <port> <target>` |

> La CI utilise les **mêmes recettes Justfile** que le développement local. Pas de scripts CI-only.

## 8. Validation Locale (CI-Local) 🧪

Avant de pusher, lancez l'intégralité du pipeline sur votre machine :
```bash
just ci-local
```

Cela enchaîne séquentiellement :
1. Build x86_64 + ARM64
2. Provisionnement des 3 VMs
3. Pour chaque OS : boot → wait SSH → deploy detect → clean → métriques

## 9. Git Hooks & Qualité de Code 🏗️

Le pre-commit hook (`just install-hooks`) exécute `just lint` avant chaque commit :

1. **Clippy** : `cargo clippy -- -D warnings` (zéro warning)
2. **actionlint** : validation des fichiers `.github/workflows/*.yml` (optionnel si non installé)
3. **check-actions** : vérifie que les GitHub Actions référencées existent (via `gh`)

```bash
just lint             # Lancer manuellement
just format-check     # Vérifier le formatage sans modifier
just test             # 30 tests (24 unitaires + 5 fonctionnels + 1 doctest)
```

## 10. Dépannage

### La VM ne boot pas / SSH timeout
```bash
just clean-vms           # Tuer les processus QEMU zombies
just provision-debian    # Re-provisionner (recréer l'overlay)
just boot-debian         # Relancer
```

### Images corrompues
Supprimer les overlays (les images de base sont préservées) :
```bash
rm tests/e2e/*-test.qcow2
just provision-vms       # Recréer les overlays
```

### Vérifier les prérequis
```bash
just setup-check         # Diagnostic complet sans rien installer
```
