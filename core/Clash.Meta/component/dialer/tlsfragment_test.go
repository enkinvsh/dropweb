package dialer

import (
	"bytes"
	"context"
	"crypto/tls"
	"net"
	"testing"
	"time"
)

// captureConn records each Write call's payload.
type captureConn struct {
	net.Conn
	writes [][]byte
}

func (c *captureConn) Write(b []byte) (int, error) {
	c.writes = append(c.writes, append([]byte(nil), b...))
	return len(b), nil
}

// fakeHello is a record that looks like a TLS ClientHello header but has no
// parseable SNI; it exercises the fallback path.
func fakeHello(size int) []byte {
	b := make([]byte, size)
	b[0] = 0x16
	b[1] = 0x03
	b[2] = 0x01
	return b
}

// realClientHello captures a genuine TLS ClientHello (with SNI=host) produced
// by the standard crypto/tls stack.
func realClientHello(t *testing.T, host string) []byte {
	t.Helper()
	cConn, sConn := net.Pipe()
	got := make(chan []byte, 1)
	go func() {
		buf := make([]byte, 8192)
		_ = sConn.SetReadDeadline(time.Now().Add(2 * time.Second))
		n, _ := sConn.Read(buf)
		got <- append([]byte(nil), buf[:n]...)
	}()
	tlsConn := tls.Client(cConn, &tls.Config{
		ServerName:         host,
		InsecureSkipVerify: true,
		MinVersion:         tls.VersionTLS12,
	})
	go func() { _ = tlsConn.Handshake() }()
	hello := <-got
	_ = cConn.Close()
	_ = sConn.Close()
	if len(hello) == 0 || !isTLSClientHello(hello) {
		t.Fatalf("failed to capture a ClientHello (got %d bytes)", len(hello))
	}
	return hello
}

func TestSniHostRangeOnRealClientHello(t *testing.T) {
	host := "cascade.dropweb.org"
	hello := realClientHello(t, host)
	s, e, ok := sniHostRange(hello)
	if !ok {
		t.Fatalf("SNI not located in a real ClientHello")
	}
	if got := string(hello[s:e]); got != host {
		t.Fatalf("SNI range mismatch: got %q want %q", got, host)
	}
}

func TestFragmentSplitsSNIInMemory(t *testing.T) {
	host := "cascade.dropweb.org"
	hello := realClientHello(t, host)
	cap := &captureConn{}
	conn := newTLSFragmentConn(cap, 8, 0)
	if _, err := conn.Write(hello); err != nil {
		t.Fatalf("write: %v", err)
	}
	if len(cap.writes) < 2 {
		t.Fatalf("ClientHello not fragmented: %d segments", len(cap.writes))
	}
	for i, w := range cap.writes {
		if bytes.Contains(w, []byte(host)) {
			t.Fatalf("segment %d still contains the full SNI %q", i, host)
		}
	}
	var all []byte
	for _, w := range cap.writes {
		all = append(all, w...)
	}
	if !bytes.Equal(all, hello) {
		t.Fatal("reassembled bytes differ from original ClientHello")
	}
}

func TestFragmentPassthroughNonTLS(t *testing.T) {
	cap := &captureConn{}
	conn := newTLSFragmentConn(cap, 8, 0)
	if _, err := conn.Write(make([]byte, 100)); err != nil { // b[0]=0, not TLS
		t.Fatalf("write: %v", err)
	}
	if len(cap.writes) != 1 {
		t.Fatalf("non-TLS first write must pass through as 1 write, got %d", len(cap.writes))
	}
}

func TestFragmentFallbackThreeWay(t *testing.T) {
	cap := &captureConn{}
	conn := newTLSFragmentConn(cap, 8, 0)
	if _, err := conn.Write(fakeHello(99)); err != nil { // looks like TLS, no SNI
		t.Fatalf("write: %v", err)
	}
	if len(cap.writes) != 3 {
		t.Fatalf("unparseable ClientHello must fall back to 3 segments, got %d", len(cap.writes))
	}
}

func TestFragmentOnlyFirstWrite(t *testing.T) {
	cap := &captureConn{}
	conn := newTLSFragmentConn(cap, 8, 0)
	_, _ = conn.Write(fakeHello(99)) // fragmented (fallback)
	after := len(cap.writes)
	_, _ = conn.Write(fakeHello(99)) // must pass through whole
	if len(cap.writes) != after+1 {
		t.Fatalf("subsequent write should be single, got %d new", len(cap.writes)-after)
	}
}

func TestWrapTLSFragmentRespectsGlobal(t *testing.T) {
	DefaultTLSFragment.Store(false)
	off := &captureConn{}
	c, _ := wrapTLSFragment(off, nil, option{})
	_, _ = c.Write(fakeHello(99))
	if len(off.writes) != 1 {
		t.Fatalf("global off must not fragment, got %d writes", len(off.writes))
	}

	DefaultTLSFragment.Store(true)
	DefaultTLSFragmentSize.Store(8)
	on := &captureConn{}
	c2, _ := wrapTLSFragment(on, nil, option{})
	_, _ = c2.Write(fakeHello(99))
	if len(on.writes) <= 1 {
		t.Fatalf("global on must fragment, got %d writes", len(on.writes))
	}
	DefaultTLSFragment.Store(false)
}

// TestDialContextSplitsSNIOverRealSocket is the end-to-end proof: a genuine
// ClientHello sent through the production DialContext + config-global path
// arrives, on a real TCP socket, with its SNI split across segments such that
// no single segment carries the full hostname.
func TestDialContextSplitsSNIOverRealSocket(t *testing.T) {
	host := "cascade.dropweb.org"
	hello := realClientHello(t, host)

	ln, err := net.ListenTCP("tcp", &net.TCPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer ln.Close()

	got := make(chan [][]byte, 1)
	go func() {
		conn, err := ln.Accept()
		if err != nil {
			got <- nil
			return
		}
		defer conn.Close()
		_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))
		var segs [][]byte
		buf := make([]byte, 4096)
		total := 0
		for total < len(hello) {
			n, err := conn.Read(buf)
			if n > 0 {
				segs = append(segs, append([]byte(nil), buf[:n]...))
				total += n
			}
			if err != nil {
				break
			}
		}
		got <- segs
	}()

	DefaultTLSFragment.Store(true)
	DefaultTLSFragmentSize.Store(8)
	DefaultTLSFragmentDelay.Store(5)
	defer DefaultTLSFragment.Store(false)

	conn, err := DialContext(context.Background(), "tcp", ln.Addr().String())
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	if _, err := conn.Write(hello); err != nil {
		t.Fatalf("write: %v", err)
	}
	time.Sleep(200 * time.Millisecond)
	conn.Close()

	segs := <-got
	if len(segs) < 2 {
		t.Fatalf("ClientHello arrived unfragmented on the wire: %d segments", len(segs))
	}
	for i, s := range segs {
		if bytes.Contains(s, []byte(host)) {
			t.Fatalf("wire segment %d still carries the full SNI %q", i, host)
		}
	}
	t.Logf("wire: %d segments, SNI %q split across them (no segment carries it whole)", len(segs), host)
}
