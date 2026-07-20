package main

import "testing"

func TestShouldFailMissingTunListener(t *testing.T) {
	tests := []struct {
		name      string
		running   bool
		requested bool
		effective bool
		want      bool
	}{
		{name: "profile apply before connect", running: false, requested: true, effective: false, want: false},
		{name: "connected listener missing", running: true, requested: true, effective: false, want: true},
		{name: "connected listener active", running: true, requested: true, effective: true, want: false},
		{name: "tun not requested", running: true, requested: false, effective: false, want: false},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := shouldFailMissingTunListener(test.running, test.requested, test.effective); got != test.want {
				t.Fatalf("shouldFailMissingTunListener() = %v, want %v", got, test.want)
			}
		})
	}
}
