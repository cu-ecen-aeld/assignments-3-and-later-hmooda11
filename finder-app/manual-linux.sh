#!/bin/bash
# Script to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$(realpath $1)
    echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
    echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # Deep cleaning the kernel build tree and removing .config file with any existing configurations
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper

    # Configure for the "virt" arm board that is simulated by QEMU
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

    # Building a kernel image for booting with QEMU since QEMU does not boot up automatically
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all

    # Build any kernel modules (optional)
    # make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules

    # Build the device tree (optional)
    # make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs

    echo "Adding the Image in outdir"
    cp ./arch/${ARCH}/boot/Image ${OUTDIR}/
fi

echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
    echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

mkdir -p ${OUTDIR}/rootfs
cd ${OUTDIR}/rootfs

# Create necessary base directories
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # Configure busybox
    make distclean
    make defconfig
    # Enable static build (optional)
    # sed -i 's/.*CONFIG_STATIC.*/CONFIG_STATIC=y/' .config
else
    cd busybox
fi



# Make and install busybox
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

cd ${OUTDIR}/rootfs

echo "Library dependencies"

${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter" || true
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library" || true


# Add library dependencies to rootfs
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
echo "Sysroot is at ${SYSROOT}"

mkdir -p lib64
sudo cp -L ${SYSROOT}/lib/ld-linux-aarch64.so.1 lib
sudo cp -L ${SYSROOT}/lib64/libm.so.6 lib64
sudo cp -L ${SYSROOT}/lib64/libresolv.so.2 lib64
sudo cp -L ${SYSROOT}/lib64/libc.so.6 lib64

# Make device nodes
sudo mknod -m 666 dev/null c 1 3 || true
sudo mknod -m 600 dev/console c 5 1 || true

# Clean and build the writer utility
cd $FINDER_APP_DIR/
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# Copy the finder related scripts and executables to the /home directory on the target rootfs
cp $FINDER_APP_DIR/finder-test.sh ${OUTDIR}/rootfs/home
cp -rL $FINDER_APP_DIR/conf ${OUTDIR}/rootfs/home
cp $FINDER_APP_DIR/finder.sh ${OUTDIR}/rootfs/home
cp $FINDER_APP_DIR/writer ${OUTDIR}/rootfs/home
cp $FINDER_APP_DIR/autorun-qemu.sh ${OUTDIR}/rootfs/home

cp ${FINDER_APP_DIR}/writer ${OUTDIR}/rootfs/home/writer
cp ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home/finder.sh
cp ${FINDER_APP_DIR}/finder-test.sh ${OUTDIR}/rootfs/home/finder-test.sh
#sudo mkdir -p ${OUTDIR}/rootfs/home/conf/
echo ${FINDER_APP_DIR}
echo ${OUTDIR}
ls ${OUTDIR}/rootfs/home/conf 
#ls -l /tmp/aeld/rootfs/home/conf



#cp /home/hmooda11/assignment-2-hmooda11/conf/username.txt /tmp/aeld/rootfs/conf/ || true


echo "root/"
ls -l /${OUTDIR}/rootfs/

echo "root/etc"
ls -l ${OUTDIR}/rootfs/etc

echo "mkdir"
sudo mkdir ${OUTDIR}/rootfs/etc/finder-app

echo "mkdir"
sudo mkdir ${OUTDIR}/rootfs/etc/finder-app/conf

echo "etc"
ls -l ${OUTDIR}/rootfs/etc
#sudo cp /home/hmooda11/assignment-2-hmooda11/conf/username.txt /tmp/aeld/rootfs/etc/finder-app/conf/ || true

ls -l /tmp/aeld/rootfs/etc/finder-app/conf/ || true

#cp /home/hmooda11/assignment-2-hmooda11/conf/assignment.txt ${OUTDIR}/rootfs/home/conf/assignment.txt
#cp /home/hmooda11/assignment-2-hmooda11/autorun-qemu.sh ${OUTDIR}/rootfs/home/autorun-qemu.sh
sudo cp ${FINDER_APP_DIR}/conf/username.txt ${OUTDIR}/rootfs/etc/finder-app/conf/
sudo cp ${FINDER_APP_DIR}/conf/assignment.txt ${OUTDIR}/rootfs/etc/finder-app/conf/


# Ensure the /home directory exists
mkdir -p ${OUTDIR}/rootfs/home || true

# Copy the finder related scripts and executables
cp -a $FINDER_APP_DIR/finder-test.sh ${OUTDIR}/rootfs/home/ || true
cp -a $FINDER_APP_DIR/finder.sh ${OUTDIR}/rootfs/home/
cp -a $FINDER_APP_DIR/writer ${OUTDIR}/rootfs/home/ || true
cp -a $FINDER_APP_DIR/autorun-qemu.sh ${OUTDIR}/rootfs/home/ || true
cp -a $FINDER_APP_DIR/conf ${OUTDIR}/rootfs/home/ || true


# Modify finder-test.sh to reference conf/assignment.txt
sed -i 's|\.\./conf/assignment.txt|conf/assignment.txt|g' ${OUTDIR}/rootfs/home/finder-test.sh

# Make scripts executable
chmod +x ${OUTDIR}/rootfs/home/finder.sh
chmod +x ${OUTDIR}/rootfs/home/finder-test.sh
chmod +x ${OUTDIR}/rootfs/home/autorun-qemu.sh
chmod +x ${OUTDIR}/rootfs/home/writer

# Create the init script
echo "Creating init script"
cat << EOF > ${OUTDIR}/rootfs/init
#!/bin/sh
echo "Booting the system..."

# Mount necessary filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Run the autorun script
cd /home
./autorun-qemu.sh
EOF

# Make the init script executable
chmod +x ${OUTDIR}/rootfs/init

# Change ownership of the root directory
cd ${OUTDIR}/rootfs
sudo chown -R root:root *

# Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root 2> /dev/null | gzip -c > ${OUTDIR}/initramfs.cpio.gz

cp ${OUTDIR}/initramfs.cpio.gz /tmp/aesd-autograder/

# Confirm the copy was successful
if [ -e /tmp/aesd-autograder/initramfs.cpio.gz ]; then
    echo "initramfs.cpio.gz successfully copied to /tmp/aesd-autograder/"
else
    echo "Failed to copy initramfs.cpio.gz to /tmp/aesd-autograder/"
    exit 1
fi

echo "Success"

