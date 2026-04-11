# Justfile for genesis-rs

# Variables
TARGET := "x86_64-unknown-linux-musl"
VM_PORT := "22220"
VM_USER := "user"
VM_HOST := "localhost"

# Check the code for errors
check:
    cargo check

# Build the project (static binary via musl)
build target=TARGET:
    cargo build --release --target {{target}}

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
deploy target=TARGET: (build target)
    scp -P {{VM_PORT}} target/{{target}}/release/genesis-rs {{VM_USER}}@{{VM_HOST}}:/tmp/genesis-rs
    @echo "Binary deployed to /tmp/genesis-rs on VM"

# --- AUTOMATED E2E VM TESTING (QEMU Cloud-Image) ---

# Provision tests requirements
provision-vms: provision-debian provision-arch
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

# Boot debian VM
boot-debian:
	qemu-system-x86_64 -m 2G -smp 2 -daemonize -enable-kvm -cpu host \
		-device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22221-:22 \
		-drive file=tests/e2e/debian-test.qcow2,format=qcow2,if=virtio \
		-drive file=tests/e2e/cloud-init/seed.iso,format=raw,if=virtio
	@echo "Debian booted on background with KVM acceleration. Wait ~30-40s before deploy."

# Deploy binary to Debian VM
deploy-debian target=TARGET:
	scp -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -P 22221 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
	ssh -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -p 22221 genesis@localhost "/tmp/genesis-rs bootstrap"

# Boot Arch Linux VM
boot-arch:
	qemu-system-x86_64 -m 2G -smp 2 -daemonize -enable-kvm -cpu host \
		-device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22222-:22 \
		-drive file=tests/e2e/arch-test.qcow2,format=qcow2,if=virtio \
		-drive file=tests/e2e/cloud-init/seed.iso,format=raw,if=virtio
	@echo "Arch Linux booted on background with KVM acceleration (Port 22222). Wait ~30s."

# Deploy binary to Arch Linux VM
deploy-arch target=TARGET:
	scp -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -P 22222 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
	ssh -o StrictHostKeyChecking=no -i tests/e2e/e2e_key -p 22222 genesis@localhost "/tmp/genesis-rs bootstrap"

# Run the E2E benchmark and output performance metrics
benchmark os="debian" target=TARGET:
	@OS_PORT=$$(case "{{os}}" in "debian") echo "22221";; "arch") echo "22222";; *) echo "0";; esac); \
	if [ "$$OS_PORT" = "0" ]; then echo "Unsupported OS: {{os}}"; exit 1; fi; \
	@killall qemu-system-x86_64 2>/dev/null || true; \
	@START_BOOT=$$(date +%s%3N); \
	just boot-{{os}} > /dev/null 2>&1; \
	echo -n "Waiting for SSH on port $${OS_PORT}..."; \
	END_BOOT=""; \
	for i in $$(seq 1 30); do \
		if ssh -i tests/e2e/e2e_key -p $${OS_PORT} genesis@localhost -o StrictHostKeyChecking=no -o ConnectTimeout=1 echo "up" > /dev/null 2>&1; then \
			END_BOOT=$$(date +%s%3N); \
			echo " Ready."; \
			break; \
		fi; \
		echo -n "."; \
		sleep 2; \
	done; \
	if [ -z "$$END_BOOT" ]; then echo "Boot failed"; exit 1; fi; \
	BOOT_TIME=$$(($$END_BOOT - $$START_BOOT)); \
	START_DEPLOY=$$(date +%s%3N); \
	just deploy-{{os}} target={{target}} > /dev/null 2>&1; \
	END_DEPLOY=$$(date +%s%3N); \
	DEPLOY_TIME=$$(($$END_DEPLOY - $$START_DEPLOY)); \
	killall qemu-system-x86_64 2>/dev/null || true; \
	echo "--- BENCHMARK RESULTS ({{os}}) ---"; \
	echo "Boot Time:   $${BOOT_TIME}ms"; \
	echo "Deploy Time: $${DEPLOY_TIME}ms"; \
	echo "Total E2E:   $$(($$BOOT_TIME + $$DEPLOY_TIME))ms"


# Kill all background VMs
clean-vms:
	killall qemu-system-x86_64 2>/dev/null || true
	@echo "All VMs terminated."


