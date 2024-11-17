# !/bin/bash
# Script to open qemu terminal.
# Author: Siddhant Jajoo.

set -e

OUTDIR=$1

if [ -z "${OUTDIR}" ]; then
    OUTDIR=/tmp/aeld
    echo "No outdir specified, using ${OUTDIR}"
fi

KERNEL_IMAGE=${OUTDIR}/Image
INITRD_IMAGE=${OUTDIR}/initramfs.cpio.gz

if [ ! -e ${KERNEL_IMAGE} ]; then
    echo "Missing kernel image at ${KERNEL_IMAGE}"
    exit 1
fi
if [ ! -e ${INITRD_IMAGE} ]; then
    echo "Missing initrd image at ${INITRD_IMAGE}"
    exit 1
fi


echo "Booting the kernel"
# See trick at https://superuser.com/a/1412150 to route serial port output to file
qemu-system-aarch64 -m 512M -M virt -cpu cortex-a53 -nographic -smp 1 \
    -kernel ${OUTDIR}/Image \
    -initrd ${OUTDIR}/initramfs.cpio.gz \
    -append "console=ttyAMA0 init=/sbin/init"




        
