package features

func Tags() (tags []string) {
	if WithLowMemory {
		tags = append(tags, "with_low_memory")
	}
	if NoExtraProtocols {
		tags = append(tags, "no_extra_protocols")
	}
	if NoFakeTCP {
		tags = append(tags, "no_fake_tcp")
	}
	if NoTailscale {
		tags = append(tags, "no_tailscale")
	}
	if NoZeroTier {
		tags = append(tags, "no_zerotier")
	}
	if NoEasyTier {
		tags = append(tags, "no_easytier")
	}
	if WithGVisor {
		tags = append(tags, "with_gvisor")
	}
	return
}
