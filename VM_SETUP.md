# Environnement de Déploiement et Test (E2E Automatisé)

Pour garantir la valeur de cet outil, il faut le tester *in situ* sur ses cibles ! Étant donné que des solutions interactives type `quickemu` demandent une installation graphique manuelle bloquante (LiveCD), nous utilisons un banc de test QEMU natif complet et **totalement automatisé** basé sur des "Cloud Images".

## 1. Pré-requis sur l'hôte

Assurez-vous d'avoir les outils de virtualisation et de génération d'ISO (pour injecter votre utilisateur et clé SSH sans mot de passe via Cloud-Init) :
- `qemu-system-x86_64` (ou `qemu-kvm`)
- `mkisofs` ou `genisoimage` (sur Fedora : `sudo dnf install genisoimage`)

## 2. Provisionnement Automatique

La recette correspondante télécharge la version officielle Debian Cloud (image `.qcow2`), génère une clé SSH dédiée `e2e_key`, et package le "Seed" (config Cloud-Init) :

```bash
just provision-vms
```
*(Ceci est fonctionnel pour la cible Debian standard. Le code pour intégrer logiquement Arch Linux Cloud et Raspbian suit le même pattern).*

## 3. Démarrage (Headless)

```bash
just boot-debian
```
Cela lancera l'instance Debian en arrière-plan (`-daemonize`). L'image `cloud-init` configurera le réseau et injectera `genesis / e2e_key` automatiquement durant son boot (~ 60 secondes).

## 4. Déploiement & Execution

Une fois la VM démarrée, il suffit de compiler l'application statiquement (`musl`) et de la pousser !

```bash
just deploy-debian
```

> **Note :** Le Justfile s'occupera d'invoquer la compilation `cargo build --release --target x86_64-unknown-linux-musl`, d'envoyer (SCP) le binaire `genesis-rs` vers `/tmp/genesis-rs` via le port proxy redirigé `22221`, et de l'exécuter dans la foulée via SSH pour vérifier son output !
