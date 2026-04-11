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

## ⏱️ Résultats de la Référence (Optimisée)

| Distribution | Architecture | Boot Time (ms) | Deploy Time (ms) | Total E2E (ms) | Gain vs Initial |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Debian 12** | x86_64 | 10 485 | 6 | 10 491 | - |
| **Arch Linux** | x86_64 | 14 483 | 6 | 14 489 | - |
| **Raspbian*** | ARM64 | **71 988** | 536 | **72 524** | **-34% (Ancier: 109s)** |

*\*Testé sur Debian 12 ARM64 via QEMU TCG.*

## 🚀 Optimisations Appliquées
- **CPU** : Passage sur `-cpu max` pour ARM64 (meilleur support d'instructions TCG).
- **Entropie** : Ajout de `virtio-rng-pci` pour accélérer le démarrage de SSH et cloud-init.
- **Stockage** : Utilisation de `cache=unsafe` pour les disques de test éphémères.
- **Headerless** : Utilisation systématique de `-display none` pour éviter tout overhead graphique.

## 📝 Observations
- L'optimisation des flags QEMU a permis de gagner plus de **35 secondes** sur le cycle ARM64.
- Le cycle de test ARM64 (~72s) reste exploitable pour de l'intégration continue, même si significativement plus lent que x86_64 (~12s).
- La compilation croisée via **Distrobox** est extrêmement performante (~6s pour le build complet).
