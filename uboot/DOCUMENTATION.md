# dArkOSen U-Boot Boot Logo Fix

## Baseline
- Repo: `christianhaitian/RG351MP-u-boot`
- Branch: `odroidgoA-v2017.09`
- Clean, unmodified clone.

## Symptom
`logo.bmp` (1024x768, 24bpp) displayed correctly for roughly the top portion,
then was corrupted/mirrored for the remainder.

## Root causes

1. `LCD_LOGO_SIZE` (2 MB) was smaller than the actual logo file (~2.36 MB),
   which falsely triggered a "file not found" fallback branch. That branch
   attempted an SPI-flash read and unzip, overwriting the already-loaded,
   valid logo in memory before it was displayed.
2. `DRM_ROCKCHIP_FB_SIZE` evaluated to `0` (since
   `CONFIG_DRM_ROCKCHIP_VIDEO_FRAMEBUFFER` is not set in this build), which
   made the logo's load address (`bmp_mem`) identical to the live display
   framebuffer's address. The BMP decoder then read and wrote overlapping
   memory, corrupting the image partway through decoding.

### 1. `include/rockchip_display_cmds.h`

```diff
-#define	LCD_LOGO_SIZE		(2 * 1024 * 1024)
+#define	LCD_LOGO_SIZE		(3 * 1024 * 1024)
```

### 2. `drivers/video/drm/rockchip_display_cmds.c`

```diff
 unsigned long lcd_get_mem(void)
 {
-	return get_drm_memory() + DRM_ROCKCHIP_FB_SIZE;
+	if (lcd_init())
+		return get_drm_memory() + (1024 * 768 * 4);
+	return get_drm_memory() + (lcd->w * lcd->h * (lcd->bpp / 8));
 }
```

```diff
 	/* bitmap load address */
-	bmp_mem = get_drm_memory() + DRM_ROCKCHIP_FB_SIZE;
+	bmp_mem = get_drm_memory() + (lcd->w * lcd->h * (lcd->bpp / 8));
```

## Build & flash

```bash
cd ~/build/RG351MP-u-boot
./make.sh odroidgoa
scp sd_fuse/uboot.img ark@<device-ip>:/tmp/uboot.img
ssh ark@<device-ip> "sudo dd if=/tmp/uboot.img of=/dev/mmcblk0 bs=512 seek=16384 conv=fsync"
```

Only `uboot.img` needs flashing — `idbloader.img` and `trust.img` were
confirmed byte-identical to a known-working reference build and were never
modified.

## Verified working on
- R36H ProMax (1024x768 panel)
- R36S V21-2551 (640x480 panel)
