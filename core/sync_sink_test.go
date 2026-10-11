//go:build cgo

package main

import "testing"

func TestSyncSinkDeliversOnlyItsPort(t *testing.T) {
	port, ch := registerSyncSink()
	if port >= 0 {
		t.Fatalf("sync ports must be negative, got %d", port)
	}
	if deliverSync(ActionResult{Port: 42}) {
		t.Fatal("a Dart port must not be swallowed")
	}
	if !deliverSync(ActionResult{Port: port, Id: "x"}) {
		t.Fatal("registered port not delivered")
	}
	if got := <-ch; got.Id != "x" {
		t.Fatalf("got %q", got.Id)
	}
	// A late result (after iosInvokeAction timed out) must still be swallowed:
	// the extension has no Dart API, posting to a port would call a NULL pointer.
	if !deliverSync(ActionResult{Port: port}) {
		t.Fatal("a late sync result must not fall through to the Dart bridge")
	}
	select {
	case got := <-ch:
		t.Fatalf("a sink must deliver once, got a second result %+v", got)
	default:
	}
}
