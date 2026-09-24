package main

// Regression: closeConnections must close EVERY tracker even when some
// Close() calls return an error (tcp/udpTracker.Close returns the underlying
// conn's Close error, e.g. a TLS close_notify write on a dead bearer).
// Previously the Range stopped at the first error and the rest stayed open.

import (
	"errors"
	"fmt"
	"sync/atomic"
	"testing"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

type errCloseTracker struct {
	id     string
	info   *statistic.TrackerInfo
	closed *atomic.Int32
}

func (a *errCloseTracker) ID() string                      { return a.id }
func (a *errCloseTracker) Info() *statistic.TrackerInfo    { return a.info }
func (a *errCloseTracker) Chains() C.Chain                 { return nil }
func (a *errCloseTracker) ProviderChains() C.Chain         { return nil }
func (a *errCloseTracker) AppendToChains(_ C.ProxyAdapter) {}
func (a *errCloseTracker) RemoteDestination() string       { return "" }
func (a *errCloseTracker) Close() error {
	a.closed.Add(1)
	statistic.DefaultManager.Leave(a)
	// Realistic: conn.Close on a dead-bearer TLS stream / already-closed socket.
	return errors.New("tls: failed to send closeNotify alert (but connection was closed anyway): broken pipe")
}

func TestCloseConnectionsClosesEveryTrackerDespiteCloseErrors(t *testing.T) {
	const n = 5
	var closed atomic.Int32
	for i := 0; i < n; i++ {
		statistic.DefaultManager.Join(&errCloseTracker{
			id:     fmt.Sprintf("close-all-%d", i),
			info:   &statistic.TrackerInfo{Metadata: &C.Metadata{}},
			closed: &closed,
		})
	}
	t.Cleanup(func() {
		for i := 0; i < n; i++ {
			if c := statistic.DefaultManager.Get(fmt.Sprintf("close-all-%d", i)); c != nil {
				statistic.DefaultManager.Leave(c)
			}
		}
	})

	ok := handleCloseConnections()

	survivors := 0
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool { survivors++; return true })
	if !ok {
		t.Fatalf("handleCloseConnections() = false")
	}
	if got := closed.Load(); got != n || survivors != 0 {
		t.Errorf("closeConnections closed %d of %d trackers, %d still live, yet reported success", got, n, survivors)
	}
}
