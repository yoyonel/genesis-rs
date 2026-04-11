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
build:
    cargo build --release --target {{TARGET}}

# Build for ARM64 using Distrobox (genesis-lab)
build-arm:
	distrobox enter genesis-lab -- cargo build --release --target {{ARM_TARGET}}

# Lint the code and deny warnings
lint:
    cargo clippy -- -D warnings

# Format the code
format:
    cargo fmt

# Check formatting
format-check:
    cargo fmt --check

# Run unit tests
test:
    cargo test

# Deploy the binary to a running VM via SCP
deploy-host target=TARGET:
    scp -P {{VM_PORT}} target/{{target}}/release/genesis-rs {{VM_USER}}@{{VM_HOST}}:/tmp/genesis-rs
    @echo "Binary deployed to /tmp/genesis-rs on VM"

# --- AUTOMATED E2E VM TESTING (QEMU Cloud-Image) ---

# Provision tests requirements
provision-vms: provision-debian provision-arch provision-raspbian
	@echo "All VMs provisioned successfully."

provision-debian:
	@echo "Provisioning Debian Cloud VM..."
	mkdir -p tests/e2e/cloud-init
	wget -q -nc -c -O tests/e2e/debian.qcow2 https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
	qemu-img create -f qcow2 -F qcow2 -b debian.qcow2 tests/e2e/debian-test.qcow2 || true
	mkisofs -output tests/e2e/cloud-init/seed.iso -volid cidata -joliet -rock tests/e2e/cloud-init/user-data tests/e2e/cloud-init/meta-data

provision-arch:
	@echo "Provisioning Arch Linux Cloud VM..."
	mkdir -p tests/e2e/cloud-init
	wget -q -nc -c -O tests/e2e/arch.qcow2 https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2
	qemu-img create -f qcow2 -F qcow2 -b arch.qcow2 tests/e2e/arch-test.qcow2 || true
	mkisofs -output tests/e2e/cloud-init/seed.iso -volid cidata -joliet -rock tests/e2e/cloud-init/user-data tests/e2e/cloud-init/meta-data

provision-raspbian:
	@echo "Provisioning Raspbian-like (Debian ARM64) Cloud VM..."
	mkdir -p tests/e2e/cloud-init
	wget -q -nc -c -O tests/e2e/raspbian.qcow2 https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-arm64.qcow2
	qemu-img create -f qcow2 -F qcow2 -b raspbian.qcow2 tests/e2e/raspbian-test.qcow2 || true
	mkisofs -output tests/e2e/cloud-init/seed.iso -volid cidata -joliet -rock tests/e2e/cloud-init/user-data tests/e2e/cloud-init/meta-data
	# Prepare padded EFI firmware (64MB required by QEMU virt machine)
	dd if=/dev/zero of=tests/e2e/EFI_CODE.fd bs=1M count=64 status=none
	dd if=/usr/share/edk2/aarch64/QEMU_EFI.fd of=tests/e2e/EFI_CODE.fd conv=notrunc status=none
	dd if=/dev/zero of=tests/e2e/EFI_VARS.fd bs=1M count=64 status=none

# Boot debian VM
boot-debian:
	qemu-system-x86_64 -m 2G -smp 2 -daemonize -enable-kvm -cpu host -display none \
		-device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22221-:22 \
		-drive file=tests/e2e/debian-test.qcow2,format=qcow2,if=virtio,cache=unsafe \
		-drive file=tests/e2e/cloud-init/seed.iso,format=raw,if=virtio \
		-device virtio-rng-pci
	@echo "Debian booted (Headless, KVM, Port 22221)."

# Deploy binary to Debian VM
deploy-debian target=TARGET:
	scp -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -P 22221 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
	ssh -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -p 22221 genesis@localhost "/tmp/genesis-rs bootstrap"

# Boot Arch Linux VM
boot-arch:
	qemu-system-x86_64 -m 2G -smp 2 -daemonize -enable-kvm -cpu host -display none \
		-device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22222-:22 \
		-drive file=tests/e2e/arch-test.qcow2,format=qcow2,if=virtio,cache=unsafe \
		-drive file=tests/e2e/cloud-init/seed.iso,format=raw,if=virtio \
		-device virtio-rng-pci
	@echo "Arch Linux booted (Headless, KVM, Port 22222)."

# Deploy binary to Arch Linux VM
deploy-arch target=TARGET:
	scp -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -P 22222 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
	ssh -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -p 22222 genesis@localhost "/tmp/genesis-rs bootstrap"

# Boot Raspbian VM (ARM64)
boot-raspbian:
	qemu-system-aarch64 -m 2G -smp 2 -daemonize -M virt -cpu max -display none \
		-drive if=pflash,format=raw,file=tests/e2e/EFI_CODE.fd,readonly=on \
		-drive if=pflash,format=raw,file=tests/e2e/EFI_VARS.fd \
		-device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22223-:22 \
		-drive file=tests/e2e/raspbian-test.qcow2,format=qcow2,if=virtio,cache=unsafe \
		-drive file=tests/e2e/cloud-init/seed.iso,format=raw,if=virtio \
		-device virtio-rng-pci
	@echo "Raspbian (ARM64) booted (Headless, TCG, Port 22223). This is optimized ARM emulation."

# Deploy binary to Raspbian VM (ARM64)
deploy-raspbian target=ARM_TARGET: build-arm
	scp -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -P 22223 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
	ssh -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -p 22223 genesis@localhost "/tmp/genesis-rs bootstrap"

# Run the E2E benchmark and output performance metrics
benchmark os="debian" target=TARGET:
	@OS_PORT=$(case "{{os}}" in "debian") echo "22221";; "arch") echo "22222";; "raspbian") echo "22223";; *) echo "0";; esac); \
	OS_TARGET=$(if [ "{{os}}" = "raspbian" ]; then echo "{{ARM_TARGET}}"; else echo "{{target}}"; fi); \
	if [ "$OS_PORT" = "0" ]; then echo "Unsupported OS: {{os}}"; exit 1; fi; \
	killall qemu-system-x86_64 qemu-system-aarch64 2>/dev/null || true; \
	START_BOOT=$(date +%s%3N); \
	just boot-{{os}} > /dev/null 2>&1; \
	echo -n "Waiting for SSH on port ${OS_PORT}..."; \
	END_BOOT=""; \
	for i in $(seq 1 120); do \
		if ssh -i tests/e2e/e2e_key -p ${OS_PORT} genesis@localhost -o StrictHostKeyChecking=no -o ConnectTimeout=1 echo "up" > /dev/null 2>&1; then \
			END_BOOT=$(date +%s%3N); \
			echo " Ready."; \
			break; \
		fi; \
		echo -n "."; \
		sleep 2; \
	done; \
	if [ -z "$END_BOOT" ]; then echo "Boot failed"; exit 1; fi; \
	BOOT_TIME=$((END_BOOT - START_BOOT)); \
	START_DEPLOY=$(date +%s%3N); \
	just deploy-{{os}} target=${OS_TARGET}; \
	END_DEPLOY=$(date +%s%3N); \
	DEPLOY_TIME=$((END_DEPLOY - START_DEPLOY)); \
	killall qemu-system-x86_64 2>/dev/null || true; \
	echo "--- BENCHMARK RESULTS ({{os}}) ---"; \
	echo "Boot Time:   ${BOOT_TIME}ms"; \
	echo "Deploy Time: ${DEPLOY_TIME}ms"; \
	echo "Total E2E:   $((BOOT_TIME + DEPLOY_TIME))ms"


# Kill all background VMs
clean-vms:
	killall qemu-system-x86_64 qemu-system-aarch64 2>/dev/null || true
	@echo "All VMs terminated."


