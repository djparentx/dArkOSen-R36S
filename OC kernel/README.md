# dArkOSen Custom Kernel — Change Log

## Source
- Base: `christianhaitian/linux`, branch `rg351`
- Defconfig: `rg351p_tweaked_defconfig`
- Toolchain: `gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu`
  - Source: `github.com/rockchip-toybrick/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu`, branch `develop-11.0`
  - Local path: `~/toolchains/linaro-6.3.1`
  - CROSS_COMPILE prefix: `~/toolchains/linaro-6.3.1/bin/aarch64-linux-gnu-`

## Change 1: CPU Overclock (credit to lcdyk)

**File modified:** `drivers/cpufreq/cpufreq-dt.c`
**File modified:** `drivers/soc/rockchip/rockchip_opp_select.c`

**Mechanism:** two `early_param` cmdline hooks, applied to `policy->max` only — never touches `policy->cpuinfo.max_freq`, so the real DTB-provided ceiling is always honestly reported to userspace.

- `max_cpufreq=<MHz>` — caps policy max. If unset, no cap beyond DTB OPP table + stock bin ceiling. If the requested value exceeds the DTB ceiling, it is ignored with a kernel warning (no fabricated ceiling).
- `boot_cpufreq=<MHz>` — temporary boot-time floor, default 1296000 kHz if unset. Set to `0` to disable the floor. Intended to be raised post-boot by a userspace tool (e.g. r36-tuner/cpu-manager); kernel does nothing after init.

**Diff (3 insertion points):** drivers/cpufreq/cpufreq-dt.c

1. After `#include <linux/err.h>`:
```c
#include <linux/kernel.h>
```

2. After `resources_available()` function, before `static int cpufreq_init(...)`:
```c
static unsigned int darkosen_oc_max_cpufreq_khz;
static unsigned int darkosen_oc_boot_cpufreq_khz = 1296000;
static bool darkosen_oc_boot_cpufreq_set;

static int __init darkosen_oc_max_cpufreq_setup(char *str)
{
	unsigned int mhz;

	if (kstrtouint(str, 10, &mhz))
		return 0;

	darkosen_oc_max_cpufreq_khz = mhz * 1000;
	return 1;
}
early_param("max_cpufreq", darkosen_oc_max_cpufreq_setup);

static int __init darkosen_oc_boot_cpufreq_setup(char *str)
{
	unsigned int mhz;

	if (kstrtouint(str, 10, &mhz))
		return 0;

	darkosen_oc_boot_cpufreq_khz = mhz * 1000;
	darkosen_oc_boot_cpufreq_set = true;
	return 1;
}
early_param("boot_cpufreq", darkosen_oc_boot_cpufreq_setup);

static void darkosen_oc_apply_cmdline(struct cpufreq_policy *policy)
{
	unsigned int dtb_max = policy->cpuinfo.max_freq;
	unsigned int cap = dtb_max;

	if (darkosen_oc_max_cpufreq_khz) {
		if (darkosen_oc_max_cpufreq_khz > dtb_max) {
			pr_warn("darkosen-oc: max_cpufreq=%u exceeds DTB ceiling %u kHz, ignoring\n",
				darkosen_oc_max_cpufreq_khz, dtb_max);
		} else {
			cap = darkosen_oc_max_cpufreq_khz;
		}
	}

	if (darkosen_oc_boot_cpufreq_khz && cap > darkosen_oc_boot_cpufreq_khz)
		cap = darkosen_oc_boot_cpufreq_khz;

	policy->max = cap;

	if (darkosen_oc_boot_cpufreq_set || darkosen_oc_max_cpufreq_khz)
		pr_info("darkosen-oc: policy->max set to %u kHz (dtb ceiling %u kHz)\n",
			cap, dtb_max);
}
```

3. In `cpufreq_init()`, immediately after the `cpufreq_table_validate_and_show()` error-check block, before the `/* Support turbo/boost mode */` comment:
```c
	darkosen_oc_apply_cmdline(policy);
```

**Companion piece (separate from kernel, already implemented by user in bash, not part of this session's kernel diff):** per-device DTB OPP table patching — raises `rockchip,max-volt` and `DCDC_REG2 regulator-max-microvolt` to 1400000 µV, adds new opp nodes for 1368–1512 MHz steps. This is what actually makes the higher frequencies exist for `max_cpufreq=` to select; the kernel patch above only controls which of the DTB-provided frequencies get used.


**Diff (4 insertion points):** drivers/soc/rockchip/rockchip_opp_select.c

1. After the pvtm_config struct definition (before #define PVTM_CH_MAX), around line 50-56:
```c
cstatic int opp_bin_sel;
static unsigned long darkosen_max_cpufreq_khz = 1296000;
static int __init darkosen_opp_bin_sel_setup(char *str)
{
	unsigned long cpufreq;
	int r;

	if (str == NULL) {
		opp_bin_sel = 13;
		return 0;
	}

	r = kstrtoul(str, 10, &cpufreq);
	if (r)
		return r;

	darkosen_max_cpufreq_khz = cpufreq * 1000;

	switch (cpufreq) {
	case 408:
		opp_bin_sel = 39;
		break;
	case 600:
		opp_bin_sel = 35;
		break;
	case 1008:
		opp_bin_sel = 20;
		break;
	case 1200:
		opp_bin_sel = 16;
		break;
	case 1296:
		opp_bin_sel = 13;
		break;
	case 1368:
		opp_bin_sel = 10;
		break;
	case 1416:
		opp_bin_sel = 8;
		break;
	case 1440:
		opp_bin_sel = 7;
		break;
	case 1464:
		opp_bin_sel = 6;
		break;
	case 1488:
		opp_bin_sel = 5;
		break;
	case 1512:
		opp_bin_sel = 4;
		break;
	default:
		pr_info("darkosen-oc: no bin-sel mapping for %lu MHz, using 1296 default\n",
			cpufreq);
		opp_bin_sel = 13;
		break;
	}

	pr_info("darkosen-oc: cpufreq %lu, max_cpufreq_khz %lu, opp_bin_sel %d\n",
		cpufreq, darkosen_max_cpufreq_khz, opp_bin_sel);

	return 0;
}

__setup("max_cpufreq=", darkosen_opp_bin_sel_setup);
```

2. Inside rockchip_of_get_bin_sel(), right after the existing if (!ret) dev_info(...) block, before the closing } at line 511:

```c
	if (!strncmp(dev_name(dev), "cpu0", 4) && opp_bin_sel) {
		*scale_sel = opp_bin_sel;
		dev_info(dev, "darkosen-oc: bin-scale override=%d, dev %s\n",
			*scale_sel, dev_name(dev));
	}
```
	
3. Inside rockchip_adjust_power_scale(), right after of_property_read_u32(np, "rockchip,avs-scale", &avs_scale); (line 727):
   
```c
	if (!strncmp(dev_name(dev), "cpu0", 4) && opp_bin_sel) {
		dev_info(dev, "darkosen-oc: avs_scale override, was %d, maxfreq %ld\n",
			avs_scale, darkosen_max_cpufreq_khz);
		avs_scale = opp_bin_sel;

	}`
```

4. Two floor-up insertions — before each dev_info(dev, "avs scale_rate=%lu\n", scale_rate); (line 777) and dev_info(dev, "scale_rate=%lu\n", scale_rate); (line 791), add immediately before each:
   
```c
			if (darkosen_max_cpufreq_khz > 0 && (darkosen_max_cpufreq_khz * 1000) > scale_rate)
				scale_rate = darkosen_max_cpufreq_khz * 1000;`
```

## Change 2: USB gadget mode — mass storage function added

**Changes to .config:** 
```c
CONFIG_USB_F_MASS_STORAGE=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_SERIAL=y
CONFIG_USB_CONFIGFS_ECM=y
CONFIG_USB_CONFIGFS_ECM_SUBSET=y
CONFIG_USB_CONFIGFS_MASS_STORAGE=y
CONFIG_USB_CONFIGFS_RNDIS=y
CONFIG_USB_CONFIGFS_EEM=y
CONFIG_USB_CONFIGFS_F_HID=y
CONFIG_CONFIGFS_FS=y
# CONFIG_USB_MASS_STORAGE is not set
```
