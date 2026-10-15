package convert

import (
	"encoding/json"
	"fmt"
	"net/url"
	"reflect"
	"strconv"
	"strings"
	"unicode"

	"go.yaml.in/yaml/v3"
)

// ConvertsSingBox convert SingBox subscribe proxies data to mihomo proxies config
func ConvertsSingBox(buf []byte) ([]map[string]any, error) {
	proxies := make([]map[string]any, 0)
	names := make(map[string]int, 200)

	config := SingConfig{}
	err := json.Unmarshal(buf, &config)
	if err != nil {
		return nil, err
	}

	for _, outbound := range config.Outbounds {
		scheme := outbound.Type
		switch scheme {
		case "hysteria":
			name := uniqueName(names, outbound.Tag)
			hysteria := make(map[string]any, 20)

			resolveBase(hysteria, name, scheme, outbound)
			resolveTls(hysteria, outbound.TLS)

			if outbound.Obfs != nil {
				hysteria["obfs"] = outbound.Obfs.Password
			}

			hysteria["auth_str"] = outbound.AuthStr

			up := outbound.Up
			down := outbound.Down
			if up == "" {
				up = strconv.Itoa(outbound.UpMbps)
			}
			if down == "" {
				down = strconv.Itoa(outbound.DownMbps)
			}
			hysteria["down"] = down
			hysteria["up"] = up

			proxies = append(proxies, hysteria)

		case "hysteria2":
			name := uniqueName(names, outbound.Tag)
			hysteria2 := make(map[string]any, 20)

			resolveBase(hysteria2, name, scheme, outbound)
			resolveTls(hysteria2, outbound.TLS)

			if outbound.Obfs != nil {
				hysteria2["obfs"] = outbound.Obfs.Type
				hysteria2["obfs-password"] = outbound.Obfs.Password
			}

			hysteria2["password"] = outbound.Password

			if outbound.DownMbps > 0 {
				hysteria2["down"] = outbound.DownMbps
			}
			if outbound.UpMbps > 0 {
				hysteria2["up"] = outbound.UpMbps
			}

			// Since sing-box 1.11.0
			serverPorts := outbound.ServerPorts
			if len(serverPorts) > 0 {
				for i, str := range serverPorts {
					serverPorts[i] = strings.Replace(str, ":", "-", 1)
				}
				hysteria2["ports"] = strings.Join(serverPorts, ",")
			}

			proxies = append(proxies, hysteria2)

		case "tuic":
			name := uniqueName(names, outbound.Tag)
			tuic := make(map[string]any, 20)

			resolveBase(tuic, name, scheme, outbound)

			tuic["uuid"] = outbound.UUID
			tuic["password"] = outbound.Password
			tuic["congestion-controller"] = outbound.CongestionController

			resolveTls(tuic, outbound.TLS)

			tuic["udp-relay-mode"] = outbound.UdpRelayMode
			tuic["udp"] = true

			proxies = append(proxies, tuic)
		case "trojan":
			name := uniqueName(names, outbound.Tag)
			trojan := make(map[string]any, 20)

			resolveBase(trojan, name, scheme, outbound)

			trojan["password"] = outbound.Password
			trojan["udp"] = true

			resolveTls(trojan, outbound.TLS)
			resolveNetwork(trojan, outbound)
			resolveMultiplex(trojan, outbound.Multiplex)

			proxies = append(proxies, trojan)

		case "vless":
			name := uniqueName(names, outbound.Tag)
			vless := make(map[string]any, 20)

			resolveBase(vless, name, scheme, outbound)

			vless["udp"] = true
			vless["uuid"] = outbound.UUID
			vless["flow"] = outbound.Flow

			resolveTls(vless, outbound.TLS)
			resolveNetwork(vless, outbound)
			resolveMultiplex(vless, outbound.Multiplex)

			switch outbound.PacketEncoding {
			case "none":
			case "packetaddr":
				vless["packet-addr"] = true
			default:
				vless["xudp"] = true
			}

			proxies = append(proxies, vless)

		case "vmess":
			name := uniqueName(names, outbound.Tag)
			vmess := make(map[string]any, 20)

			resolveBase(vmess, name, scheme, outbound)

			vmess["uuid"] = outbound.UUID
			vmess["alterId"] = outbound.AlterID
			if outbound.Security != "" {
				vmess["cipher"] = outbound.Security
			} else {
				vmess["cipher"] = "auto"
			}

			vmess["udp"] = true
			vmess["xudp"] = true
			vmess["tls"] = false

			resolveTls(vmess, outbound.TLS)
			resolveNetwork(vmess, outbound)
			resolveMultiplex(vmess, outbound.Multiplex)

			proxies = append(proxies, vmess)

		case "shadowsocks":

			name := uniqueName(names, outbound.Tag)
			ss := make(map[string]any, 20)

			resolveBase(ss, name, "ss", outbound)
			resolveMultiplex(ss, outbound.Multiplex)

			ss["cipher"] = outbound.Method
			ss["password"] = outbound.Password

			ss["udp"] = true

			if outbound.UdpOverTcp != nil {
				ss["udp-over-tcp"] = outbound.UdpOverTcp.Enabled
				ss["udp-over-tcp-version"] = outbound.UdpOverTcp.Version
			}

			if v1, ok1 := outbound.PluginOpts.(string); ok1 {
				plugin := outbound.Plugin
				pluginInfo, _ := url.ParseQuery(strings.ReplaceAll(v1, ";", "&"))
				switch plugin {
				case "v2ray-plugin":
					ss["plugin"] = "v2ray-plugin"
					ss["plugin-opts"] = map[string]any{
						"mode": pluginInfo.Get("mode"),
						"host": pluginInfo.Get("host"),
						"path": pluginInfo.Get("path"),
						"tls":  strings.Contains(v1, "tls"),
					}
				case "obfs", "obfs-local":
					ss["plugin"] = "obfs"
					ss["plugin-opts"] = map[string]any{
						"mode": pluginInfo.Get("obfs"),
						"host": pluginInfo.Get("obfs-host"),
					}
				}
			} else if v2, ok2 := outbound.PluginOpts.(*SingPluginOpts); ok2 {
				if outbound.Plugin != "" && outbound.PluginOpts != nil {
					switch outbound.Plugin {
					case "v2ray-plugin":
						ss["plugin"] = "v2ray-plugin"
						ss["plugin-opts"] = map[string]any{
							"mode": v2.Mode,
							"host": v2.Host,
							"path": v2.Path,
							"tls":  v2.Tls,
							"mux":  v2.Mux == "1",
						}
					case "obfs", "obfs-local":
						ss["plugin"] = "obfs"
						ss["plugin-opts"] = map[string]any{
							"mode": v2.Mode,
							"host": v2.Host,
						}
					}
				}
			}

			proxies = append(proxies, ss)

		case "anytls":
			name := uniqueName(names, outbound.Tag)
			anytls := make(map[string]any, 20)

			resolveBase(anytls, name, "anytls", outbound)
			resolveTls(anytls, outbound.TLS)

			anytls["password"] = outbound.Password
			anytls["min-idle-session"] = outbound.MinIdleSession
			idle := extractNumber(outbound.IdleSessionCheckInterval)
			if idle > 0 {
				anytls["idle-session-check-interval"] = idle
			}
			idle = extractNumber(outbound.IdleSessionTimeout)
			if idle > 0 {
				anytls["idle-session-timeout"] = idle
			}

			proxies = append(proxies, anytls)

		}
	}

	if len(proxies) == 0 {
		return nil, fmt.Errorf("convert singbox subscribe error: format invalid")
	}

	return proxies, nil
}

type SingBoxOption struct {
	Username                 string                    `json:"username,omitempty"`
	Password                 string                    `json:"password,omitempty"`
	Server                   string                    `json:"server,omitempty"`
	ServerPort               int                       `json:"server_port,omitempty"`
	Tag                      string                    `json:"tag,omitempty"`
	TLS                      *SingTLS                  `json:"tls,omitempty"`
	Transport                *SingTransport            `json:"transport,omitempty"`
	Type                     string                    `json:"type,omitempty"`
	Method                   string                    `json:"method,omitempty"`
	AlterID                  int                       `json:"alter_id,omitempty"`
	Security                 string                    `json:"security,omitempty"`
	UUID                     string                    `json:"uuid,omitempty"`
	Default                  string                    `json:"default,omitempty"`
	Outbounds                []string                  `json:"outbounds,omitempty"`
	Interval                 string                    `json:"interval,omitempty"`
	Tolerance                int                       `json:"tolerance,omitempty"`
	URL                      string                    `json:"url,omitempty"`
	Network                  string                    `json:"network,omitempty"`
	Plugin                   string                    `json:"plugin,omitempty"`
	PluginOpts               any                       `json:"plugin_opts,omitempty"`
	ObfsParam                string                    `json:"obfs_param,omitempty"`
	Protocol                 string                    `json:"protocol,omitempty"`
	ProtocolParam            string                    `json:"protocol_param,omitempty"`
	Flow                     string                    `json:"flow,omitempty"`
	PacketEncoding           string                    `json:"packet_encoding,omitempty"`
	AuthStr                  string                    `json:"auth_str,omitempty"`
	DisableMtuDiscovery      bool                      `json:"disable_mtu_discovery,omitempty"`
	Down                     string                    `json:"down,omitempty"`
	DownMbps                 int                       `json:"down_mbps,omitempty"`
	RecvWindow               int                       `json:"recv_window,omitempty"`
	RecvWindowConn           int                       `json:"recv_window_conn,omitempty"`
	Up                       string                    `json:"up,omitempty"`
	UpMbps                   int                       `json:"up_mbps,omitempty"`
	Detour                   string                    `json:"detour,omitempty"`
	Multiplex                *SingMultiplex            `json:"multiplex,omitempty"`
	Version                  int                       `json:"version,omitempty"`
	UdpOverTcp               *SingUdpOverTcp           `json:"udp_over_tcp,omitempty"`
	SystemInterface          bool                      `json:"system_interface,omitempty"`
	InterfaceName            string                    `json:"interface_name,omitempty"`
	LocalAddress             []string                  `json:"local_address,omitempty"`
	PrivateKey               string                    `json:"private_key,omitempty"`
	Peers                    []*SingWireguardMultiPeer `json:"peers,omitempty"`
	PeerPublicKey            string                    `json:"peer_public_key,omitempty"`
	PreSharedKey             string                    `json:"pre_shared_key,omitempty"`
	Reserved                 []int64                   `json:"reserved,omitempty"`
	MTU                      uint                      `json:"mtu,omitempty"`
	CongestionController     string                    `json:"congestion_control,omitempty"`
	UdpRelayMode             string                    `json:"udp_relay_mode,omitempty"`
	ZeroRttHandshake         bool                      `json:"zero_rtt_handshake,omitempty"`
	Heartbeat                string                    `json:"heartbeat,omitempty"`
	Obfs                     *SingObfs                 `json:"obfs,omitempty"`
	Ignored                  bool                      `json:"-"`
	TcpFastOpen              bool                      `json:"tcp_fast_open,omitempty"`
	TcpMultiPath             bool                      `json:"tcp_multi_path,omitempty"`
	Visible                  []string                  `json:"-"`
	ServerPorts              []string                  `json:"server_ports,omitempty"`
	IdleSessionCheckInterval string                    `json:"idle_session_check_interval,omitempty"`
	IdleSessionTimeout       string                    `json:"idle_session_timeout,omitempty"`
	MinIdleSession           int                       `json:"min_idle_session,omitempty"`
}

func (c *SingBoxOption) UnmarshalJSON(data []byte) error {
	// 定义一个临时结构，避免递归调用 UnmarshalJSON
	type Alias SingBoxOption
	aux := &struct {
		PluginOpts json.RawMessage `json:"plugin_opts"`
		*Alias
	}{
		Alias: (*Alias)(c),
	}

	if err := json.Unmarshal(data, &aux); err != nil {
		return err
	}

	if len(aux.PluginOpts) == 0 {
		return nil
	}

	// 核心逻辑：尝试判断 PluginOpts 的内容
	var s string
	if err := json.Unmarshal(aux.PluginOpts, &s); err == nil {
		// 如果成功解析为字符串
		c.PluginOpts = s
		return nil
	}

	// 如果不是字符串，尝试解析为结构体
	var opts SingPluginOpts
	if err := json.Unmarshal(aux.PluginOpts, &opts); err == nil {
		c.PluginOpts = &opts
		return nil
	}

	return fmt.Errorf("plugin_opts field has invalid type")
}

type SingUdpOverTcp struct {
	Enabled bool `json:"enabled,omitempty"`
	Version bool `json:"version,omitempty"`
}

type SingTLS struct {
	Enabled     bool         `json:"enabled,omitempty"`
	ServerName  string       `json:"server_name,omitempty"`
	Alpn        []string     `json:"alpn,omitempty"`
	Insecure    bool         `json:"insecure,omitempty"`
	Utls        *SingUtls    `json:"utls,omitempty"`
	Reality     *SingReality `json:"reality,omitempty"`
	Certificate string       `json:"certificate,omitempty"`
}

type SingUtls struct {
	Enabled     bool   `json:"enabled,omitempty"`
	Fingerprint string `json:"fingerprint,omitempty"`
}

type SingReality struct {
	Enabled   bool   `json:"enabled,omitempty"`
	PublicKey string `json:"public_key,omitempty"`
	ShortID   string `json:"short_id,omitempty"`
}

type SingTransport struct {
	Headers             any    `json:"headers,omitempty" yaml:"headers,omitempty"`
	Path                string `json:"path,omitempty" yaml:"path,omitempty"`
	Type                string `json:"type,omitempty" yaml:"type,omitempty"`
	EarlyDataHeaderName string `json:"early_data_header_name,omitempty" yaml:"early-data-header-name,omitempty"`
	MaxEarlyData        int    `json:"max_early_data,omitempty" yaml:"max-early-data,omitempty"`
	Host                string `json:"host,omitempty" yaml:"host,omitempty"`
	Method              string `json:"method,omitempty" yaml:"method,omitempty"`
	ServiceName         string `json:"service_name,omitempty" yaml:"grpc-service-name,omitempty"`
}

type SingMultiplex struct {
	Enabled        bool        `json:"enabled,omitempty"`
	MaxConnections int         `json:"max_connections,omitempty"`
	MinStreams     int         `json:"min_streams,omitempty"`
	MaxStreams     int         `json:"max_streams,omitempty"`
	Padding        bool        `json:"padding,omitempty"`
	Protocol       string      `json:"protocol,omitempty"`
	Brutal         *SingBrutal `json:"brutal,omitempty"`
}

type SingBrutal struct {
	Enabled bool `json:"enabled,omitempty"`
	Up      int  `json:"up_mbps,omitempty"`
	Down    int  `json:"down_mbps,omitempty"`
}

type SingWireguardMultiPeer struct {
	Server       string   `json:"server,omitempty"`
	ServerPort   int      `json:"server_port,omitempty"`
	PublicKey    string   `json:"public_key,omitempty"`
	PreSharedKey string   `json:"pre_shared_key,omitempty"`
	AllowedIps   []string `json:"allowed_ips,omitempty"`
	Reserved     []int64  `json:"reserved,omitempty"`
}

type SingObfs struct {
	Password string `json:"password,omitempty"`
	Type     string `json:"type,omitempty"`
}

type SingPluginOpts struct {
	Mode string `json:"mode,omitempty"`
	Host string `json:"host,omitempty"`
	Path string `json:"path,omitempty"`
	Tls  bool   `json:"tls,omitempty"`
	Mux  string `json:"mux,omitempty"`
}

type SingConfig struct {
	Outbounds []SingBoxOption `json:"outbounds,omitempty"`
}

func resolveBase(v map[string]any, name, scheme string, outbound SingBoxOption) {
	v["name"] = name
	v["type"] = scheme
	v["server"] = outbound.Server
	v["port"] = outbound.ServerPort
}

func resolveTls(v map[string]any, singTLS *SingTLS) {
	if singTLS != nil {
		if singTLS.ServerName != "" {
			switch v["type"] {
			case "vmess", "vless":
				v["servername"] = singTLS.ServerName
			default:
				v["sni"] = singTLS.ServerName
			}
		}

		v["tls"] = singTLS.Enabled

		if singTLS.Insecure {
			v["skip-cert-verify"] = true
		}

		if len(singTLS.Alpn) > 0 {
			v["alpn"] = singTLS.Alpn
		}

		if singTLS.Reality != nil {
			v["reality-opts"] = map[string]any{
				"public-key": singTLS.Reality.PublicKey,
				"short-id":   singTLS.Reality.ShortID,
			}
		}

		if singTLS.Utls != nil {
			v["client-fingerprint"] = singTLS.Utls.Fingerprint
		}
	}
}

func resolveNetwork(v map[string]any, outbound SingBoxOption) {
	if outbound.Network != "" {
		v["network"] = outbound.Network
	}

	if outbound.Transport != nil {
		network := "tcp"
		if outbound.Transport.Type != "" {
			network = outbound.Transport.Type
			outbound.Transport.Type = ""
		}
		v["network"] = network

		switch network {
		case "h2":
			v["h2-opts"] = SingTransportToMap(outbound.Transport)
		case "tcp", "http":
			v["http-opts"] = SingTransportToMap(outbound.Transport)
		case "ws":
			v["ws-opts"] = SingTransportToMap(outbound.Transport)
		case "httpupgrade":
			wsOpts := make(map[string]any)
			if path := outbound.Transport.Path; path != "" {
				wsOpts["path"] = path
			}
			wsOpts["v2ray-http-upgrade"] = true
			wsOpts["v2ray-http-upgrade-fast-open"] = true

			if host := outbound.Transport.Host; host != "" {
				headers := make(map[string]any)
				headers["User-Agent"] = RandUserAgent()
				headers["Host"] = host
				wsOpts["headers"] = headers
			}

			v["network"] = "ws"
			v["ws-opts"] = wsOpts
		case "grpc":
			v["grpc-opts"] = SingTransportToMap(outbound.Transport)
		}
	}
}

func SingTransportToMap(obj *SingTransport) map[string]interface{} {
	var result map[string]interface{}

	marshal, err := yaml.Marshal(obj)
	if err != nil {
		return nil
	}

	err = yaml.Unmarshal(marshal, &result)
	if err != nil {
		return nil
	}

	if _, exists := result["headers"]; exists {
		if reflect.TypeOf(result["headers"]).Kind() != reflect.Map {
			delete(result, "headers")
		}
	}

	return result
}

func resolveMultiplex(v map[string]any, mul *SingMultiplex) {
	if mul == nil {
		return
	}

	// 解析 Multiplex
	mux := make(map[string]any)
	mux["enabled"] = mul.Enabled
	mux["padding"] = mul.Padding
	if mul.Protocol != "" {
		mux["protocol"] = mul.Protocol
	}
	if mul.MaxConnections > 0 {
		mux["max-connections"] = mul.MaxConnections
	}
	if mul.MinStreams > 0 {
		mux["min-streams"] = mul.MinStreams
	}
	if mul.MaxStreams > 0 {
		mux["max-streams"] = mul.MaxStreams
	}

	// 解析 brutal 字段
	bru := make(map[string]any)
	brutal := mul.Brutal
	if brutal != nil {
		bru["enabled"] = brutal.Enabled
		bru["up"] = brutal.Up
		bru["down"] = brutal.Down
	}
	if len(bru) > 0 {
		mux["brutal-opts"] = bru
	}

	if len(mux) > 0 {
		v["smux"] = mux
	}
}

func extractNumber(s string) int {
	var numRunes []rune
	for _, r := range s {
		if unicode.IsDigit(r) {
			numRunes = append(numRunes, r)
		} else {
			break
		}
	}
	if len(numRunes) == 0 {
		return 0
	}
	num, err := strconv.Atoi(string(numRunes))
	if err != nil {
		return 0
	}
	return num
}
