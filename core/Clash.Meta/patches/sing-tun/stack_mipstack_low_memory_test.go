package tun

import (
	"testing"

	"github.com/metacubex/mipstack"
	"github.com/metacubex/sing/common"
)

func TestMipstackConfigBuffersFollowLowMemory(t *testing.T) {
	config := (&Mipstack{mtu: 1500}).config()
	stack, err := mipstack.New(config)
	if err != nil {
		t.Fatal(err)
	}
	_ = stack.Close()

	if !common.LowMemory {
		if config.TCP.MaximumReceiveBuffer != 0 || config.TCP.MaximumSendBuffer != 0 {
			t.Fatal("default builds must keep mipstack's own buffer limits")
		}
		return
	}
	const limit = 256 * 1024
	if config.TCP.MaximumReceiveBuffer == 0 || config.TCP.MaximumReceiveBuffer > limit ||
		config.TCP.MaximumSendBuffer == 0 || config.TCP.MaximumSendBuffer > limit {
		t.Fatalf("TCP buffers not capped: %+v", config.TCP)
	}
	if config.UDP.ReceiveBuffer == 0 || config.UDP.ReceiveBuffer > limit ||
		config.IP.ReceiveBuffer == 0 || config.IP.ReceiveBuffer > limit {
		t.Fatalf("datagram buffers not capped: udp %d ip %d", config.UDP.ReceiveBuffer, config.IP.ReceiveBuffer)
	}
}
