package outbound

import (
	"testing"
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
