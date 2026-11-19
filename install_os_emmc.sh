#!/bin/sh
# Cai OS (rootfs + /boot/Image + dtb) vao eMMC cua OneKiwi RZ/V2H.
# Chay TREN BOARD, khi board dang boot Linux tu the microSD (hoac USB).
#
#   sh install_os_emmc.sh /duong/dan/core-image-weston-onekiwi-rzv2h-4gb.rootfs-XXXX.tar.bz2
#
# Ket qua: /dev/mmcblk0p1 (500M ext4, du phong) + /dev/mmcblk0p2 (rootfs, phan con lai).
# U-Boot (sd0load) doc mmc 0:2 /boot/Image + /boot/onekiwi-rzv2h-*.dtb, root=/dev/mmcblk0p2.
set -e

TAR="$1"
[ -f "$TAR" ] || { echo "Cach dung: sh $0 <rootfs.tar.bz2>"; exit 1; }

# Tim eMMC: thiet bi mmcblkN co mmcblkNboot0 (the SD khong co boot partition)
EMMC=""
for d in /dev/mmcblk[0-9]; do
    [ -b "${d}boot0" ] && EMMC="$d" && break
done
[ -n "$EMMC" ] || { echo "Khong tim thay eMMC (khong co mmcblk*boot0)"; exit 1; }

ROOTDEV=$(awk '$2=="/" {print $1}' /proc/mounts | head -1)
case "$ROOTDEV" in
    ${EMMC}*) echo "Rootfs hien tai dang chay tren $EMMC - phai boot tu microSD/USB truoc!"; exit 1;;
esac

SIZE=$(( $(cat /sys/block/$(basename $EMMC)/size) * 512 ))
echo "eMMC         : $EMMC ($((SIZE/1024/1024)) MB)"
echo "Rootfs dang chay: $ROOTDEV"
echo "File rootfs  : $TAR"
echo
echo "!!! TOAN BO DU LIEU tren vung user cua $EMMC se bi XOA (boot partition chua bootloader KHONG bi dung)."
printf "Go YES de tiep tuc: "
read ans
[ "$ans" = "YES" ] || exit 1

umount ${EMMC}p* 2>/dev/null || true

if command -v sfdisk >/dev/null 2>&1; then
sfdisk "$EMMC" <<EOF
label: dos
,500M,83
,,83
EOF
else
# fdisk: dong trong = chap nhan gia tri mac dinh (first/last sector)
fdisk "$EMMC" <<EOF
o
n
p
1

+500M
n
p
2


w
EOF
fi
sync; sleep 1
partprobe "$EMMC" 2>/dev/null || blockdev --rereadpt "$EMMC" 2>/dev/null || true
sleep 1

mkfs.ext4 -F -L data   ${EMMC}p1
mkfs.ext4 -F -L rootfs ${EMMC}p2

MNT=/mnt/emmc_root
mkdir -p $MNT
mount ${EMMC}p2 $MNT

echo "Dang giai nen rootfs (vai phut)..."
case "$TAR" in
    *.tar.bz2) tar -xjpf "$TAR" -C $MNT ;;
    *.tar.gz)  tar -xzpf "$TAR" -C $MNT ;;
    *)         tar -xpf  "$TAR" -C $MNT ;;
esac
sync

echo
ls -lh $MNT/boot/ || true
if ls $MNT/boot/Image >/dev/null 2>&1 && ls $MNT/boot/onekiwi-rzv2h-*.dtb >/dev/null 2>&1; then
    echo "[OK] Co /boot/Image va dtb."
else
    echo "[CANH BAO] Thieu /boot/Image hoac dtb trong rootfs - copy tay tu deploy/images vao $MNT/boot/"
fi
df -h $MNT
umount $MNT
sync
echo
echo "[XONG] Tat nguon, rut microSD/USB, bat lai -> boot hoan toan tu eMMC."
