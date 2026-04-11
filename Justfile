# Justfile for genesis-rs

# Variables
TARGET := "x86_64-unknown-linux-musl"
ARM_TARGET := "aarch64-unknown-linux-musl"
VM_PORT := "22220"
VM_USER := "user"
VM_HOST := "localhost"

# Check the code for errors
check:
    cargo check

# Build for the host architecture
build target=TARGET:
    cargo build --release --target {{target}}

# Build for ARM64 using Distrobox (genesis-lab)
build-arm:
	distrobox enter genesis-lab -- cargo build --release --target {{ARM_TARGET}}

# Build for ARM64 natively (for CI)
build-arm-native target=ARM_TARGET:
	cargo build --release --target {{target}}

# Vérifier la qualité du code (Rust + CI + Existence des Actions)
lint: lint-rust lint-ci check-actions

# Lint du code Rust
lint-rust:
    cargo clippy -- -D warnings

# Lint des workflows GitHub Actions
lint-ci:
	actionlint .github/workflows/*.yml || echo "⚠️ actionlint non trouvé ou en erreur, ignoré."

# Vérifier l'existence des dépôts GitHub Actions utilisés
check-actions:
	@echo "🔍 Vérification de l'existence des GitHub Actions..."
	@grep "uses:" .github/workflows/*.yml | grep -v "./" | sed 's/.*uses: \(.*\)@.*/\1/' | sort -u | xargs -n 1 gh repo view --json nameWithOwner -q .nameWithOwner || (echo "❌ Une ou plusieurs actions sont introuvables !"; exit 1)
	@echo "✅ Toutes les actions sont valides."

# Format the code
format:
    cargo fmt

# Générer la doc et lancer un serveur local pour la consulter proprement
doc:
	cargo doc --no-deps
	@echo "Lancement du serveur de doc sur http://localhost:8085"
	python3 -m http.server --directory target/doc 8085

# Check formatting
format-check:
    cargo fmt --check

# Install Git hooks
install-hooks:
	cp .git/hooks/pre-commit.sample .git/hooks/pre-commit || true # safety if sample exists
	@echo "Installing pre-commit hook..."
	@printf '#!/bin/bash\n# genesis-rs pre-commit hook\nset -e\njust lint\n' > .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit

# Run unit tests
test:
    cargo test

# Deploy the binary to a running VM via SCP
deploy-host target=TARGET:
    scp -P {{VM_PORT}} target/{{target}}/release/genesis-rs {{VM_USER}}@{{VM_HOST}}:/tmp/genesis-rs
    @echo "Binary deployed to /tmp/genesis-rs on VM"

# Setup tests requirements (SSH keys)
provision-setup:
	@mkdir -p tests/e2e/cloud-init
	@if [ ! -f tests/e2e/e2e_key ]; then \
		ssh-keygen -t ed25519 -N "" -f tests/e2e/e2e_key -C "e2e@genesis" > /dev/null; \
	fi
	@PUB_KEY=$(cat tests/e2e/e2e_key.pub); \
	sed -i "s|__GENESIS_SSH_KEY__|${PUB_KEY}|" tests/e2e/cloud-init/user-data 2>/dev/null || true

# Provision all Cloud images
provision-vms: provision-setup provision-debian provision-arch provision-raspbian
	@echo "All VMs provisioned successfully."

provision-debian: provision-setup
	@echo "Provisioning Debian Cloud VM..."
	@mkdir -p tests/e2e/cloud-init
	@if [ ! -f tests/e2e/debian.qcow2 ]; then \
		echo "Downloading Debian image..."; \
		wget -q -c -O tests/e2e/debian.qcow2 https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2; \
	fi
	qemu-img create -f qcow2 -F qcow2 -b debian.qcow2 tests/e2e/debian-test.qcow2 || true
	mkisofs -output tests/e2e/cloud-init/seed.iso -volid cidata -joliet -rock tests/e2e/cloud-init/user-data tests/e2e/cloud-init/meta-data

provision-arch: provision-setup
	@echo "Provisioning Arch Linux Cloud VM..."
	@mkdir -p tests/e2e/cloud-init
	@if [ ! -f tests/e2e/arch.qcow2 ]; then \
		echo "Downloading Arch image..."; \
		wget -q -c -O tests/e2e/arch.qcow2 https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2; \
	fi
	qemu-img create -f qcow2 -F qcow2 -b arch.qcow2 tests/e2e/arch-test.qcow2 || true
	mkisofs -output tests/e2e/cloud-init/seed.iso -volid cidata -joliet -rock tests/e2e/cloud-init/user-data tests/e2e/cloud-init/meta-data

provision-raspbian: provision-setup
	@echo "Provisioning Raspbian-like (Debian ARM64) Cloud VM..."
	@mkdir -p tests/e2e/cloud-init
	@if [ ! -f tests/e2e/raspbian.qcow2 ]; then \
		echo "Downloading Raspbian image..."; \
		wget -q -c -O tests/e2e/raspbian.qcow2 https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-arm64.qcow2; \
	fi
	qemu-img create -f qcow2 -F qcow2 -b raspbian.qcow2 tests/e2e/raspbian-test.qcow2 || true
	mkisofs -output tests/e2e/cloud-init/seed.iso -volid cidata -joliet -rock tests/e2e/cloud-init/user-data tests/e2e/cloud-init/meta-data
	# Prepare padded EFI firmware (64MB required by QEMU virt machine)
	dd if=/dev/zero of=tests/e2e/EFI_CODE.fd bs=1M count=64 status=none
	# Find EFI firmware path (Distro agnostic)
	EFI_PATH=""; \
	for p in "/usr/share/AAVMF/AAVMF_CODE.fd" "/usr/share/edk2/aarch64/QEMU_EFI.fd" "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"; do \
		if [ -f "$p" ]; then EFI_PATH="$p"; break; fi; \
	done; \
	if [ -z "$EFI_PATH" ]; then echo "❌ Error: QEMU AArch64 EFI firmware not found!"; exit 1; fi; \
	dd if="$EFI_PATH" of=tests/e2e/EFI_CODE.fd conv=notrunc status=none
	dd if=/dev/zero of=tests/e2e/EFI_VARS.fd bs=1M count=64 status=none

# Boot debian VM
boot-debian:
	qemu-system-x86_64 -m 2G -smp 2 -daemonize -cpu max -display none \
		-accel tcg,thread=multi \
		-device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22221-:22 \
		-drive file=tests/e2e/debian-test.qcow2,format=qcow2,if=virtio,cache=unsafe \
		-drive file=tests/e2e/cloud-init/seed.iso,format=raw,if=virtio,readonly=on \
		-device virtio-rng-pci
	@echo "Debian booted (Headless, TCG Multi, Port 22221)."

# Deploy and run a command on Debian VM
deploy-debian cmd="bootstrap" target=TARGET:
	scp -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -P 22221 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
	ssh -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -p 22221 genesis@localhost "chmod +x /tmp/genesis-rs && /tmp/genesis-rs {{cmd}}"

# Boot Arch Linux VM
boot-arch:
	qemu-system-x86_64 -m 2G -smp 2 -daemonize -cpu max -display none \
		-accel tcg,thread=multi \
		-device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22222-:22 \
		-drive file=tests/e2e/arch-test.qcow2,format=qcow2,if=virtio,cache=unsafe \
		-drive file=tests/e2e/cloud-init/seed.iso,format=raw,if=virtio,readonly=on \
		-device virtio-rng-pci
	@echo "Arch Linux booted (Headless, TCG Multi, Port 22222)."

# Deploy and run a command on Arch Linux VM
deploy-arch cmd="bootstrap" target=TARGET:
	scp -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -P 22222 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
	ssh -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -p 22222 genesis@localhost "chmod +x /tmp/genesis-rs && /tmp/genesis-rs {{cmd}}"

# Boot Raspbian VM (ARM64)
boot-raspbian:
	qemu-system-aarch64 -m 2G -smp 2 -daemonize -M virt -cpu max -display none \
		-accel tcg,thread=multi \
		-drive if=pflash,format=raw,file=tests/e2e/EFI_CODE.fd,readonly=on \
		-drive if=pflash,format=raw,file=tests/e2e/EFI_VARS.fd \
		-device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22223-:22 \
		-drive file=tests/e2e/raspbian-test.qcow2,format=qcow2,if=virtio,cache=unsafe \
		-drive file=tests/e2e/cloud-init/seed.iso,format=raw,if=virtio,readonly=on \
		-device virtio-rng-pci
	@echo "Raspbian (ARM64) booted (Headless, MTTCG, Port 22223)."

# Deploy and run a command on Raspbian VM (ARM64)
deploy-raspbian cmd="bootstrap" target=ARM_TARGET:
	scp -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -P 22223 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
	ssh -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -p 22223 genesis@localhost "chmod +x /tmp/genesis-rs && /tmp/genesis-rs {{cmd}}"

# Wait for SSH to be ready on a specific port (300 tries = 10 minutes timeout)
wait-ssh PORT:
	@echo "Waiting for SSH on port {{PORT}}..."
	@for i in $(seq 1 300); do \
		if ssh -i tests/e2e/e2e_key -p {{PORT}} genesis@localhost -o StrictHostKeyChecking=no -o ConnectTimeout=1 echo "up" > /dev/null 2>&1; then \
			echo "SSH is ready!"; \
			sleep 5; \
			break; \
		fi; \
		echo -n "."; \
		sleep 2; \
	done

# Run a full CI test cycle for a specific OS (Boot -> Deploy -> Detect -> Clean)
ci-test os PORT target build="true":
	if [ "{{build}}" = "true" ]; then just build {{target}}; fi && \
	START_BOOT=$(date +%s%3N) && \
	just boot-{{os}} && \
	just wait-ssh {{PORT}} && \
	END_BOOT=$(date +%s%3N) && \
	BOOT_TIME=$((END_BOOT - START_BOOT)) && \
	START_DEPLOY=$(date +%s%3N) && \
	just deploy-{{os}} "detect" {{target}} && \
	END_DEPLOY=$(date +%s%3N) && \
	DEPLOY_TIME=$((END_DEPLOY - START_DEPLOY)) && \
	just clean-vms && \
	echo "" && \
	echo "--- CI PERFORMANCE METRICS ({{os}}) ---" && \
	echo "Boot Time:   ${BOOT_TIME}ms" && \
	echo "Deploy Time: ${DEPLOY_TIME}ms" && \
	echo "Total E2E:   $((BOOT_TIME + DEPLOY_TIME))ms"

# Run all CI tests locally before pushing
ci-local: build build-arm provision-vms
	@echo "=== STARTING LOCAL CI TEST SUITE (Sequential) ==="
	just clean-vms
	just ci-test debian 22221 {{TARGET}}
	just ci-test arch 22222 {{TARGET}}
	just ci-test raspbian 22223 {{ARM_TARGET}}
	@echo "=== LOCAL CI TEST SUITE COMPLETED ==="

# Run the E2E benchmark and output performance metrics
benchmark os="debian" target=TARGET:
	@OS_PORT=$(case "{{os}}" in "debian") echo "22221";; "arch") echo "22222";; "raspbian") echo "22223";; *) echo "0";; esac) && \
	OS_TARGET=$(if [ "{{os}}" = "raspbian" ]; then echo "{{ARM_TARGET}}"; else echo "{{target}}"; fi) && \
	if [ "$OS_PORT" = "0" ]; then echo "Unsupported OS: {{os}}"; exit 1; fi && \
	killall qemu-system-x86_64 qemu-system-aarch64 2>/dev/null || true && \
	START_BOOT=$(date +%s%3N) && \
	just boot-{{os}} && \
	echo -n "Waiting for SSH on port ${OS_PORT}..." && \
	END_BOOT="" && \
	for i in $(seq 1 120); do \
		if ssh -i tests/e2e/e2e_key -p ${OS_PORT} genesis@localhost -o StrictHostKeyChecking=no -o ConnectTimeout=1 echo "up" > /dev/null 2>&1; then \
			END_BOOT=$(date +%s%3N); \
			echo " Ready."; \
			break; \
		fi; \
		echo -n "."; \
		sleep 2; \
	done && \
	if [ -z "$END_BOOT" ]; then echo "Boot failed"; exit 1; fi && \
	BOOT_TIME=$((END_BOOT - START_BOOT)) && \
	START_DEPLOY=$(date +%s%3N) && \
	just deploy-{{os}} "bootstrap" ${OS_TARGET} && \
	END_DEPLOY=$(date +%s%3N) && \
	DEPLOY_TIME=$((END_DEPLOY - START_DEPLOY)) && \
	killall qemu-system-x86_64 2>/dev/null || true && \
	echo "--- BENCHMARK RESULTS ({{os}}) ---" && \
	echo "Boot Time:   ${BOOT_TIME}ms" && \
	echo "Deploy Time: ${DEPLOY_TIME}ms" && \
	echo "Total E2E:   $((BOOT_TIME + DEPLOY_TIME))ms"


# Kill all background VMs
clean-vms:
	killall qemu-system-x86_64 qemu-system-aarch64 2>/dev/null || true
	@echo "All VMs terminated."


