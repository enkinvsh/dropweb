//go:build no_extra_protocols

package adapter

import (
	"context"
	"fmt"

	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/common/structure"
	C "github.com/metacubex/mihomo/constant"
)

// extraProxyTypes are the protocols a slim build leaves out. A proxy of such
// a type still loads, so the groups and rules that name it keep working, but
// it never connects. Unknown types stay an error, as in the full build.
var extraProxyTypes = map[string]C.AdapterType{
	"ssr":         C.ShadowsocksR,
	"snell":       C.Snell,
	"hysteria":    C.Hysteria,
	"wireguard":   C.WireGuard,
	"tuic":        C.Tuic,
	"shadowquic":  C.ShadowQuic,
	"gost-relay":  C.GostRelay,
	"ssh":         C.Ssh,
	"mieru":       C.Mieru,
	"anytls":      C.AnyTLS,
	"sudoku":      C.Sudoku,
	"masque":      C.Masque,
	"trusttunnel": C.TrustTunnel,
	"openvpn":     C.OpenVPN,
	"tailscale":   C.Tailscale,
	"zerotier":    C.ZeroTier,
	"easytier":    C.EasyTier,
}

type unavailableOption struct {
	Name string `proxy:"name"`
}

func parseExtraProxy(proxyType string, mapping map[string]any, decoder *structure.Decoder, basicOption outbound.BasicOption) (outbound.ProxyAdapter, error) {
	tp, ok := extraProxyTypes[proxyType]
	if !ok {
		return nil, fmt.Errorf("unsupport proxy type: %s", proxyType)
	}
	option := &unavailableOption{}
	if err := decoder.Decode(mapping, option); err != nil {
		return nil, err
	}
	return &unavailableProxy{
		Base: outbound.NewBase(outbound.BaseOption{
			Name:         option.Name,
			Type:         tp,
			ProviderName: basicOption.ProviderName,
		}),
		err: fmt.Errorf("proxy type %s is not included in this build", proxyType),
	}, nil
}

type unavailableProxy struct {
	*outbound.Base
	err error
}

func (p *unavailableProxy) DialContext(context.Context, *C.Metadata) (C.Conn, error) {
	return nil, p.err
}

func (p *unavailableProxy) ListenPacketContext(context.Context, *C.Metadata) (C.PacketConn, error) {
	return nil, p.err
}
