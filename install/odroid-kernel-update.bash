#!/bin/bash

function say() {
    $(echo "$@" | festival --tts) || true
}

(
    set -e

    if [ ! -d /root/linux ]; then
        # Cloning the repository for the kernel from the right branch
        git clone --depth 1 https://github.com/hardkernel/linux -b odroidxu4-4.14.y /root/linux
    fi

    cd /root/linux

    # Update the repo
    git pull

    # Build configuration and build kernel + modules
    make odroidxu4_defconfig
    make -j8

    # Install modules and images
    make modules_install
    cp -f arch/arm/boot/zImage /media/boot
    cp -f arch/arm/boot/dts/exynos5422-odroidxu3.dtb /media/boot
    cp -f arch/arm/boot/dts/exynos5422-odroidxu4.dtb /media/boot
    cp -f arch/arm/boot/dts/exynos5422-odroidxu3-lite.dtb /media/boot

    # Finalize writes on disk
    sync

    # Update initramfs (could be optional)
    cp .config /boot/config-$(make kernelrelease)
    update-initramfs -c -k $(make kernelrelease)
    mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/initrd.img-$(make kernelrelease) /boot/uInitrd-$(make kernelrelease)
    cp /boot/uInitrd-$(make kernelrelease) /media/boot/uInitrd

    # Finalize writes on disk
    sync

    echo "Kernel updated! Reboot now to boot into the new kernel!"
    say "Kernel updated! Reboot now to boot into the new kernel!" || true
)
