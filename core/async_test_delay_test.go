package main

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/metacubex/mihomo/constant"
)

// asyncTestDelayReply runs the real handleAsyncTestDelay and returns the single
// reply it hands the Dart bridge. The work is dispatched through mBatch, so the
// reply arrives on another goroutine.
func asyncTestDelayReply(t *testing.T, params TestDelayParams) Delay {
	t.Helper()
	paramsString, err := json.Marshal(params)
	if err != nil {
		t.Fatalf("json.Marshal(TestDelayParams): %v", err)
	}

	replies := make(chan string, 1)
	handleAsyncTestDelay(string(paramsString), func(value string) {
		select {
		case replies <- value:
		default:
		}
	})

	select {
	case raw := <-replies:
		var delay Delay
		if err := json.Unmarshal([]byte(raw), &delay); err != nil {
			t.Fatalf("reply %q does not decode as Delay: %v", raw, err)
		}
		return delay
	case <-time.After(5 * time.Second):
		t.Fatal("handleAsyncTestDelay never replied")
		return Delay{}
	}
}

// No core is running under `go test`, so the proxy lookup always misses and the
// nil-proxy branch answers. Dart keys its delay map by the (url, name) pair it
// asked for; a reply that drops either field is written under a foreign key and
// the badge that requested the measurement never sees it.
func TestAsyncTestDelayUnknownProxyEchoesRequestedKey(t *testing.T) {
	tests := []struct {
		name      string
		proxyName string
		testUrl   string
		wantUrl   string
	}{
		{
			name:      "explicit test url is echoed back",
			proxyName: "nl-001",
			testUrl:   "https://cp.cloudflare.com/generate_204",
			wantUrl:   "https://cp.cloudflare.com/generate_204",
		},
		{
			name:      "omitted test url resolves to the core default",
			proxyName: "de-002",
			testUrl:   "",
			wantUrl:   constant.DefaultTestURL,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			delay := asyncTestDelayReply(t, TestDelayParams{
				ProxyName: test.proxyName,
				TestUrl:   test.testUrl,
				Timeout:   1000,
			})

			if delay.Name != test.proxyName {
				t.Fatalf("Delay.Name = %q, want %q", delay.Name, test.proxyName)
			}
			if delay.Url != test.wantUrl {
				t.Fatalf("Delay.Url = %q, want %q", delay.Url, test.wantUrl)
			}
			if delay.Value != -1 {
				t.Fatalf("Delay.Value = %d, want -1 (unreachable)", delay.Value)
			}
		})
	}
}
