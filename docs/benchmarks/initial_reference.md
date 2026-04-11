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
| **CPU** | Intel(R) Core(TM) i7-4720HQ @ 2.60GHz |
| **Mémoire** | (Hôte standard pour ce CPU ~16GB) |
| **Architecture** | x86_64 |

## 🛠️ Stack Technique & Outils
| Outil | Version | Rôle |
| :--- | :--- | :--- |
| **Rustc** | 1.92.0 | Compilateur |
| **Cargo** | 1.92.0 | Gestionnaire de paquets |
| **QEMU** | 10.2.2 | Hyperviseur (avec KVM activé) |
| **Just** | 1.43.0 | Automate de tâches |
| **Clap** | 4.6.0 | Parsing CLI |
| **Target Rust** | `x86_64-unknown-linux-musl` | Compilation statique |

## ⏱️ Résultats de la Référence (Baseline)

### Scénario : Boot & Deploy Debian 12 (Cloud Image)
| Phase | Temps Mesuré | Conditions |
| :--- | :--- | :--- |
| **Boot VM (Ready for SSH)** | **10,445 ms** | KVM activé, Images QCow2 sur SSD. |
| **Deploy & Exec** | **314 ms** | Binaire déjà compilé, SCP local. |
| **TOTAL Cycle E2E** | **10,759 ms** | Référence pour Debian. |

### Scénario : Boot & Deploy Arch Linux (Cloud Image)
| Phase | Temps Mesuré | Conditions |
| :--- | :--- | :--- |
| **Boot VM (Ready for SSH)** | **14,679 ms** | KVM activé, Images QCow2 sur SSD. |
| **Deploy & Exec** | **372 ms** | Binaire déjà compilé, SCP local. |
| **TOTAL Cycle E2E** | **15,051 ms** | Référence pour Arch Linux. |

## 📝 Observations
- L'utilisation de **KVM** est le facteur critique ; sans lui, le boot passe de ~10s à plus de 60s.
- Le temps de déploiement est négligeable par rapport au boot.
- Tout ajout de logique lourde dans `platform::debian::bootstrap` devra être monitoré via cette référence.
