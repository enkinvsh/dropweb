package drophaul

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"io"
	"math/big"
	"net"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/metacubex/mihomo/transport/drophaul/smux"
	"github.com/metacubex/mihomo/transport/vmess"
)

func TestDeriveTokenMatchesVector(t *testing.T) {
	got := DeriveToken("  7xK9PublicKeyBase64Url  ", " 4F8A01 ")
	const want = "836e61114095708f13b16aedf6f193adfcb7fa01c6f03aba1048a1aa1abb31d1"
	if got != want {
		t.Fatalf("token vector mismatch: got %q, want %q", got, want)
	}
}

func verifyMarkedRandom(key, random []byte, now time.Time) bool {
	if len(random) != 32 {
		return false
	}
	baseWindow := uint64(now.Unix() / 60)
	nonce := random[:16]
	wantTag := random[16:32]
	for delta := int64(-5); delta <= 5; delta++ {
		w := uint64(int64(baseWindow) + delta)
		var winBuf [8]byte
		binary.BigEndian.PutUint64(winBuf[:], w)
		mac := hmac.New(sha256.New, key)
		mac.Write(nonce)
		mac.Write(winBuf[:])
		sum := mac.Sum(nil)
		if hmac.Equal(sum[:16], wantTag) {
			return true
		}
	}
	return false
}

func TestMarkedRandomMatchesVector(t *testing.T) {
	token := strings.Repeat("0123456789abcdef", 4)
	key := MarkKey(token)
	const wantKeyHex = "516c4c704217c12983b8b5c81380fbe879ee4893722b74b110a54544717f1ce1"
	if gotKeyHex := hex.EncodeToString(key); gotKeyHex != wantKeyHex {
		t.Fatalf("MarkKey hex mismatch: got %q, want %q", gotKeyHex, wantKeyHex)
	}

	nonce := []byte{
		0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
		0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
	}
	fixedNow := time.Unix(1760600000, 0)
	rnd, err := NewMarkedRandom(key, fixedNow, bytes.NewReader(nonce))
	if err != nil {
		t.Fatalf("NewMarkedRandom error: %v", err)
	}
	const wantRandomHex = "000102030405060708090a0b0c0d0e0f2e0d09b0e5d6c0df8e0cd5e073ef65e1"
	if gotRandomHex := hex.EncodeToString(rnd[:]); gotRandomHex != wantRandomHex {
		t.Fatalf("NewMarkedRandom hex mismatch: got %q, want %q", gotRandomHex, wantRandomHex)
	}

	if !verifyMarkedRandom(key, rnd[:], fixedNow) {
		t.Fatalf("expected verifyMarkedRandom to accept vector random at fixedNow")
	}
	if verifyMarkedRandom(MarkKey("different-token"), rnd[:], fixedNow) {
		t.Fatalf("expected verifyMarkedRandom to reject different token")
	}

	liveRnd, err := ClientRandomForToken(token)
	if err != nil {
		t.Fatalf("ClientRandomForToken error: %v", err)
	}
	if !verifyMarkedRandom(key, liveRnd, time.Now()) {
		t.Fatalf("expected ClientRandomForToken output to pass verification")
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

func readFirstTLSRecord(r io.Reader) ([]byte, error) {
	var hdr [5]byte
	if _, err := io.ReadFull(r, hdr[:]); err != nil {
		return nil, err
	}
	recLen := int(binary.BigEndian.Uint16(hdr[3:5]))
	rec := make([]byte, 5+recLen)
	copy(rec[:5], hdr[:])
	if _, err := io.ReadFull(r, rec[5:]); err != nil {
		return nil, err
	}
	return rec, nil
}

func parseClientHelloExtensions(t *testing.T, record []byte, wantSNI string) (extCount int, hasSNI bool) {
	t.Helper()
	if len(record) < 44 || record[0] != 0x16 || record[5] != 0x01 {
		t.Fatalf("not a TLS ClientHello record (len=%d)", len(record))
	}
	sidLen := int(record[43])
	pos := 44 + sidLen
	if pos+2 > len(record) {
		t.Fatalf("truncated at cipher suites length")
	}
	csLen := int(binary.BigEndian.Uint16(record[pos : pos+2]))
	pos += 2 + csLen
	if pos+1 > len(record) {
		t.Fatalf("truncated at compression methods length")
	}
	compLen := int(record[pos])
	pos += 1 + compLen
	if pos+2 > len(record) {
		t.Fatalf("truncated at extensions length")
	}
	extsLen := int(binary.BigEndian.Uint16(record[pos : pos+2]))
	pos += 2
	end := pos + extsLen
	if end > len(record) {
		t.Fatalf("extensions exceed record length: %d > %d", end, len(record))
	}
	for pos < end {
		if pos+4 > end {
			t.Fatalf("truncated extension header at %d", pos)
		}
		extType := binary.BigEndian.Uint16(record[pos : pos+2])
		extLen := int(binary.BigEndian.Uint16(record[pos+2 : pos+4]))
		pos += 4
		if pos+extLen > end {
			t.Fatalf("truncated extension body at %d", pos)
		}
		if extType == 0 && bytes.Contains(record[pos:pos+extLen], []byte(wantSNI)) {
			hasSNI = true
		}
		pos += extLen
		extCount++
	}
	return extCount, hasSNI
}

func TestStreamTLSConnWithFirefoxClientRandomHookWritesMarkedHello(t *testing.T) {
	token := DeriveToken("pubKeyWire", "4f8a01")
	const sniHost = "node.meybz.asia"

	var generatedRandom []byte
	clientConn, serverConn := net.Pipe()
	defer clientConn.Close()
	defer serverConn.Close()

	recCh := make(chan []byte, 1)
	errCh := make(chan error, 1)
	go func() {
		rec, err := readFirstTLSRecord(serverConn)
		_ = serverConn.Close()
		if err != nil {
			errCh <- err
			return
		}
		recCh <- rec
	}()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	tlsOpts := vmess.TLSConfig{
		Host:              sniHost,
		ClientFingerprint: "firefox",
		NextProtos:        []string{"h2", "http/1.1"},
		ClientRandom: func() ([]byte, error) {
			r, err := ClientRandomForToken(token)
			generatedRandom = append([]byte(nil), r...)
			return r, err
		},
	}
	_, _ = vmess.StreamTLSConn(ctx, clientConn, &tlsOpts)

	select {
	case err := <-errCh:
		t.Fatalf("readFirstTLSRecord failed: %v", err)
	case rec := <-recCh:
		if len(rec) < 43 {
			t.Fatalf("record too short: %d", len(rec))
		}
		wireRandom := rec[11:43]
		if !bytes.Equal(wireRandom, generatedRandom) {
			t.Fatalf("wire ClientHello.Random %x != hook random %x", wireRandom, generatedRandom)
		}
		if !verifyMarkedRandom(MarkKey(token), wireRandom, time.Now()) {
			t.Fatalf("wire ClientHello.Random failed verification for token")
		}
		if verifyMarkedRandom(MarkKey(DeriveToken("otherPubKey", "000000")), wireRandom, time.Now()) {
			t.Fatalf("wire ClientHello.Random unexpectedly verified for different token")
		}
		extCount, hasSNI := parseClientHelloExtensions(t, rec, sniHost)
		if !hasSNI {
			t.Fatalf("expected SNI %q in Firefox ClientHello", sniHost)
		}
		if extCount <= 10 {
			t.Fatalf("expected Firefox ClientHello extensions count > 10, got %d", extCount)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for ClientHello record")
	}
}

func TestStreamTLSConnWithoutClientRandomLeavesHelloUnmarked(t *testing.T) {
	token := DeriveToken("pubKeyWire", "4f8a01")
	const sniHost = "node.meybz.asia"

	clientConn, serverConn := net.Pipe()
	defer clientConn.Close()
	defer serverConn.Close()

	recCh := make(chan []byte, 1)
	go func() {
		rec, _ := readFirstTLSRecord(serverConn)
		_ = serverConn.Close()
		recCh <- rec
	}()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	tlsOpts := vmess.TLSConfig{
		Host:              sniHost,
		ClientFingerprint: "firefox",
		NextProtos:        []string{"h2", "http/1.1"},
	}
	_, _ = vmess.StreamTLSConn(ctx, clientConn, &tlsOpts)

	rec := <-recCh
	if len(rec) < 43 {
		t.Fatalf("record too short: %d", len(rec))
	}
	if verifyMarkedRandom(MarkKey(token), rec[11:43], time.Now()) {
		t.Fatalf("unmarked ClientHello should not match token mark")
	}
	extCount, hasSNI := parseClientHelloExtensions(t, rec, sniHost)
	if !hasSNI || extCount <= 10 {
		t.Fatalf("expected intact Firefox ClientHello (hasSNI=%v, extCount=%d)", hasSNI, extCount)
	}
}

func TestPoolFallsBackToRealityWhenClientRandomHookCannotApply(t *testing.T) {
	token := DeriveToken("pubKey1", "short01")

	pool := NewPool(Options{
		Addr:  "127.0.0.1:443",
		Token: token,
		DialTCP: func(ctx context.Context) (net.Conn, error) {
			c, s := net.Pipe()
			_ = s.Close()
			return c, nil
		},
		HandshakeTLS: func(ctx context.Context, rawConn net.Conn) (net.Conn, error) {
			tlsOpts := vmess.TLSConfig{
				Host:              "node.meybz.asia",
				ClientFingerprint: "none",
				ClientRandom: func() ([]byte, error) {
					return ClientRandomForToken(token)
				},
			}
			return vmess.StreamTLSConn(ctx, rawConn, &tlsOpts)
		},
	})
	defer pool.Close()

	_, err := pool.DialStream(context.Background())
	if !errors.Is(err, ErrFallbackToReality) {
		t.Fatalf("expected ErrFallbackToReality when ClientRandom cannot be applied, got %v", err)
	}
	if !pool.ShouldFallback() {
		t.Fatalf("expected pool.ShouldFallback() == true after hook error")
	}
}
