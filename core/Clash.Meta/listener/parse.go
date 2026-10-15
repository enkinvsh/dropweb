package listener

import (
	"fmt"

	"github.com/metacubex/mihomo/common/structure"
	C "github.com/metacubex/mihomo/constant"
	IN "github.com/metacubex/mihomo/listener/inbound"
)

func ParseListener(mapping map[string]any) (C.InboundListener, error) {
	decoder := structure.NewDecoder(structure.Option{TagName: "inbound", WeaklyTypedInput: true, KeyReplacer: structure.DefaultKeyReplacer})
	proxyType, existType := mapping["type"].(string)
	if !existType {
		return nil, fmt.Errorf("missing type")
	}

	var (
		listener C.InboundListener
		err      error
	)
	switch proxyType {
	case "socks":
		socksOption := &IN.SocksOption{UDP: true}
		err = decoder.Decode(mapping, socksOption)
		if err != nil {
			return nil, err
		}
		listener, err = IN.NewSocks(socksOption)
	case "http":
		httpOption := &IN.HTTPOption{}
		err = decoder.Decode(mapping, httpOption)
		if err != nil {
			return nil, err
		}
		listener, err = IN.NewHTTP(httpOption)
	case "mixed":
		mixedOption := &IN.MixedOption{UDP: true}
		err = decoder.Decode(mapping, mixedOption)
		if err != nil {
			return nil, err
		}
		listener, err = IN.NewMixed(mixedOption)
	case "tunnel":
		tunnelOption := &IN.TunnelOption{}
		err = decoder.Decode(mapping, tunnelOption)
		if err != nil {
			return nil, err
		}
		listener, err = IN.NewTunnel(tunnelOption)
	case "tun":
		tunOption := &IN.TunOption{
			Stack:     C.TunGvisor,
			DNSHijack: []string{"0.0.0.0:53"}, // default hijack all dns query
		}
		err = decoder.Decode(mapping, tunOption)
		if err != nil {
			return nil, err
		}
		listener, err = IN.NewTun(tunOption)
	default:
		listener, err = parseExtraListener(proxyType, mapping, decoder)
	}
	return listener, err
}
