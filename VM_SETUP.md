# Environnement de Déploiement et Test (E2E Automatisé)

Pour garantir la valeur de cet outil, il faut le tester *in situ* sur ses cibles ! Étant donné que des solutions interactives type `quickemu` demandent une installation graphique manuelle bloquante (LiveCD), nous utilisons un banc de test QEMU natif complet et **totalement automatisé** basé sur des "Cloud Images".

## 1. Pré-requis sur l'hôte

Assurez-vous d'avoir les outils de virtualisation et de génération d'ISO (pour injecter votre utilisateur et clé SSH sans mot de passe via Cloud-Init) :
- `qemu-system-x86_64` (ou `qemu-kvm`) et `qemu-system-aarch64`
- `mkisofs` ou `genisoimage` (sur Fedora : `sudo dnf install genisoimage`)
- `podman` ou `docker` (pour le build ARM via Distrobox)

## 2. Architecture des Cibles

| OS | Port SSH | Architecture | Commande de Boot |
| :--- | :--- | :--- | :--- |
| **Debian** | 22221 | x86_64 | `just boot-debian` |
| **Arch** | 22222 | x86_64 | `just boot-arch` |
| **Raspbian** | 22223 | ARM64 | `just boot-raspbian` |

## 3. Provisionnement Automatique

La recette correspondante télécharge les versions officielles Cloud, génère une clé SSH dédiée `e2e_key`, et package le "Seed" (config Cloud-Init) :

```bash
just provision-vms
```
*(Ceci est fonctionnel pour toutes les cibles. Pour ARM64, cela prépare aussi le firmware EFI).*

## 4. Démarrage (Headless)

Toutes les VMs démarrent en mode **Headless** (sans fenêtre graphique) via le moteur de virtualisation correspondant :

```bash
just boot-debian   # Boot via KVM
just boot-raspbian # Boot via TCG (ARM64 Emulation - Lent)
```
Cela lancera l'instance en arrière-plan (`-daemonize`). L'image `cloud-init` configurera le réseau et injectera `genesis / e2e_key` automatiquement durant son boot.

## 5. Build & Déploiement

Le déploiement est couplé à la compilation statique (Musl).

### Cas x86_64 (Debian/Arch)
```bash
just deploy-debian   # Compile en local et pousse
```

### Cas ARM64 (Raspbian)
Pour ARM, `genesis-rs` utilise un container **Distrobox** nommé `genesis-lab` qui contient la toolchain de cross-compilation GCC ARM.
```bash
just deploy-raspbian # Compile via Distrobox et pousse
```

## 5. Benchmarking & Profiling ⏱️

Pour mesurer la performance brute (boot et déploiement) sur un OS spécifique :
```bash
just benchmark debian
just benchmark raspbian
```
Les résultats incluent désormais le **Dashboard Matériel** (CPU, RAM, Disques) généré par l'application en temps réel.

## 6. Pipeline CI/CD (GitHub Actions) 🤖

Le projet intègre une configuration **GitHub Actions** (`.github/workflows/ci.yml`) qui s'exécute à chaque push.
Elle réalise :
- Le build statique multi-architecture (x86_64 et ARM64).
- Le boot de 3 instances QEMU en parallèle (Debian, Arch, Raspbian).
- La validation fonctionnelle via la commande `detect` (inspections système).
- Le tracking des métriques de performance (**Boot Time**, **Deploy Time**) directement dans les logs de la CI.

## 7. Validation Locale (CI-Local) 🧪

Avant de pusher vos modifications, vous pouvez jouer l'intégralité du pipeline CI sur votre machine :
```bash
just ci-local
```
Cette commande enchaîne les tests sur Debian, Arch et Raspbian. Elle utilise automatiquement **Distrobox** pour la partie ARM si vous êtes sur Bazzite, garantissant une parité parfaite avec l'infrastructure de production du lab.

## 8. Git Hooks & Qualité de Code (QA) 🏗️

Le dépôt est configuré avec un **hook pre-commit** local (`.git/hooks/pre-commit`).
Ce hook garantit qu'aucun commit n'est poussé s'il ne respecte pas les critères suivants :

1. **Formatage** : `cargo fmt --check` (doit être au standard Rust).
2. **Clippy** : `cargo clippy -- -D warnings` (zéro warning autorisé).
3. **CI Lint** : `actionlint` (validation des fichiers `.github/workflows`).

### Installation du Linter CI
Pour bénéficier de la validation des workflows localement :
```bash
# Sur Fedora/Bazzite
go install github.com/rhysd/actionlint/cmd/actionlint@latest
```

### Forcer la vérification
Vous pouvez lancer manuellement toutes les vérifications de qualité via :
```bash
just lint
```
Cela lancera `clippy` et `actionlint` de manière séquentielle.

---
Consultez le [Dashboard Système](file:///home/latty/Prog/genesis-rs/src/platform/mod.rs) pour voir comment les métadonnées sont extraites.
