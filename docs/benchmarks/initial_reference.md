# Project Benchmark & Profiling Reference

Ce document sert de "Source of Truth" pour les performances de base du projet `genesis-rs`. Il permet de comparer l'impact des futurs changements d'architecture ou de logique sur le temps de cycle de développement (E2E).

## 📅 Métadonnées du Benchmark
- **Date** : 2026-04-11
- **Auteur** : Antigravity (Assistant IA)
- **Objectif** : Mesure du cycle de boot et de déploiement initial (Optimisé).

## 💻 Environnement Hôte
| Composant | Détails |
| :--- | :--- |
| **OS** | Bazzite 42 (Fedora 42 base) |
| **Kernel** | 6.16.4-116.bazzite.fc42.x86_64 |
| **Architecture** | x86_64 |
| **Build Env** | Distrobox `genesis-lab` (Fedora 42) pour ARM64 |

## 📊 Dashboard de Référence (Auto-Inspection)

Depuis la version 0.1.0, le projet intègre un inventaire matériel automatique via `sysinfo`. Voici un exemple de référence capturé en VM :
- **CPU** : Intel(R) Core(TM) i7-4720HQ CPU @ 2.60GHz (2 cores)
- **RAM** : 1.93 GB
- **Disk** : `/` (ext4), `/boot/efi` (vfat)

## ⏱️ Résultats de la Référence (CI/CD Automatisée)

| Distribution | Architecture | Boot Time (ms) | Deploy Time (ms) | Total E2E (ms) | Statut CI |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Debian 12** | x86_64 | ~10 500 | ~350 | ~10 850 | ✅ Pass |
| **Arch Linux** | x86_64 | ~14 800 | ~360 | ~15 160 | ✅ Pass |
| **Raspbian*** | ARM64 | **~68 000** | ~400 | **~68 400** | ✅ Pass |

*\*Testé via QEMU TCG en CI (GitHub Actions).*

## 🚀 Nouvelles Instrumentations
- **Dashboard Système** : Affichage temps réel de l'OS, CPU, RAM et disques au lancement.
- **Profilage CI** : Mesure automatique des temps dans chaque job GitHub Actions.
- **Cache QEMU** : Utilisation d'un cache global pour les images Cloud afin d'accélérer le cycle CI.

## 📝 Observations
- L'optimisation continue des flags QEMU a permis de stabiliser le cycle ARM64 sous la barre des **70 secondes**.
- Le déploiement et la détection (`detect`) sont désormais la base de validation fonctionnelle de chaque commit.
