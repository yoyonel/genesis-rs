# Environnement de Déploiement et Test (E2E Automatisé)

Pour garantir la valeur de cet outil, il faut le tester *in situ* sur ses cibles ! Étant donné que des solutions interactives type `quickemu` demandent une installation graphique manuelle bloquante (LiveCD), nous utilisons un banc de test QEMU natif complet et **totalement automatisé** basé sur des "Cloud Images".

## 1. Pré-requis sur l'hôte

Assurez-vous d'avoir les outils de virtualisation et de génération d'ISO (pour injecter votre utilisateur et clé SSH sans mot de passe via Cloud-Init) :
- `qemu-system-x86_64` (ou `qemu-kvm`)
- `mkisofs` ou `genisoimage` (sur Fedora : `sudo dnf install genisoimage`)

## 2. Provisionnement Automatique

La recette correspondante télécharge les versions officielles Cloud (Debian 12 et Arch Linux), génère une clé SSH dédiée `e2e_key`, et package le "Seed" (config Cloud-Init) :

```bash
just provision-vms
```
*(Ceci est fonctionnel pour les cibles Arch Linux et Debian).*

## 3. Démarrage (Headless)

```bash
just boot-debian   # Redirection SSH sur port 22221
# ou
just boot-arch     # Redirection SSH sur port 22222
```
Cela lancera l'instance en arrière-plan (`-daemonize`). L'image `cloud-init` configurera le réseau et injectera `genesis / e2e_key` automatiquement durant son boot (~ 20-40 secondes).

## 4. Déploiement & Execution

Une fois la VM démarrée, il suffit de compiler l'application statiquement (`musl`) et de la pousser !

```bash
just deploy-debian
# ou
just deploy-arch
```

> **Note :** Le Justfile s'occupera d'invoquer la compilation `cargo build --release --target x86_64-unknown-linux-musl`, d'envoyer (SCP) le binaire `genesis-rs` vers `/tmp/genesis-rs` via le port proxy redirigé, et de l'exécuter dans la foulée via SSH !
