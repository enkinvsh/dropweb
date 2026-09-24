package main

// Regression: when a setup payload fails to decode mid-session (e.g. an
// invalid CIDR in tun.route-address fails netip.Prefix.UnmarshalText),
// handleSetupConfig must keep the live config and report the error, instead of
// replacing it with the rule-less default config (which routes all DIRECT).

import (
	"testing"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

func setupPayloadWithRoute(routeAddress string) string {
	return `{"config":{"mode":"rule","log-level":"silent","mixed-port":0,` +
		`"proxies":[{"name":"live-proxy","type":"socks5","server":"127.0.0.1","port":1080}],` +
		`"rules":["MATCH,live-proxy"],` +
		`"tun":{"enable":false,"stack":"mixed","route-address":[` + routeAddress + `]}},` +
		`"selected-map":{},"test-url":"https://www.gstatic.com/generate_204"}`
}

func TestSetupConfigDecodeErrorKeepsLiveConfig(t *testing.T) {
	constant.SetHomeDir(t.TempDir())
	prevCfg, prevRunning := currentConfig, isRunning
	isRunning = false
	t.Cleanup(func() { currentConfig, isRunning = prevCfg, prevRunning })

	if msg := handleSetupConfig([]byte(setupPayloadWithRoute(`"0.0.0.0/1"`))); msg != "" {
		t.Fatalf("baseline setupConfig failed: %s", msg)
	}
	if _, ok := tunnel.Proxies()["live-proxy"]; !ok {
		t.Fatalf("baseline: live-proxy not applied")
	}
	live := currentConfig

	msg := handleSetupConfig([]byte(setupPayloadWithRoute(`"10.0.0.0"`))) // missing /mask
	if msg == "" {
		t.Fatalf("invalid route-address unexpectedly accepted")
	}
	t.Logf("setupConfig error reported to Dart: %s", msg)
	if currentConfig != live {
		t.Errorf("live config was REPLACED after a rejected payload (rules now %d, proxy present=%v)",
			len(tunnel.Rules()), tunnel.Proxies()["live-proxy"] != nil)
	}
	if _, ok := tunnel.Proxies()["live-proxy"]; !ok {
		t.Errorf("live proxy vanished after a rejected payload: the tunnel now runs the default config (no rules => DIRECT)")
	}
}
