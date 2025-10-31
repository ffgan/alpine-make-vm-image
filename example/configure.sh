#!/bin/sh

_step_counter=0
step() {
	_step_counter=$(( _step_counter + 1 ))
	printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}


sed -i '/^#ttyS0::respawn/s/^#//' /etc/inittab
apk update
apk add --no-cache grub-efi efibootmgr

if [ -d /boot/efi ]; then
	EFI_DIR=/boot/efi
else
	EFI_DIR=/boot
	mkdir -p /boot/EFI
fi
grub-install --target=riscv64-efi --efi-directory="$EFI_DIR" --bootloader-id=Alpine --removable
cat > /etc/default/grub <<'EOF'
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="rootfstype=ext4 modules=kms,scsi,virtio console=ttyS0"
GRUB_TERMINAL_INPUT=console
GRUB_TERMINAL_OUTPUT=console
EOF
grub-mkconfig -o /boot/grub/grub.cfg
mkdir -p "$EFI_DIR/EFI/BOOT"
if [ -f "$EFI_DIR/EFI/Alpine/grubriscv64.efi" ]; then
	cp "$EFI_DIR/EFI/Alpine/grubriscv64.efi" "$EFI_DIR/EFI/BOOT/bootriscv64.efi"
fi


step 'Set up qemu-guest-agent'
cat > /etc/conf.d/qemu-guest-agent <<-EOF
GA_METHOD="virtio-serial"
GA_PATH="/dev/virtio-ports/org.qemu.guest_agent.0"
EOF

step 'Adjust rc.conf'
sed -Ei \
	-e 's/^[# ](rc_depend_strict)=.*/\1=NO/' \
	-e 's/^[# ](rc_logger)=.*/\1=YES/' \
	-e 's/^[# ](unicode)=.*/\1=YES/' \
	/etc/rc.conf

step 'Enable services'
rc-update add qemu-guest-agent default
rc-update add cloud-init default
rc-update add cloud-init-local default
rc-update add cloud-config default
rc-update add cloud-final default
rc-update add networking default
rc-update add sshd default
rc-update add acpid default