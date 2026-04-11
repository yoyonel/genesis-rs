# Project Benchmark & Profiling Reference

Ce document sert de "Source of Truth" pour les performances de base du projet `genesis-rs`. Il permet de comparer l'impact des futurs changements d'architecture ou de logique sur le temps de cycle de développement (E2E).

## 📅 Métadonnées du Benchmark
- **Date** : 2026-04-11
- **Auteur** : Antigravity (Assistant IA)
- **Objectif** : Mesure du cycle de boot et de déploiement initial.

## 💻 Environnement Hôte
| Composant | Détails |
| :--- | :--- |
| **OS** | Bazzite 42 (Fedora 42 base) |
| **Kernel** | 6.16.4-116.bazzite.fc42.x86_64 |
| **Architecture** | x86_64 |
| **Build Env** | Distrobox `genesis-lab` (Fedora 42) pour ARM64 |

## ⏱️ Résultats de la Référence (Baseline)

| Distribution | Architecture | Boot Time (ms) | Deploy Time (ms) | Total E2E (ms) | Conditions |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Debian 12** | x86_64 | 8 472 | 7 | 8 479 | KVM activé |
| **Arch Linux** | x86_64 | 14 700 | 6 | 14 706 | KVM activé |
| **Raspbian*** | ARM64 | 108 816 | 453 | 109 269 | Émulation TCG (Lent) |

*\*Testé sur Debian 12 ARM64 pour la partie automation.*

> [!NOTE]
> Les temps ARM64 sont ~10x supérieurs aux versions x86_64 car QEMU doit traduire chaque instruction CPU (TCG) sur une architecture différente de l'hôte.

## 📝 Observations
- L'utilisation de **KVM** est le facteur critique pour x86_64.
- Pour **ARM64**, l'absence de KVM (émulation TCG) pénalise fortement le cycle de test (~2 minutes).
- Le déploiement ARM a été effectué via une compilation croisée dans un container **Distrobox** dédié.
- Les VMs tournent désormais en mode **Headless** (`-nographic`) pour une intégration CI/CD fluide.
