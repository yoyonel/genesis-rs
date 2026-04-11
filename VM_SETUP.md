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

## ⏱️ Benchmarking

Pour mesurer le temps de boot et de déploiement d'un OS spécifique :
```bash
just benchmark debian
just benchmark raspbian
```

Les résultats sont sauvegardés dans `docs/benchmarks/initial_reference.md`.
