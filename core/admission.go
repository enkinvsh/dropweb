package main

import (
	"sync"
	"time"
)

// connectionAdmission paces new connections by memory headroom. Each admitted
// connection is charged its expected cost for window, roughly the time it
// takes to finish its handshakes and settle; a new one is admitted only while
// the headroom above floor covers every charged connection.
type connectionAdmission struct {
	floor  int64
	cost   int64
	window time.Duration

	mu     sync.Mutex
	recent []time.Time
}

func (a *connectionAdmission) admit(available int64, now time.Time) bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	expired := 0
	for expired < len(a.recent) && now.Sub(a.recent[expired]) >= a.window {
		expired++
	}
	a.recent = append(a.recent[:0], a.recent[expired:]...)
	if int64(len(a.recent)) >= (available-a.floor)/a.cost {
		return false
	}
	a.recent = append(a.recent, now)
	return true
}
