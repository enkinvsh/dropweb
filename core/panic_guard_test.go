package main

import (
	"strings"
	"testing"
)

// runGuarded: a swallowed panic must never be reported to Dart as success.

func TestRunGuardedReportsTrueWhenBodyCompletes(t *testing.T) {
	ran := false
	ok := runGuarded("noPanic", func() { ran = true })
	if !ran {
		t.Fatal("runGuarded did not run the body")
	}
	if !ok {
		t.Fatal("runGuarded(non-panicking) = false; want true")
	}
}

func TestRunGuardedReportsFalseWhenBodyPanics(t *testing.T) {
	ok := runGuarded("boom", func() { panic("boom") })
	if ok {
		t.Fatal("runGuarded(panicking) = true; want false -- a swallowed panic reported as success is the defect")
	}
}

func TestRunGuardedContainsThePanic(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("runGuarded let the panic escape to the caller: %v", r)
		}
	}()
	_ = runGuarded("boom", func() { panic("boom") })
}

func TestRunGuardedKeepsWorkDoneBeforeThePanic(t *testing.T) {
	steps := 0
	ok := runGuarded("partial", func() {
		steps++
		panic("stop")
	})
	if steps != 1 {
		t.Fatalf("body side effects = %d; want 1 (work before the panic still happens)", steps)
	}
	if ok {
		t.Fatal("partial completion reported as success")
	}
}

// recoverGoFn: a goroutine that owns a Dart port must always reply.

func TestRecoverGoFnDeliversErrorPayloadOnPanic(t *testing.T) {
	var got string
	called := 0
	func() {
		defer recoverGoFn("quickStart", func(msg string) {
			called++
			got = msg
		})
		panic("kaboom")
	}()
	if called != 1 {
		t.Fatalf("reply callback called %d times; want exactly 1 (Dart waits forever otherwise)", called)
	}
	if !strings.Contains(got, "quickStart") || !strings.Contains(got, "kaboom") {
		t.Fatalf("payload = %q; want it to name both the goroutine and the panic", got)
	}
}

func TestRecoverGoFnStaysSilentWithoutPanic(t *testing.T) {
	called := 0
	func() {
		defer recoverGoFn("quickStart", func(string) { called++ })
	}()
	if called != 0 {
		t.Fatalf("reply callback fired %d times on the happy path; want 0", called)
	}
}
