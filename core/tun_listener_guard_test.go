package main

import (
	"encoding/json"
	"testing"
)

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

func TestStartListenerResult(t *testing.T) {
	tests := []struct {
		name      string
		requested bool
		effective bool
		tunError  string
		wantOK    bool
		wantError *string
	}{
		{
			name:      "proxy only succeeds",
			requested: false,
			effective: false,
			wantOK:    true,
		},
		{
			name:      "requested effective tun succeeds",
			requested: true,
			effective: true,
			wantOK:    true,
		},
		{
			name:      "native tun failure preserves exact cause",
			requested: true,
			effective: false,
			tunError:  "wintun: adapter is already in use",
			wantOK:    false,
			wantError: stringPointer("wintun: adapter is already in use"),
		},
		{
			name:      "empty native cause uses deterministic fallback",
			requested: true,
			effective: false,
			wantOK:    false,
			wantError: stringPointer(tunStartFallbackError),
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := startListenerResult(test.requested, test.effective, test.tunError)

			if result.Ok != test.wantOK {
				t.Fatalf("StartListenerResult.Ok = %v, want %v", result.Ok, test.wantOK)
			}
			if !equalOptionalString(result.TunError, test.wantError) {
				t.Fatalf("StartListenerResult.TunError = %v, want %v", result.TunError, test.wantError)
			}
			payload, err := json.Marshal(result)
			if err != nil {
				t.Fatalf("json.Marshal(StartListenerResult): %v", err)
			}
			var object map[string]any
			if err := json.Unmarshal(payload, &object); err != nil {
				t.Fatalf("json.Unmarshal(StartListenerResult): %v", err)
			}
			if _, exists := object["ok"]; !exists {
				t.Fatal("serialized StartListenerResult is missing ok")
			}
			if _, exists := object["tunError"]; !exists {
				t.Fatal("serialized StartListenerResult is missing tunError")
			}
		})
	}
}

func stringPointer(value string) *string {
	return &value
}

func equalOptionalString(left, right *string) bool {
	if left == nil || right == nil {
		return left == nil && right == nil
	}
	return *left == *right
}
