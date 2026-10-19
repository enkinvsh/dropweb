package tls

import (
	"net"
	"testing"

	utls "github.com/metacubex/utls"
)

func buildCustomUConn(t *testing.T, clientFingerprint string) *UConn {
	t.Helper()

	fingerprint, ok := GetFingerprint(clientFingerprint)
	if !ok {
		t.Fatalf("GetFingerprint(%q) not found", clientFingerprint)
	}
	if fingerprint != utls.HelloCustom {
		t.Fatalf("GetFingerprint(%q) = %v, want HelloCustom", clientFingerprint, fingerprint.Client)
	}

	c, s := net.Pipe()
	t.Cleanup(func() {
		_ = c.Close()
		_ = s.Close()
	})

	uConn := UClient(c, &utls.Config{ServerName: "example.com"}, fingerprint)
	if err := ApplyClientFingerprint(uConn, clientFingerprint); err != nil {
		t.Fatalf("ApplyClientFingerprint(%q): %v", clientFingerprint, err)
	}
	if err := uConn.BuildHandshakeState(); err != nil {
		t.Fatalf("BuildHandshakeState(%q): %v", clientFingerprint, err)
	}
	return uConn
}

func TestDropwebCustomFingerprintsBuild(t *testing.T) {
	cases := []struct {
		name        string
		minCiphers  int
		wantCiphers []uint16
	}{
		{
			name:       "firefox148",
			minCiphers: 17,
			wantCiphers: []uint16{
				utls.TLS_AES_128_GCM_SHA256,
				utls.TLS_CHACHA20_POLY1305_SHA256,
				utls.TLS_AES_256_GCM_SHA384,
			},
		},
		{
			name:       "safari26",
			minCiphers: 21,
			wantCiphers: []uint16{
				utls.TLS_AES_256_GCM_SHA384,
				utls.TLS_CHACHA20_POLY1305_SHA256,
				utls.TLS_AES_128_GCM_SHA256,
			},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			uConn := buildCustomUConn(t, tc.name)

			hello := uConn.HandshakeState.Hello
			if hello == nil {
				t.Fatal("HandshakeState.Hello is nil")
			}
			if len(hello.Raw) == 0 {
				t.Fatal("marshaled ClientHello (hello.Raw) is empty")
			}
			if len(hello.CipherSuites) < tc.minCiphers {
				t.Fatalf("CipherSuites len = %d, want >= %d", len(hello.CipherSuites), tc.minCiphers)
			}
			if len(uConn.Extensions) == 0 {
				t.Fatal("Extensions is empty after applying custom spec")
			}
			assertExtensionTypes(t, uConn)
			for _, want := range tc.wantCiphers {
				if !containsCipher(hello.CipherSuites, want) {
					t.Fatalf("CipherSuites missing 0x%04x", want)
				}
			}
		})
	}
}

func TestDropwebGetClientHelloSpec(t *testing.T) {
	for _, name := range []string{"firefox148", "safari26"} {
		spec, ok := GetClientHelloSpec(name)
		if !ok {
			t.Fatalf("GetClientHelloSpec(%q) not found", name)
		}
		if spec == nil || len(spec.CipherSuites) == 0 || len(spec.Extensions) == 0 {
			t.Fatalf("GetClientHelloSpec(%q) returned an empty spec", name)
		}
	}

	if _, ok := GetClientHelloSpec("chrome120"); ok {
		t.Fatal("GetClientHelloSpec(\"chrome120\") should be false: preset, not a custom spec")
	}
	if err := ApplyClientFingerprint(nil, "chrome120"); err != nil {
		t.Fatalf("ApplyClientFingerprint for preset fingerprint should be a no-op, got: %v", err)
	}
}

func assertExtensionTypes(t *testing.T, uConn *UConn) {
	t.Helper()
	var hasSNI, hasKeyShare, hasSupportedVersions, hasALPN bool
	for _, ext := range uConn.Extensions {
		switch ext.(type) {
		case *utls.SNIExtension:
			hasSNI = true
		case *utls.KeyShareExtension:
			hasKeyShare = true
		case *utls.SupportedVersionsExtension:
			hasSupportedVersions = true
		case *utls.ALPNExtension:
			hasALPN = true
		}
	}
	if !hasSNI {
		t.Error("custom spec missing SNIExtension")
	}
	if !hasKeyShare {
		t.Error("custom spec missing KeyShareExtension")
	}
	if !hasSupportedVersions {
		t.Error("custom spec missing SupportedVersionsExtension")
	}
	if !hasALPN {
		t.Error("custom spec missing ALPNExtension")
	}
}

func containsCipher(suites []uint16, want uint16) bool {
	for _, s := range suites {
		if s == want {
			return true
		}
	}
	return false
}
