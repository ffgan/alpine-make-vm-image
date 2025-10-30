#!/bin/sh

_step_counter=0
step() {
	_step_counter=$(( _step_counter + 1 ))
	printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

uname -a

step 'Set up timezone'
setup-timezone -z Europe/Prague

step 'Set up networking'
cat > /etc/network/interfaces <<-EOF
	iface lo inet loopback
	iface eth0 inet dhcp
EOF
ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0

step 'Adjust rc.conf'
sed -Ei \
	-e 's/^[# ](rc_depend_strict)=.*/\1=NO/' \
	-e 's/^[# ](rc_logger)=.*/\1=YES/' \
	-e 's/^[# ](unicode)=.*/\1=YES/' \
	/etc/rc.conf

step 'Enable services'
rc-update add acpid default
rc-update add chronyd default
rc-update add crond default
rc-update add net.eth0 default
rc-update add net.lo boot
rc-update add termencoding boot

step 'List /usr/local/bin'
ls -la /usr/local/bin

if [ "$(uname -m)" = "riscv64" ]; then
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
fi