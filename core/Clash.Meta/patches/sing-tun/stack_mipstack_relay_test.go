package tun

import (
	"context"
	"encoding/binary"
	"net"
	"net/netip"
	"testing"
	"time"

	"github.com/metacubex/sing/common"
	M "github.com/metacubex/sing/common/metadata"
	N "github.com/metacubex/sing/common/network"
)

func TestMipsRelayBuffersFollowLowMemory(t *testing.T) {
	d := newMemoryTun()
	conns := make(chan net.Conn, 1)
	testStack(t, d, &testHandler{tcp: func(_ context.Context, c net.Conn, _ M.Metadata) error {
		conns <- c
		return nil
	}}, nil)
	source, target := netip.MustParseAddr("198.18.0.1"), netip.MustParseAddr("8.8.8.8")
	d.in <- tcpPacket(source, target, 100, 0, 2, nil)
	synAck := readPacket(t, d)
	d.in <- tcpPacket(source, target, 101, binary.BigEndian.Uint32(synAck[20+4:])+1, 16, nil)

	var conn net.Conn
	select {
	case conn = <-conns:
	case <-time.After(3 * time.Second):
		t.Fatal("connection did not reach the handler")
	}
	defer conn.Close()

	want := 0
	if common.LowMemory {
		want = 1500 // the TUN MTU, instead of 16 KB per direction
	}
	if got := N.CalculateMTU(conn, nil); got != want {
		t.Errorf("relay buffer reading from the TUN: got %d, want %d", got, want)
	}
	if got := N.CalculateMTU(nil, conn); got != want {
		t.Errorf("relay buffer writing to the TUN: got %d, want %d", got, want)
	}
}
