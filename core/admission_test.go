package main

import (
	"testing"
	"time"
)

func newTestAdmission() *connectionAdmission {
	return &connectionAdmission{floor: 1 << 20, cost: 100 << 10, window: time.Second}
}

func TestAdmissionChargesNewConnectionsAgainstHeadroom(t *testing.T) {
	a := newTestAdmission()
	now := time.Now()
	available := int64(1<<20 + 3*(100<<10))
	for i := 0; i < 3; i++ {
		if !a.admit(available, now) {
			t.Fatalf("connection %d refused while headroom covers it", i)
		}
	}
	if a.admit(available, now) {
		t.Fatal("fourth connection admitted beyond the headroom")
	}
}

func TestAdmissionReleasesChargeAfterWindow(t *testing.T) {
	a := newTestAdmission()
	now := time.Now()
	available := int64(1<<20 + 100<<10)
	if !a.admit(available, now) {
		t.Fatal("first connection refused")
	}
	if a.admit(available, now.Add(500*time.Millisecond)) {
		t.Fatal("admitted while the previous connection is still charged")
	}
	if !a.admit(available, now.Add(time.Second)) {
		t.Fatal("refused after the previous charge expired")
	}
}

func TestAdmissionNeverSpendsTheFloor(t *testing.T) {
	a := newTestAdmission()
	if a.admit(1<<20+50<<10, time.Now()) {
		t.Fatal("admitted a connection that does not fit above the floor")
	}
	if a.admit(512<<10, time.Now()) {
		t.Fatal("admitted below the floor")
	}
}
