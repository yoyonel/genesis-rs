# VM Virtualization & Benchmark Reproducibility Guide

Ce document explique en détail le fonctionnement de l'infrastructure de virtualisation de genesis-rs, les facteurs qui impactent les performances et la reproductibilité, et comment configurer son environnement pour des résultats stables et déterministes.

---

## Table des matières

1. [Architecture de virtualisation](#1-architecture-de-virtualisation)
2. [KVM vs TCG : l'accélération matérielle](#2-kvm-vs-tcg--laccélération-matérielle)
3. [Images QCOW2 et overlay copy-on-write](#3-images-qcow2-et-overlay-copy-on-write)
4. [Cloud-Init et first-boot](#4-cloud-init-et-first-boot)
5. [Sources de non-déterminisme](#5-sources-de-non-déterminisme)
6. [Garantir la reproductibilité](#6-garantir-la-reproductibilité)
7. [Configuration KVM complète](#7-configuration-kvm-complète)
8. [Référence des commandes](#8-référence-des-commandes)
9. [Dépannage](#9-dépannage)
10. [Références officielles](#10-références-officielles)

---

## 1. Architecture de virtualisation

genesis-rs utilise [QEMU](https://www.qemu.org/) pour exécuter des VMs headless à partir de Cloud Images officielles. L'architecture est la suivante :

```
┌─────────────────────────────────────────────────────┐
│  Machine hôte (x86_64)                              │
│                                                     │
│  ┌──────────────────┐  ┌──────────────────────────┐ │
│  │ base.qcow2       │  │ cloud-init/seed.iso      │ │
│  │ (image officielle │  │ (user-data + meta-data)  │ │
│  │  en lecture seule)│  │                          │ │
│  └───────┬──────────┘  └────────────┬─────────────┘ │
│          │ backing file             │               │
│  ┌───────▼──────────┐               │               │
│  │ *-test.qcow2     │               │               │
│  │ (overlay CoW,    │               │               │
│  │  toutes écritures│               │               │
│  │  vont ici)       │               │               │
│  └───────┬──────────┘               │               │
│          │                          │               │
│  ┌───────▼──────────────────────────▼─────────────┐ │
│  │  QEMU  (KVM ou TCG)                            │ │
│  │  ┌───────────────────────────────────────────┐  │ │
│  │  │  VM Guest (Debian / Arch / Raspbian)      │  │ │
│  │  │  - cloud-init → user genesis + clé SSH    │  │ │
│  │  │  - SSH sur port forwarding (2222x)        │  │ │
│  │  │  - /tmp/genesis-rs (binaire déployé)      │  │ │
│  │  └───────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

**Flux d'un benchmark complet** :
1. Kill des VMs existantes
2. Reset de l'overlay → état vierge
3. Boot QEMU avec l'overlay frais + cloud-init
4. Attente SSH (cloud-init crée l'utilisateur, configure réseau, génère clés hôte)
5. SCP du binaire `genesis-rs` vers la VM
6. Exécution SSH de `genesis-rs bootstrap` (update système + install paquets)
7. Kill VM, rapport des métriques

---

## 2. KVM vs TCG : l'accélération matérielle

C'est **le facteur n°1** qui impacte les performances. La différence est colossale.

### Qu'est-ce que KVM ?

[KVM (Kernel-based Virtual Machine)](https://www.linux-kvm.org/) est un module du noyau Linux qui permet au CPU d'exécuter **directement** le code du guest via les extensions de virtualisation matérielle Intel VT-x (instruction `vmx`) ou AMD-V (instruction `svm`).

Le guest tourne en mode "near-native" : les instructions sont exécutées par le CPU physique sans traduction. Seuls les accès I/O et les instructions privilégiées provoquent un "VM exit" vers l'hyperviseur.

### Qu'est-ce que TCG ?

[TCG (Tiny Code Generator)](https://www.qemu.org/docs/master/devel/tcg.html) est l'émulateur logiciel de QEMU. Il fait de la **traduction binaire dynamique** : chaque bloc d'instructions du guest est traduit à la volée en instructions de l'hôte, mis en cache, puis exécuté. C'est l'équivalent d'un interpréteur JIT pour du code machine.

### Comparaison des performances

| Métrique | KVM | TCG | Facteur |
|:---|:---|:---|:---|
| **Boot + SSH ready** | ~20-25s | ~250-300s | **10-15x** |
| **pacman-key --init** (crypto RSA) | ~2s | ~30-60s | **15-30x** |
| **pacman -Syu** (183 MB) | ~25s | ~200s+ | **8-10x** |
| **Bootstrap total** | ~35-40s | ~400-600s | **10-15x** |
| **CPU overhead** | ~2-5% | ~1000-2000% | - |

### Cas particulier : ARM64 cross-emulation (Raspbian)

Pour Raspbian, QEMU émule une architecture **différente** de l'hôte (aarch64 sur x86_64). C'est du **TCG obligatoire** — KVM ne peut accélérer que la même architecture que l'hôte. La [documentation QEMU sur la system emulation](https://www.qemu.org/docs/master/system/targets.html) le confirme : KVM requiert que le guest et l'host partagent la même ISA.

Cela signifie :
- Chaque instruction ARM (A64) est traduite dynamiquement en x86_64 par le [TCG](https://www.qemu.org/docs/master/devel/tcg.html)
- Les instructions SIMD/crypto ARM (NEON, AES, SHA) n'ont pas d'équivalent direct → émulation multi-instructions
- Le firmware [UEFI EDK2/AAVMF](https://github.com/tianocore/edk2) ajoute une couche de boot supplémentaire (pflash)

| Métrique | x86_64 + KVM | ARM64 + TCG cross | Facteur |
|:---|:---|:---|:---|
| **Boot + SSH** | ~25s | ~106s | **~4x** |
| **Bootstrap total** | ~37s | ~254s | **~7x** |
| **Total E2E** | ~62s | ~360s | **~6x** |

### Pourquoi TCG est particulièrement lent pour genesis-rs

Le bootstrap exécute des opérations **CPU-intensives** dans la VM :
- **Cryptographie GPG** : `pacman-key --init` génère des clés RSA et importe ~100 clés PGP. Chaque opération crypto implique des millions d'instructions arithmétiques, chacune traduite individuellement par TCG.
- **Décompression** : chaque paquet est décompressé (zstd/xz) — opérations de manipulation de bits massivement utilisées.
- **I/O disque** : toutes les écritures passent par la couche d'émulation QEMU → overlay qcow2 → hôte.

### Version de QEMU : impact réel sur les performances

On pourrait penser qu'une version plus récente de QEMU améliorerait significativement les performances. En pratique, l'impact est **négligeable** pour notre cas d'usage.

**Contexte** : Debian 13 (trixie) fournit QEMU 10.0.8. La dernière stable upstream est 10.2.2 (mars 2026). Les [changelogs QEMU](https://www.qemu.org/docs/master/about/changelog.html) entre ces versions montrent des corrections de bugs, des améliorations de compatibilité matérielle, et des optimisations TCG incrémentales (~2-5%).

| Scénario | Gain estimé QEMU 10.0 → 10.2 | Pourquoi |
|:---|:---|:---|
| **x86_64 + KVM** | **~0%** | QEMU n'est pas dans le chemin critique. Le CPU exécute directement le code guest via [VT-x](https://www.kernel.org/doc/html/latest/virt/kvm/index.html). QEMU ne fait que le setup et l'I/O virtio |
| **ARM64 + TCG** | **~2-5%** | Les améliorations TCG entre versions mineures sont incrémentales. Le bottleneck est fondamentalement la traduction binaire cross-arch, pas un bug de perf |

**Coût de la mise à jour** : compiler QEMU from source (~30 min de build, ~200 dépendances) ou utiliser un backport/PPA, avec un risque de casse et une charge de maintenance pour un gain marginal.

**Vrai levier de performance pour ARM64** : utiliser un hôte ARM64 natif (Raspberry Pi 5, Apple Silicon via [UTM](https://mac.getutm.app/), [Ampere Altra](https://amperecomputing.com/), CI GitHub avec runner `ubuntu-24.04-arm`) pour éliminer le TCG et basculer sur KVM ARM. Gain attendu : **5-7x** vs le TCG cross-arch actuel.

**Conclusion** : rester sur la version QEMU du package manager de la distro. Les gains significatifs viennent de l'activation de KVM (10-20x), pas de la version de QEMU.

Releases : <https://www.qemu.org/download/>

### Comment le script choisit

[`scripts/boot-vm.sh`](../scripts/boot-vm.sh) teste l'accès à `/dev/kvm` :

```bash
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    ACCEL="kvm"    # Virtualisation hardware
    CPU="host"     # Expose le CPU réel au guest
else
    ACCEL="tcg,thread=multi"  # Émulation logicielle
    CPU="max"                  # CPU émulé avec toutes les features
fi
```

Quand KVM est indisponible, un encadré d'avertissement est affiché avec les instructions de correction.

---

## 3. Images QCOW2 et overlay copy-on-write

### Principe

Le format [QCOW2 (QEMU Copy-On-Write 2)](https://www.qemu.org/docs/master/interop/qcow2.html) supporte les **backing files** : un overlay ne stocke que les blocs qui diffèrent de l'image de base.

```
arch.qcow2 (518 MB)           ← Image de base officielle (lecture seule)
    └── arch-test.qcow2       ← Overlay : ne contient QUE les écritures
         (192 KB vierge → 300 MB après un bootstrap complet)
```

- **Avantage** : on peut "reset" la VM en recréant l'overlay (~instantané), sans re-télécharger l'image de 500 MB.
- **Piège** : si on réutilise un overlay "dirty" (post-bootstrap), le deuxième run est plus rapide car cloud-init ne s'exécute pas, les paquets sont déjà cachés, les clés GPG déjà importées. **Ce n'est pas un benchmark valide.**

### Anatomie d'un overlay

```bash
$ qemu-img info tests/e2e/arch-test.qcow2

# Overlay vierge (juste créé) :
disk size: 192 KiB
backing file: arch.qcow2

# Overlay après un bootstrap complet :
disk size: 310 MiB     ← 310 MB de données écrites par la VM
backing file: arch.qcow2
```

### Reset d'un overlay

```bash
# Un seul OS :
just reset-overlay arch

# Tous les OS :
just reset-overlays
```

Le script [`scripts/reset-overlay.sh`](../scripts/reset-overlay.sh) :
1. Supprime l'overlay existant (et ses 300 MB de delta)
2. Recrée un overlay vierge pointant vers la même image de base
3. Résultat : la VM bootera comme si c'était la première fois

---

## 4. Cloud-Init et first-boot

[Cloud-Init](https://cloud-init.io/) est le standard d'initialisation des Cloud Images. Au premier boot d'une VM avec un overlay vierge, il exécute :

1. **Réseau** : configuration DHCP (via QEMU user-mode networking)
2. **Utilisateur** : création de `genesis` avec sudo NOPASSWD
3. **SSH** : injection de la clé publique `e2e_key.pub`, génération des clés hôte (RSA, ECDSA, ED25519)
4. **Paquets** : mise à jour initiale des métadonnées (selon la distro)
5. **Marqueur** : écriture de `/var/lib/cloud/instance/boot-finished`

**Impact sur les benchmarks** : le first-boot cloud-init prend ~15-20s (KVM) ou ~120-180s (TCG). Sur un overlay réutilisé, cloud-init détecte que l'initialisation a déjà été faite et skip tout → le boot est beaucoup plus rapide, mais **ce n'est pas reproductible**.

Le fichier de configuration cloud-init est dans [`tests/e2e/cloud-init/user-data`](../tests/e2e/cloud-init/user-data), packagé en ISO via `mkisofs`.

---

## 5. Sources de non-déterminisme

Voici **tous les facteurs** qui peuvent faire varier les résultats d'un benchmark :

### Facteurs majeurs (impact > 5x)

| Facteur | Impact | Explication |
|:---|:---|:---|
| **KVM vs TCG (même arch)** | 10-20x | Voir section 2. Module kernel `kvm_intel`/`kvm_amd` non chargé |
| **TCG cross-arch (ARM64)** | 5-7x vs KVM | Émulation cross-architecture obligatoire, pas de contournement possible sur x86 |
| **Overlay dirty vs frais** | 2-10x | Cloud-init skip, paquets déjà en cache, clés GPG déjà importées |

### Facteurs moyens (impact 1.5-3x)

| Facteur | Impact | Explication |
|:---|:---|:---|
| **Bande passante réseau** | 1.5-3x | `pacman -Syu` télécharge ~183 MB, `apt upgrade` ~100 MB. Miroir lent = benchmark lent |
| **Nombre de paquets à mettre à jour** | 1-3x | L'image de base vieillit → plus de mises à jour à chaque run |
| **Charge CPU hôte** | 1.2-2x | Autres processus sur l'hôte (compilation, navigateur, etc.) |
| **I/O disque hôte** | 1.2-2x | HDD vs SSD vs NVMe. L'overlay qcow2 fait beaucoup d'I/O aléatoires |

### Facteurs mineurs (impact < 1.5x)

| Facteur | Impact | Explication |
|:---|:---|:---|
| **QEMU `-smp` / `-m`** | ~1.1-1.3x | 2 vCPUs/2 GB est le paramètre actuel. Plus = légèrement plus rapide |
| **Cache QEMU (`cache=unsafe`)** | ~1.1x | Déjà activé. `unsafe` skip les `fsync()` pour la vitesse |
| **virtio-rng-pci** | ~1.05x | Déjà activé. Accélère la génération d'entropie (clés SSH, GPG) |
| **Jitter kernel** | ~1-5% | Scheduling, interruptions, timer variance |

---

## 6. Garantir la reproductibilité

### Ce que fait le benchmark automatiquement

Depuis cette version, `just benchmark <os>` exécute automatiquement :
1. **Kill** des VMs existantes
2. **Reset** de l'overlay (sauf si `--keep-overlay` est passé)
3. **Détection** de l'accélération (KVM/TCG) et affichage dans les résultats
4. **Boot**, **deploy**, **mesures**

Les résultats incluent désormais :
```
--- BENCHMARK RESULTS (arch) ---
Accel:       kvm
Overlay:     fresh (reset)
Boot Time:   23694ms
Deploy Time: 36099ms
Total E2E:   59793ms
```

### Benchmark de référence (Avril 2026)

Mesures sur Intel i7-1355U, Debian 13 (trixie), NVMe, réseau fibre :

| Distribution | Architecture | Accélération | Boot | Deploy | Total E2E |
|:---|:---|:---|:---|:---|:---|
| **Arch Linux** | x86_64 | KVM | ~29s | ~37s | **~66s** |
| **Debian 12** | x86_64 | KVM | ~25s | ~35s | **~60s** |
| **Raspbian** | ARM64 | TCG (cross) | ~106s | ~254s | **~360s** |

> **Raspbian** est ~5-6x plus lent que les targets x86_64 avec KVM. C'est intrinsèque à l'émulation cross-architecture ([QEMU TCG](https://www.qemu.org/docs/master/devel/tcg.html)) et ne peut pas être amélioré sans un hôte ARM64 natif.

### Checklist pour des résultats reproductibles

```bash
# 1. Vérifier que KVM est actif
just setup-check

# 2. Fermer les applications CPU-intensives (compilations, navigateurs)

# 3. Lancer le benchmark (overlay reset automatique)
just benchmark arch

# 4. Pour comparer, relancer 2-3 fois et faire la médiane
just benchmark arch
just benchmark arch
```

### Option `--keep-overlay` pour les benchmarks incrémentaux

Si vous voulez mesurer le temps de bootstrap sur une VM **déjà initialisée** (sans cloud-init) :
```bash
just benchmark arch            # Fresh: cloud-init + update + packages
just benchmark arch             # Fresh à nouveau (overlay reset)
# Pour garder l'état post-bootstrap:
scripts/benchmark.sh arch x86_64-unknown-linux-musl aarch64-unknown-linux-musl --keep-overlay
```

---

## 7. Configuration KVM complète

### Prérequis matériel

Le CPU doit supporter la virtualisation matérielle :
- **Intel** : VT-x (flag `vmx` dans `/proc/cpuinfo`)
- **AMD** : AMD-V (flag `svm` dans `/proc/cpuinfo`)

Vérification :
```bash
# Doit retourner un nombre > 0
grep -cE '(vmx|svm)' /proc/cpuinfo
```

> **Note** : si vous êtes dans une VM (cloud, WSL2, etc.), il faut activer le "nested virtualization" sur l'hyperviseur parent.

### Activer KVM — étape par étape

#### 1. Charger le module kernel

```bash
# Intel
sudo modprobe kvm_intel

# AMD
sudo modprobe kvm_amd
```

Vérification :
```bash
lsmod | grep kvm
# Doit afficher: kvm_intel (ou kvm_amd) + kvm
ls -la /dev/kvm
# Doit exister avec permissions crw-rw----
```

#### 2. Rendre permanent (survit au reboot)

```bash
# Intel
echo 'kvm_intel' | sudo tee /etc/modules-load.d/kvm.conf

# AMD
echo 'kvm_amd' | sudo tee /etc/modules-load.d/kvm.conf
```

Le fichier `/etc/modules-load.d/kvm.conf` est lu par `systemd-modules-load.service` au boot.

Référence : [systemd modules-load.d(5)](https://www.freedesktop.org/software/systemd/man/latest/modules-load.d.html)

#### 3. Permissions utilisateur

`/dev/kvm` appartient au groupe `kvm`. Votre utilisateur doit en faire partie :

```bash
# Vérifier
groups | grep kvm

# Ajouter si nécessaire
sudo usermod -aG kvm $(whoami)

# Appliquer sans déconnexion
newgrp kvm
```

> **Note** : sur les distributions récentes (Debian 12+, Fedora 38+, Arch), l'installation de `qemu-system-*` crée automatiquement le groupe `kvm` et configure les udev rules. Ce n'est pas toujours le cas — d'où la vérification dans `just setup-check`.

#### 4. Vérification avec `just setup-check`

```bash
$ just setup-check
▶ Checking KVM hardware acceleration...
  ✅ KVM active (Intel kvm_intel, /dev/kvm accessible)
    VMs will use hardware acceleration — optimal performance.
```

Les cas d'erreur possibles et leur diagnostic :
- **CPU sans vmx/svm** : pas de virtualisation matérielle, TCG obligatoire
- **Module non chargé** : `sudo modprobe kvm_intel` (+ instructions permanent)
- **`/dev/kvm` inaccessible** : `sudo usermod -aG kvm $(whoami)` (+ affiche permissions et groupes)

### Nested virtualization (VM dans une VM)

Si votre hôte est lui-même virtualisé (cloud provider, Proxmox, VMware, etc.) :

```bash
# Vérifier si nested est activé
cat /sys/module/kvm_intel/parameters/nested   # Y = activé

# Activer (temporaire)
sudo modprobe -r kvm_intel
sudo modprobe kvm_intel nested=1

# Activer (permanent)
echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm.conf
```

Références :
- [KVM Nested Guests (kernel.org)](https://www.kernel.org/doc/html/latest/virt/kvm/nested-virtualization.html)
- [QEMU KVM documentation](https://www.qemu.org/docs/master/system/i386/kvm.html)

---

## 8. Référence des commandes

### Overlay management

| Commande | Description |
|:---|:---|
| `just reset-overlay arch` | Reset l'overlay Arch → état vierge |
| `just reset-overlay debian` | Reset l'overlay Debian → état vierge |
| `just reset-overlay raspbian` | Reset l'overlay Raspbian → état vierge |
| `just reset-overlays` | Reset **tous** les overlays |

### Benchmarks

| Commande | Description |
|:---|:---|
| `just benchmark arch` | Benchmark complet (reset overlay + boot + bootstrap) |
| `just benchmark debian` | Benchmark Debian |
| `just benchmark raspbian` | Benchmark Raspbian (ARM64, toujours TCG cross-emulation, ~6 min) |

### Diagnostic

| Commande | Description |
|:---|:---|
| `just setup-check` | Vérifie tout : outils, Rust targets, KVM, permissions |
| `just setup` | Installe les dépendances manquantes |
| `qemu-img info tests/e2e/arch-test.qcow2` | Inspecter l'état d'un overlay (taille delta, backing file) |

---

## 9. Dépannage

### Le benchmark donne des résultats très différents entre deux runs

**Cause probable** : KVM inactif sur un des runs, ou overlay pas reset.

```bash
# Vérifier KVM
just setup-check | grep KVM

# Les résultats du benchmark indiquent maintenant l'accélération :
# Accel: kvm      ← OK
# Accel: tcg      ← 10-20x plus lent !
# Overlay: fresh  ← OK, idempotent
# Overlay: reused ← Non reproductible
```

### SSH timeout au boot

**Avec KVM** : SSH devrait être prêt en ~20-25s. Si timeout → problème d'image ou de cloud-init.

**Avec TCG x86** : le premier boot peut prendre 4-5 minutes. Le timeout de `benchmark.sh` est de 120 tentatives × 2s = 240s.

**Avec TCG ARM64 (Raspbian)** : le boot peut prendre ~2 minutes. `benchmark.sh` utilise automatiquement un timeout élargi de 300 tentatives (10 min) pour Raspbian.

```bash
# Le timeout est géré automatiquement par benchmark.sh :
# - x86_64 : 120 tentatives (4 min)
# - ARM64  : 300 tentatives (10 min)
# Pour wait-ssh.sh manuel :
scripts/wait-ssh.sh 22223 300 2    # 300 tentatives × 2s = 10 min
```

### `pacman-key` échoue (PGP key import error)

Les images Arch Linux ont un keyring GPG qui vieillit. genesis-rs exécute automatiquement `pacman-key --init` + `pacman-key --populate archlinux` avant `pacman -Syu` pour résoudre ce problème.

Si l'erreur persiste, l'image de base est probablement très ancienne :
```bash
rm tests/e2e/arch.qcow2       # Supprimer l'image de base
just provision-arch             # Re-télécharger la dernière
```

### KVM module ne se charge pas

```bash
# Vérifier que le BIOS/UEFI a la virtualisation activée
dmesg | grep -i "kvm\|vmx\|svm"

# Si "disabled by BIOS" → redémarrer et activer VT-x/AMD-V dans le BIOS/UEFI
# Souvent dans : Advanced → CPU Configuration → Intel Virtualization Technology
```

---

## 10. Références officielles

### QEMU

- **QEMU Documentation** : <https://www.qemu.org/docs/master/>
- **QCOW2 format specification** : <https://www.qemu.org/docs/master/interop/qcow2.html>
- **QEMU TCG (Tiny Code Generator)** : <https://www.qemu.org/docs/master/devel/tcg.html>
- **QEMU KVM acceleration (x86)** : <https://www.qemu.org/docs/master/system/i386/kvm.html>
- **QEMU virtio devices** : <https://www.qemu.org/docs/master/system/devices/virtio.html>
- **QEMU networking (user mode)** : <https://www.qemu.org/docs/master/system/devices/net.html>

### KVM

- **KVM project** : <https://www.linux-kvm.org/>
- **Kernel KVM documentation** : <https://www.kernel.org/doc/html/latest/virt/kvm/index.html>
- **Nested virtualization** : <https://www.kernel.org/doc/html/latest/virt/kvm/nested-virtualization.html>
- **KVM API** : <https://www.kernel.org/doc/html/latest/virt/kvm/api.html>

### Cloud-Init

- **Cloud-Init documentation** : <https://cloud-init.io/>
- **Cloud-Init reference** : <https://cloudinit.readthedocs.io/en/latest/>
- **NoCloud datasource** (ce que nous utilisons) : <https://cloudinit.readthedocs.io/en/latest/reference/datasources/nocloud.html>

### ARM64 / AArch64 specifics

- **QEMU AArch64 system emulation** : <https://www.qemu.org/docs/master/system/target-arm.html>
- **QEMU virt machine (ARM)** : <https://www.qemu.org/docs/master/system/arm/virt.html>
- **EDK2 UEFI firmware (AAVMF)** : <https://github.com/tianocore/edk2>
- **QEMU multi-target emulation** : <https://www.qemu.org/docs/master/system/targets.html>
- **ARM architecture reference** : <https://developer.arm.com/documentation/ddi0487/latest/>

### Cloud Images

- **Debian Cloud Images** : <https://cloud.debian.org/images/cloud/>
- **Arch Linux Cloud Images** : <https://gitlab.archlinux.org/archlinux/arch-boxes>
- **QEMU EFI firmware (edk2/AAVMF)** : <https://github.com/tianocore/edk2>

### Kernel modules

- **modules-load.d(5)** : <https://www.freedesktop.org/software/systemd/man/latest/modules-load.d.html>
- **modprobe.d(5)** : <https://man7.org/linux/man-pages/man5/modprobe.d.5.html>
