package outbound

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"io"
	"net"
	"testing"
	"time"

	"github.com/metacubex/mihomo/transport/drophaul"
)

func TestNewVlessWithHaulInitializesHaulPool(t *testing.T) {
	v, err := NewVless(VlessOption{
		Name:              "DE-Haul",
		Server:            "de-001.meybz.asia",
		Port:              443,
		UUID:              "11111111-2222-3333-4444-555555555555",
		TLS:               true,
		ServerName:        "ads.x5.ru",
		ClientFingerprint: "firefox",
		Haul:              true,
		RealityOpts: RealityOptions{
			PublicKey: "B7xK9PublicKeyBase64Url___________________8",
			ShortID:   "4f8a01",
		},
	})
	if err != nil {
		t.Fatalf("NewVless failed: %v", err)
	}
	defer v.Close()
	if v.haulPool == nil {
		t.Fatalf("expected haulPool to be initialized when Haul=true and RealityOpts is set")
	}
}

func TestNewVlessWithoutHaulLeavesHaulPoolNil(t *testing.T) {
	v, err := NewVless(VlessOption{
		Name:       "DE-Standard",
		Server:     "de-001.meybz.asia",
		Port:       443,
		UUID:       "11111111-2222-3333-4444-555555555555",
		TLS:        true,
		ServerName: "ads.x5.ru",
		Haul:       false,
		RealityOpts: RealityOptions{
			PublicKey: "B7xK9PublicKeyBase64Url___________________8",
			ShortID:   "4f8a01",
		},
	})
	if err != nil {
		t.Fatalf("NewVless failed: %v", err)
	}
	defer v.Close()
	if v.haulPool != nil {
		t.Fatalf("expected haulPool == nil when Haul=false")
	}
}

func TestVlessHaulHandshakeSendsMarkedClientRandom(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer ln.Close()

	recCh := make(chan []byte, 1)
	go func() {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		var hdr [5]byte
		if _, err := io.ReadFull(conn, hdr[:]); err != nil {
			return
		}
		recLen := int(binary.BigEndian.Uint16(hdr[3:5]))
		rec := make([]byte, 5+recLen)
		copy(rec[:5], hdr[:])
		if _, err := io.ReadFull(conn, rec[5:]); err != nil {
			return
		}
		recCh <- rec
	}()

	const pubKey = "B7xK9PublicKeyBase64Url___________________8"
	const shortID = "4f8a01"
	v, err := NewVless(VlessOption{
		Name:              "DE-Haul-Wire",
		Server:            "127.0.0.1",
		Port:              ln.Addr().(*net.TCPAddr).Port,
		UUID:              "11111111-2222-3333-4444-555555555555",
		TLS:               true,
		ServerName:        "ads.x5.ru",
		ClientFingerprint: "firefox",
		Haul:              true,
		RealityOpts: RealityOptions{
			PublicKey: pubKey,
			ShortID:   shortID,
		},
	})
	if err != nil {
		t.Fatalf("NewVless failed: %v", err)
	}
	defer v.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, _ = v.haulPool.DialStream(ctx)

	select {
	case rec := <-recCh:
		if len(rec) < 43 {
			t.Fatalf("record too short: %d", len(rec))
		}
		random := rec[11:43]
		key := drophaul.MarkKey(drophaul.DeriveToken(pubKey, shortID))
		var winBuf [8]byte
		binary.BigEndian.PutUint64(winBuf[:], uint64(time.Now().Unix()/60))
		mac := hmac.New(sha256.New, key)
		mac.Write(random[:16])
		mac.Write(winBuf[:])
		if !hmac.Equal(mac.Sum(nil)[:16], random[16:32]) {
			t.Fatalf("Vless haul ClientHello.Random %x does not carry valid drophaul mark", random)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for Vless haul ClientHello")
	}
}
