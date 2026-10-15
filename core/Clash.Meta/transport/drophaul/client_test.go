package drophaul

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/binary"
	"errors"
	"io"
	"math/big"
	"net"
	"sync"
	"testing"
	"time"

	"github.com/metacubex/mihomo/transport/drophaul/smux"
)

func TestDeriveTokenMatchesVector(t *testing.T) {
	got := DeriveToken("  7xK9PublicKeyBase64Url  ", " 4F8A01 ")
	const want = "836e61114095708f13b16aedf6f193adfcb7fa01c6f03aba1048a1aa1abb31d1"
	if got != want {
		t.Fatalf("token vector mismatch: got %q, want %q", got, want)
	}
}

func makeTLSConfigPair(t *testing.T) (*tls.Config, *tls.Config) {
	t.Helper()
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("key: %v", err)
	}
	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "node.meybz.asia"},
		DNSNames:     []string{"node.meybz.asia"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour),
		KeyUsage:     x509.KeyUsageDigitalSignature,
		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &priv.PublicKey, priv)
	if err != nil {
		t.Fatalf("cert: %v", err)
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatalf("parse cert: %v", err)
	}
	roots := x509.NewCertPool()
	roots.AddCert(cert)

	srvCfg := &tls.Config{
		Certificates: []tls.Certificate{{Certificate: [][]byte{der}, PrivateKey: priv}},
		MinVersion:   tls.VersionTLS13,
	}
	cliCfg := &tls.Config{
		ServerName: "node.meybz.asia",
		RootCAs:    roots,
		MinVersion: tls.VersionTLS13,
	}
	return srvCfg, cliCfg
}

func TestPoolMultiplexesStreamsOverSingleSession(t *testing.T) {
	srvTLS, cliTLS := makeTLSConfigPair(t)
	token := DeriveToken("pubKey1", "short01")

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer ln.Close()

	var acceptedConns int32
	var mu sync.Mutex

	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			mu.Lock()
			acceptedConns++
			mu.Unlock()
			go func(raw net.Conn) {
				defer raw.Close()
				tc := tls.Server(raw, srvTLS)
				if err := tc.Handshake(); err != nil {
					return
				}
				var hdr [3]byte
				if _, err := io.ReadFull(tc, hdr[:]); err != nil {
					return
				}
				msgLen := int(binary.BigEndian.Uint16(hdr[:2]))
				if hdr[2] != SGChan || msgLen != len(token) {
					return
				}
				tokBuf := make([]byte, msgLen)
				if _, err := io.ReadFull(tc, tokBuf); err != nil || string(tokBuf) != token {
					return
				}
				if _, err := tc.Write([]byte{SGChan}); err != nil {
					return
				}
				cfg := smux.DefaultConfig()
				cfg.Version = 2
				cfg.Padding = true
				sess, err := smux.Server(tc, cfg)
				if err != nil {
					return
				}
				defer sess.Close()
				for {
					st, err := sess.AcceptStream()
					if err != nil {
						return
					}
					go func(s *smux.Stream) {
						defer s.Close()
						_, _ = io.Copy(s, s)
					}(st)
				}
			}(c)
		}
	}()

	pool := NewPool(Options{
		Addr:  ln.Addr().String(),
		Token: token,
		DialTCP: func(ctx context.Context) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "tcp", ln.Addr().String())
		},
		HandshakeTLS: func(ctx context.Context, rawConn net.Conn) (net.Conn, error) {
			tc := tls.Client(rawConn, cliTLS)
			if err := tc.HandshakeContext(ctx); err != nil {
				return nil, err
			}
			return tc, nil
		},
	})
	defer pool.Close()

	// открываем 5 потоков подряд — все они должны пройти внутри одной smux-сессии
	for i := 0; i < 5; i++ {
		st, err := pool.DialStream(context.Background())
		if err != nil {
			t.Fatalf("DialStream #%d: %v", i, err)
		}
		msg := []byte("hello-drophaul-stream")
		if _, err := st.Write(msg); err != nil {
			t.Fatalf("write #%d: %v", i, err)
		}
		got := make([]byte, len(msg))
		if _, err := io.ReadFull(st, got); err != nil {
			t.Fatalf("read #%d: %v", i, err)
		}
		if string(got) != string(msg) {
			t.Fatalf("mismatch: %q != %q", string(got), string(msg))
		}
		_ = st.Close()
	}

	mu.Lock()
	conns := acceptedConns
	mu.Unlock()
	if conns != 1 {
		t.Fatalf("expected 1 underlying TCP connection for 5 streams, got %d", conns)
	}
}

func TestPoolFallsBackToRealityWhenNodeReturnsHTTP(t *testing.T) {
	srvTLS, cliTLS := makeTLSConfigPair(t)

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer ln.Close()

	go func() {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		defer c.Close()
		tc := tls.Server(c, srvTLS)
		if err := tc.Handshake(); err != nil {
			return
		}
		buf := make([]byte, 128)
		_, _ = tc.Read(buf)
		// имитируем необновлённую ноду, где reality dest ведёт прямо в nginx
		_, _ = io.WriteString(tc, "HTTP/1.1 400 Bad Request\r\n\r\n")
	}()

	pool := NewPool(Options{
		Addr:  ln.Addr().String(),
		Token: DeriveToken("pubKey1", "short01"),
		DialTCP: func(ctx context.Context) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "tcp", ln.Addr().String())
		},
		HandshakeTLS: func(ctx context.Context, rawConn net.Conn) (net.Conn, error) {
			tc := tls.Client(rawConn, cliTLS)
			if err := tc.HandshakeContext(ctx); err != nil {
				return nil, err
			}
			return tc, nil
		},
	})
	defer pool.Close()

	_, err = pool.DialStream(context.Background())
	if !errors.Is(err, ErrFallbackToReality) {
		t.Fatalf("expected ErrFallbackToReality, got %v", err)
	}
	if !pool.ShouldFallback() {
		t.Fatalf("expected pool.ShouldFallback() == true after HTTP response")
	}
}
