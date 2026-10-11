//go:build cgo

package main

import (
	"sync"
	"sync/atomic"
)

// Sync sinks let a caller without a Dart port (the iOS tunnel extension) wait
// for an action result. Ports <= -1000 are sync ports; -1 means "no port".
var (
	syncSinks    sync.Map
	lastSyncPort atomic.Int64
)

func init() { lastSyncPort.Store(-1000) }

func registerSyncSink() (int64, chan ActionResult) {
	port := lastSyncPort.Add(-1)
	ch := make(chan ActionResult, 1)
	syncSinks.Store(port, ch)
	return port, ch
}

// deliverSync claims every sync port, even when its sink is gone (the caller
// timed out): the extension never initialises the Dart API, so letting such a
// result reach bridge.SendToPort would call a NULL Dart_PostCObject_DL.
func deliverSync(result ActionResult) bool {
	if result.Port > -1000 {
		return false
	}
	if value, ok := syncSinks.LoadAndDelete(result.Port); ok {
		value.(chan ActionResult) <- result
	}
	return true
}
