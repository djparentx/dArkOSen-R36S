# Recovery Service Installer

Creates `/etc/systemd/system/recovery-check.service`
- launches `recovery-runner.sh` at boot before emulation station loads

Creates `recovery-runner.sh`
- launches `/boot/recovery.sh` if it exists

`/boot/recovery.sh` can be literally any executable script allowing for system repairs or changes at boot time.

# dArkOSen dtb patcher

- place in tools and run to patch your original dtb for use with dArkOSen
- creates *.dtb.bak in case of failure
- adds the following to CPU OPP values:

		opp-1368000000 {
			opp-hz = <0x00 0x518a0600>;
			opp-microvolt = <0x149970 0x149970 0x149970>;
			opp-microvolt-L0 = <0x149970 0x149970 0x149970>;
			opp-microvolt-L1 = <0x149970 0x149970 0x149970>;
			opp-microvolt-L2 = <0x149970 0x149970 0x149970>;
			opp-microvolt-L3 = <0x149970 0x149970 0x149970>;
			clock-latency-ns = <0x9c40>;
		};

		opp-1416000000 {
			opp-hz = <0x00 0x54667200>;
			opp-microvolt = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L0 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L1 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L2 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L3 = <0x155cc0 0x155cc0 0x155cc0>;
			clock-latency-ns = <0x9c40>;
		};

		opp-1440000000 {
			opp-hz = <0x00 0x55d4a800>;
			opp-microvolt = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L0 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L1 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L2 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L3 = <0x155cc0 0x155cc0 0x155cc0>;
			clock-latency-ns = <0x9c40>;
		};

		opp-1464000000 {
			opp-hz = <0x00 0x5742de00>;
			opp-microvolt = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L0 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L1 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L2 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L3 = <0x155cc0 0x155cc0 0x155cc0>;
			clock-latency-ns = <0x9c40>;
		};

		opp-1488000000 {
			opp-hz = <0x00 0x58b11400>;
			opp-microvolt = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L0 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L1 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L2 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L3 = <0x155cc0 0x155cc0 0x155cc0>;
			clock-latency-ns = <0x9c40>;
		};

		opp-1512000000 {
			opp-hz = <0x00 0x5a1f4a00>;
			opp-microvolt = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L0 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L1 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L2 = <0x155cc0 0x155cc0 0x155cc0>;
			opp-microvolt-L3 = <0x155cc0 0x155cc0 0x155cc0>;
			clock-latency-ns = <0x9c40>;
		};

- and the following to GPU OPP vlaues:

		opp-600000000 {
			opp-microvolt = <0x115b5c>;
			opp-microvolt-L0 = <0x10f9b4>;
			opp-hz = <0x00 0x23c34600>;
		};
