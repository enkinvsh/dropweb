package tls

// dropweb custom TLS client fingerprints.
//
// metacubex/utls v1.8.7 maxes out at HelloFirefox_120 / HelloSafari_16_0, so the
// modern Firefox 148 and Safari 26.3 ClientHellos are not available as preset
// ClientHelloIDs. Instead of vendoring a fork of utls (pluralplay's approach), we
// keep metacubex/utls v1.8.7 as a normal dependency — preserving its security
// updates — and define the two specs here against utls' PUBLIC API.
//
// These are applied via utls.HelloCustom + (*utls.UConn).ApplyPreset(&spec): see
// GetFingerprint / GetClientHelloSpec in utls.go and the ApplyPreset call sites in
// the transport packages.
//
// Spec bodies are ported faithfully (cipher suites, extensions, order, key shares,
// GREASE, ECH params) from pluralplay's u_parrots_flclashx.go, translated from the
// in-package unprefixed type names to the exported utls./dicttls. forms. JA3/JA4
// fidelity matters, so do not reorder or drop extensions.
//
// Note: v1.8.4 has no ReuseHybridAndClassicalKeyShares helper, so key shares are
// listed explicitly. The ClientHello structure (and therefore JA3/JA4) is identical;
// only the standalone X25519 key isn't reused from the hybrid share.

import (
	utls "github.com/metacubex/utls"
	"github.com/metacubex/utls/dicttls"
)

func firefox148ClientHelloSpec() utls.ClientHelloSpec {
	return utls.ClientHelloSpec{
		TLSVersMin: utls.VersionTLS12,
		TLSVersMax: utls.VersionTLS13,
		CipherSuites: []uint16{
			utls.TLS_AES_128_GCM_SHA256,
			utls.TLS_CHACHA20_POLY1305_SHA256,
			utls.TLS_AES_256_GCM_SHA384,
			utls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
			utls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
			utls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,
			utls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,
			utls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
			utls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
			utls.TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,
			utls.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,
			utls.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,
			utls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
			utls.TLS_RSA_WITH_AES_128_GCM_SHA256,
			utls.TLS_RSA_WITH_AES_256_GCM_SHA384,
			utls.TLS_RSA_WITH_AES_128_CBC_SHA,
			utls.TLS_RSA_WITH_AES_256_CBC_SHA,
		},
		CompressionMethods: []uint8{
			0x0, // no compression
		},
		Extensions: []utls.TLSExtension{
			&utls.SNIExtension{},
			&utls.ExtendedMasterSecretExtension{},
			&utls.RenegotiationInfoExtension{
				Renegotiation: utls.RenegotiateOnceAsClient,
			},
			&utls.SupportedCurvesExtension{
				Curves: []utls.CurveID{
					utls.X25519MLKEM768,
					utls.X25519,
					utls.CurveP256,
					utls.CurveP384,
					utls.CurveP521,
					0x0100,
					0x0101,
				},
			},
			&utls.SupportedPointsExtension{
				SupportedPoints: []uint8{
					0x0, // uncompressed
				},
			},
			&utls.ALPNExtension{
				AlpnProtocols: []string{
					"h2",
					"http/1.1",
				},
			},
			&utls.StatusRequestExtension{},
			&utls.FakeDelegatedCredentialsExtension{
				SupportedSignatureAlgorithms: []utls.SignatureScheme{
					utls.ECDSAWithP256AndSHA256,
					utls.ECDSAWithP384AndSHA384,
					utls.ECDSAWithP521AndSHA512,
					utls.ECDSAWithSHA1,
				},
			},
			&utls.SCTExtension{},
			&utls.KeyShareExtension{
				KeyShares: []utls.KeyShare{
					{Group: utls.X25519MLKEM768},
					{Group: utls.X25519},
					{Group: utls.CurveP256},
				},
			},
			&utls.SupportedVersionsExtension{
				Versions: []uint16{
					utls.VersionTLS13,
					utls.VersionTLS12,
				},
			},
			&utls.SignatureAlgorithmsExtension{
				SupportedSignatureAlgorithms: []utls.SignatureScheme{
					utls.ECDSAWithP256AndSHA256,
					utls.ECDSAWithP384AndSHA384,
					utls.ECDSAWithP521AndSHA512,
					utls.PSSWithSHA256,
					utls.PSSWithSHA384,
					utls.PSSWithSHA512,
					utls.PKCS1WithSHA256,
					utls.PKCS1WithSHA384,
					utls.PKCS1WithSHA512,
					utls.ECDSAWithSHA1,
					utls.PKCS1WithSHA1,
				},
			},
			&utls.FakeRecordSizeLimitExtension{
				Limit: 0x4001,
			},
			&utls.UtlsCompressCertExtension{
				Algorithms: []utls.CertCompressionAlgo{
					utls.CertCompressionZlib,
					utls.CertCompressionBrotli,
					utls.CertCompressionZstd,
				},
			},
			&utls.GREASEEncryptedClientHelloExtension{
				CandidateCipherSuites: []utls.HPKESymmetricCipherSuite{
					{
						KdfId:  dicttls.HKDF_SHA256,
						AeadId: dicttls.AEAD_AES_128_GCM,
					},
					{
						KdfId:  dicttls.HKDF_SHA256,
						AeadId: dicttls.AEAD_CHACHA20_POLY1305,
					},
				},
				CandidatePayloadLens: []uint16{223}, // +16: 239
			},
		},
	}
}

func safari263ClientHelloSpec() utls.ClientHelloSpec {
	return utls.ClientHelloSpec{
		TLSVersMin: utls.VersionTLS12,
		TLSVersMax: utls.VersionTLS13,
		CipherSuites: []uint16{
			utls.GREASE_PLACEHOLDER,
			utls.TLS_AES_256_GCM_SHA384,
			utls.TLS_CHACHA20_POLY1305_SHA256,
			utls.TLS_AES_128_GCM_SHA256,
			utls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
			utls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
			utls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,
			utls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
			utls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
			utls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,
			utls.TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,
			utls.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,
			utls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
			utls.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,
			utls.TLS_RSA_WITH_AES_256_GCM_SHA384,
			utls.TLS_RSA_WITH_AES_128_GCM_SHA256,
			utls.TLS_RSA_WITH_AES_256_CBC_SHA,
			utls.TLS_RSA_WITH_AES_128_CBC_SHA,
			utls.FAKE_TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA,
			utls.TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,
			utls.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
		},
		CompressionMethods: []uint8{
			0x0, // no compression
		},
		Extensions: []utls.TLSExtension{
			&utls.UtlsGREASEExtension{},
			&utls.SNIExtension{},
			&utls.ExtendedMasterSecretExtension{},
			&utls.RenegotiationInfoExtension{
				Renegotiation: utls.RenegotiateOnceAsClient,
			},
			&utls.SupportedCurvesExtension{
				Curves: []utls.CurveID{
					utls.GREASE_PLACEHOLDER,
					utls.X25519MLKEM768,
					utls.X25519,
					utls.CurveP256,
					utls.CurveP384,
					utls.CurveP521,
				},
			},
			&utls.SupportedPointsExtension{
				SupportedPoints: []uint8{
					0x0, // uncompressed
				},
			},
			&utls.ALPNExtension{
				AlpnProtocols: []string{
					"h2",
					"http/1.1",
				},
			},
			&utls.StatusRequestExtension{},
			&utls.SignatureAlgorithmsExtension{
				SupportedSignatureAlgorithms: []utls.SignatureScheme{
					utls.ECDSAWithP256AndSHA256,
					utls.PSSWithSHA256,
					utls.PKCS1WithSHA256,
					utls.ECDSAWithP384AndSHA384,
					utls.PSSWithSHA384,
					utls.PSSWithSHA384,
					utls.PKCS1WithSHA384,
					utls.PSSWithSHA512,
					utls.PKCS1WithSHA512,
					utls.PKCS1WithSHA1,
				},
			},
			&utls.SCTExtension{},
			&utls.KeyShareExtension{
				KeyShares: []utls.KeyShare{
					{
						Group: utls.GREASE_PLACEHOLDER,
						Data: []byte{
							0,
						},
					},
					{Group: utls.X25519MLKEM768},
					{Group: utls.X25519},
				},
			},
			&utls.PSKKeyExchangeModesExtension{
				Modes: []uint8{
					utls.PskModeDHE,
				},
			},
			&utls.SupportedVersionsExtension{
				Versions: []uint16{
					utls.GREASE_PLACEHOLDER,
					utls.VersionTLS13,
					utls.VersionTLS12,
				},
			},
			&utls.UtlsCompressCertExtension{
				Algorithms: []utls.CertCompressionAlgo{
					utls.CertCompressionZlib,
				},
			},
			&utls.UtlsGREASEExtension{},
		},
	}
}

// dropwebClientHelloSpecs maps dropweb custom client-fingerprint names to their
// ClientHelloSpec factory. Names follow the existing map style ("firefox120",
// "safari16"). Each entry resolves to utls.HelloCustom in the fingerprints map and
// the spec is applied via (*utls.UConn).ApplyPreset at the UClient call sites.
var dropwebClientHelloSpecs = map[string]func() utls.ClientHelloSpec{
	// Standard names resolve to the newest spec so a shared client-fingerprint
	// value (firefox/safari) is backward-safe across core versions.
	"firefox": firefox148ClientHelloSpec,
	"safari":  safari263ClientHelloSpec,
	// Explicit version-pinned aliases for the same specs.
	"firefox148": firefox148ClientHelloSpec,
	"safari26":   safari263ClientHelloSpec,
}
