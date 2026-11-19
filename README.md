# rzv-flash

Flash the OneKiwi RZ/V2H bootloader (BL2 + FIP/U-Boot) over UART (SCIF download mode),
either to xSPI flash or to eMMC Boot Partition 1.

```
pip3 install pyserial alive-progress
./flash.py --spi --4gb      # xSPI flash
./flash.py --spi --8gb
./flash.py --spi --16gb
./flash.py --mmc --4gb      # eMMC (no SPI flash needed)
./flash.py --mmc --8gb
./flash.py --mmc --16gb
./flash.py --spi --4gb --serial_port /dev/ttyUSB1
```

Copy into this folder from `build/tmp/deploy/images/onekiwi-rzv2h-<size>/`:

| Mode | Files |
|---|---|
| `--spi` | `Flash_Writer_SCIF_RZV2H_DEV_INTERNAL_MEMORY.mot`, `bl2_bp_spi-onekiwi-rzv2h-<size>.srec`, `fip-onekiwi-rzv2h-<size>.srec` |
| `--mmc` | `Flash_Writer_SCIF_RZV2H_DEV_INTERNAL_MEMORY.mot`, `bl2_bp_mmc-onekiwi-rzv2h-<size>.srec`, `fip-onekiwi-rzv2h-<size>.srec` |

Start the script with the board powered off, then power it on when asked.

### DIP switch (OneKiwi EVK SOM V2H, labels BOOT3 BOOT2 BOOT1 BOOT0 = SW1..SW4)
Measured on the board. Check the `BL2: SYS_LSI_MODE` line in the boot log:
the low 3 bits are the real MD_BOOT[2:0] level (5 = eMMC 1.8V, 6 = xSPI 1.8V).

| Mode | SW1 | SW2 | SW3 | SW4 | Label | SYS_LSI_MODE & 7 |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| SCIF download (flashing) | down | down | up | up | 0 0 1 1 | 3 |
| Boot from xSPI 1.8V | down | down | down | up | 0 0 0 1 | 6 |
| Boot from eMMC 1.8V | down | up | up | up | 0 1 1 1 | 5 |

### xSPI RZ/V2H
| File name | Address to load to RAM | Address to save to ROM |
|---|:---:|:---:|
| bl2_bp_spi-name.srec | 8101E00 | 00000 |
| fip-name.srec | 00000 | 60000 |

### eMMC RZ/V2H
EXT_CSD setup: `EM_SECSD` index `b1` = `02`, index `b3` = `08` (boot from Boot Partition 1).

| File name | Partition to save to eMMC | Address to save to eMMC (sector) | Address to load to RAM |
|---|:---:|:---:|:---:|
| bl2_bp_mmc-name.srec | 1 | 00000001 | 8101E00 |
| fip-name.srec | 1 | 00000300 | 00000000 |

FIP sector 0x300 = byte offset 0x60000 (`RZV2H_EMMC_FIP_BASE` in TF-A).

### Install the OS to eMMC
Boot Linux from a microSD/USB first, then on the board:
```
sh install_os_emmc.sh core-image-weston-onekiwi-rzv2h-<size>.rootfs-<date>.tar.bz2
```
It partitions the eMMC user area (p1 500M, p2 rootfs), extracts the rootfs and checks `/boot/Image` + dtb.
U-Boot `sd0load` then boots `mmc 0:2` when no microSD is inserted.
