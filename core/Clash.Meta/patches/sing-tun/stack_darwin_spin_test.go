//go:build darwin && with_gvisor

package tun

import (
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/metacubex/gvisor/pkg/tcpip/stack"
	"github.com/metacubex/sing/common/buf"
	"github.com/metacubex/sing/common/logger"
)

// errTUN is a DarwinTUN whose BatchRead always fails the same way, emulating a
// utun descriptor that macOS tore down under us (sleep/wake, Wi-Fi roam,
// interface down). A correct read loop must give up; a buggy one spins.
type errTUN struct {
	Tun
	err   error
	reads atomic.Int64
}

func (t *errTUN) BatchRead() ([]*buf.Buffer, error) {
	t.reads.Add(1)
	return nil, t.err
}

func (t *errTUN) BatchWrite([]*buf.Buffer) error { return nil }

// emptyTUN returns "no packets, no error" forever — the silent variant that
// logs nothing at all.
type emptyTUN struct {
	Tun
	reads atomic.Int64
}

func (t *emptyTUN) BatchRead() ([]*buf.Buffer, error) {
	t.reads.Add(1)
	return nil, nil
}

func (t *emptyTUN) BatchWrite([]*buf.Buffer) error { return nil }

func mustExit(t *testing.T, name string, run func(), reads func() int64) {
	t.Helper()
	done := make(chan struct{})
	go func() {
		run()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatalf("%s: loop never exited — spun %d times in 3s (busy loop)", name, reads())
	}
}

func TestMixedBatchLoopDarwinExitsOnEBADF(t *testing.T) {
	m := &Mixed{System: &System{logger: logger.NOP()}}
	tun := &errTUN{err: syscall.EBADF}
	mustExit(t, "Mixed/EBADF", func() { m.batchLoopDarwin(tun) }, tun.reads.Load)
}

func TestSystemBatchLoopDarwinExitsOnEBADF(t *testing.T) {
	s := &System{logger: logger.NOP()}
	tun := &errTUN{err: syscall.EBADF}
	mustExit(t, "System/EBADF", func() { s.batchLoopDarwin(tun) }, tun.reads.Load)
}

func TestMixedBatchLoopDarwinExitsOnEndlessEmptyReads(t *testing.T) {
	m := &Mixed{System: &System{logger: logger.NOP()}}
	tun := &emptyTUN{}
	mustExit(t, "Mixed/empty", func() { m.batchLoopDarwin(tun) }, tun.reads.Load)
}

func TestSystemBatchLoopDarwinExitsOnEndlessEmptyReads(t *testing.T) {
	s := &System{logger: logger.NOP()}
	tun := &emptyTUN{}
	mustExit(t, "System/empty", func() { s.batchLoopDarwin(tun) }, tun.reads.Load)
}

// plainTUN implements ONLY Tun, so tunLoop falls through the WinTun / LinuxTUN /
// DarwinTUN branches and reaches the generic single-packet read loop.
type plainTUN struct {
	err   error
	reads atomic.Int64
}

func (t *plainTUN) Read(p []byte) (int, error)  { t.reads.Add(1); return 0, t.err }
func (t *plainTUN) Write(p []byte) (int, error) { return len(p), nil }
func (t *plainTUN) Close() error                { return nil }

// gvisorPlainTUN is the same thing widened to GVisorTun, which is what Mixed holds.
type gvisorPlainTUN struct{ plainTUN }

func (t *gvisorPlainTUN) WritePacket(*stack.PacketBuffer) (int, error) { return 0, nil }
func (t *gvisorPlainTUN) NewEndpoint() (stack.LinkEndpoint, stack.NICOptions, error) {
	return nil, stack.NICOptions{}, nil
}

func TestSystemTunLoopExitsOnEBADF(t *testing.T) {
	tun := &plainTUN{err: syscall.EBADF}
	s := &System{tun: tun, mtu: 1500, logger: logger.NOP()}
	mustExit(t, "System/tunLoop/EBADF", s.tunLoop, tun.reads.Load)
}

func TestSystemTunLoopExitsOnEndlessShortReads(t *testing.T) {
	tun := &plainTUN{}
	s := &System{tun: tun, mtu: 1500, logger: logger.NOP()}
	mustExit(t, "System/tunLoop/short", s.tunLoop, tun.reads.Load)
}

func TestMixedTunLoopExitsOnEBADF(t *testing.T) {
	tun := &gvisorPlainTUN{plainTUN{err: syscall.EBADF}}
	m := &Mixed{System: &System{mtu: 1500, logger: logger.NOP()}, tun: tun}
	mustExit(t, "Mixed/tunLoop/EBADF", m.tunLoop, tun.reads.Load)
}

func TestMixedTunLoopExitsOnEndlessShortReads(t *testing.T) {
	tun := &gvisorPlainTUN{plainTUN{}}
	m := &Mixed{System: &System{mtu: 1500, logger: logger.NOP()}, tun: tun}
	mustExit(t, "Mixed/tunLoop/short", m.tunLoop, tun.reads.Load)
}
