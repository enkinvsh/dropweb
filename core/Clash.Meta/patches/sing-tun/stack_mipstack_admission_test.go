package tun

import (
	"context"
	"net"
	"net/netip"
	"sync/atomic"
	"testing"
	"time"

	M "github.com/metacubex/sing/common/metadata"
)

func TestMipsDropsTCPConnectionsThatAreNotAdmitted(t *testing.T) {
	var admit atomic.Bool
	AdmitConnection = admit.Load
	t.Cleanup(func() { AdmitConnection = nil })
	d := newMemoryTun()
	accepted := make(chan struct{}, 1)
	testStack(t, d, &testHandler{tcp: func(_ context.Context, c net.Conn, _ M.Metadata) error {
		accepted <- struct{}{}
		return c.Close()
	}}, nil)
	source, target := netip.MustParseAddr("198.18.0.1"), netip.MustParseAddr("8.8.8.8")

	d.in <- tcpPacket(source, target, 100, 0, 2, nil)
	select {
	case p := <-d.out:
		t.Fatalf("a refused SYN must be dropped silently, got %x", p)
	case <-accepted:
		t.Fatal("a refused connection reached the handler")
	case <-time.After(300 * time.Millisecond):
	}

	admit.Store(true)
	d.in <- tcpPacket(source, target, 100, 0, 2, nil) // the client retransmits
	if synAck := readPacket(t, d); synAck[20+13]&18 != 18 {
		t.Fatalf("expected SYN ACK once admitted: %x", synAck)
	}
}
