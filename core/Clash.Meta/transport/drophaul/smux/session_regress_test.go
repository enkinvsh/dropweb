package smux

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// regressConfig повторяет продовый конфиг пула (client.go NewPool), но без keepalive:
// иначе сессию мог бы закрыть keepalive, и тест не отличил бы починку от таймаута.
func regressConfig() *Config {
	return &Config{
		Version:           2,
		KeepAliveDisabled: true,
		MaxFrameSize:      32768,
		MaxReceiveBuffer:  4194304,
		MaxStreamBuffer:   262144,
	}
}

func rawFrame(ver, cmd byte, sid uint32, payload []byte) []byte {
	b := make([]byte, headerSize+len(payload))
	b[0] = ver
	b[1] = cmd
	binary.LittleEndian.PutUint16(b[2:], uint16(len(payload)))
	binary.LittleEndian.PutUint32(b[4:], sid)
	copy(b[headerSize:], payload)
	return b
}

type countingWriter struct{ n atomic.Int64 }

func (w *countingWriter) Write(p []byte) (int, error) {
	w.n.Add(int64(len(p)))
	return len(p), nil
}

// newRawPeer поднимает сессию на одном конце net.Pipe; второй конец — «сырой» пир,
// который пишет кадры руками, а всё входящее вычитывает в счётчик, чтобы sendLoop не залипал.
func newRawPeer(t *testing.T, client bool) (*Session, net.Conn, *countingWriter) {
	t.Helper()
	local, peer := net.Pipe()
	var (
		sess *Session
		err  error
	)
	if client {
		sess, err = Client(local, regressConfig())
	} else {
		sess, err = Server(local, regressConfig())
	}
	if err != nil {
		t.Fatalf("session: %v", err)
	}
	drained := &countingWriter{}
	go func() { _, _ = io.Copy(drained, peer) }()
	t.Cleanup(func() {
		_ = sess.Close()
		_ = peer.Close()
	})
	return sess, peer, drained
}

func waitUntil(t *testing.T, d time.Duration, what string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(d)
	for !cond() {
		if time.Now().After(deadline) {
			t.Fatalf("timeout after %v waiting for: %s", d, what)
		}
		time.Sleep(5 * time.Millisecond)
	}
}

// callWithin запускает fn в горутине и падает, если она не вернулась за d
// (зависший вызов под streamLock — ровно то, что ловят D1-тесты).
func callWithin(t *testing.T, d time.Duration, what string, fn func()) {
	t.Helper()
	done := make(chan struct{})
	go func() {
		defer close(done)
		fn()
	}()
	select {
	case <-done:
	case <-time.After(d):
		t.Fatalf("%s did not return within %v", what, d)
	}
}

func writeAsync(peer net.Conn, b []byte) {
	go func() { _, _ = peer.Write(b) }()
}

func TestRegressD1ClientRejectsSYN(t *testing.T) {
	sess, peer, _ := newRawPeer(t, true)

	var flood []byte
	for i := 0; i < 1100; i++ {
		flood = append(flood, rawFrame(2, cmdSYN, uint32(2+2*i), nil)...)
	}
	writeAsync(peer, flood)

	waitUntil(t, 2*time.Second, "client session closed after server-sent SYN", sess.IsClosed)
	callWithin(t, time.Second, "NumStreams", func() { _ = sess.NumStreams() })
	callWithin(t, time.Second, "OpenStream", func() {
		if _, err := sess.OpenStream(); err == nil {
			t.Error("OpenStream succeeded on a session that got a SYN from the server")
		}
	})
}

func TestRegressD1ServerAcceptBacklogNonBlocking(t *testing.T) {
	sess, peer, _ := newRawPeer(t, false)

	writeAsync(peer, rawFrame(2, cmdSYN, 1, nil))
	var st *Stream
	callWithin(t, 2*time.Second, "AcceptStream", func() {
		var err error
		st, err = sess.AcceptStream()
		if err != nil {
			t.Errorf("AcceptStream: %v", err)
		}
	})
	if st == nil {
		t.FailNow()
	}

	var flood []byte
	for i := 0; i < defaultAcceptBacklog+100; i++ {
		flood = append(flood, rawFrame(2, cmdSYN, uint32(3+2*i), nil)...)
	}
	flood = append(flood, rawFrame(2, cmdPSH, 1, []byte("hello"))...)
	writeAsync(peer, flood)

	_ = st.SetReadDeadline(time.Now().Add(2 * time.Second))
	buf := make([]byte, 16)
	n, err := st.Read(buf)
	if err != nil || string(buf[:n]) != "hello" {
		t.Fatalf("data on existing stream not delivered after SYN flood: n=%d err=%v", n, err)
	}
	callWithin(t, time.Second, "NumStreams", func() {
		if got, want := sess.NumStreams(), 1+defaultAcceptBacklog; got != want {
			t.Errorf("NumStreams=%d, want %d (overflow SYNs must be dropped)", got, want)
		}
	})
	if sess.IsClosed() {
		t.Fatal("server session must survive a SYN flood")
	}
}

func TestRegressD2ProtoErrorClosesSession(t *testing.T) {
	sess, peer, _ := newRawPeer(t, true)

	writeAsync(peer, rawFrame(2, 0x7f, 0, nil))

	waitUntil(t, 2*time.Second, "session closed after unknown cmd", sess.IsClosed)
	callWithin(t, time.Second, "OpenStream", func() {
		if _, err := sess.OpenStream(); err == nil {
			t.Error("OpenStream succeeded after protocol error")
		}
	})
}

func TestRegressD2ReadErrorClosesSession(t *testing.T) {
	sess, peer, _ := newRawPeer(t, true)

	_ = peer.Close()

	waitUntil(t, 2*time.Second, "session closed after socket read error", sess.IsClosed)
	callWithin(t, time.Second, "OpenStream", func() {
		if _, err := sess.OpenStream(); err == nil {
			t.Error("OpenStream succeeded after socket read error")
		}
	})
}

func TestRegressD2BlockedWriteWakesOnProtoError(t *testing.T) {
	sess, peer, drained := newRawPeer(t, true)

	st, err := sess.OpenStream()
	if err != nil {
		t.Fatalf("OpenStream: %v", err)
	}

	type res struct {
		n   int
		err error
	}
	writeDone := make(chan res, 1)
	go func() {
		n, err := st.Write(make([]byte, initialPeerWindow+100000))
		writeDone <- res{n, err}
	}()
	readDone := make(chan error, 1)
	go func() {
		_, err := st.Read(make([]byte, 16))
		readDone <- err
	}()

	// Ждём, пока писатель выберет всё стартовое окно пира и встанет на ожидании UPD.
	waitUntil(t, 2*time.Second, "initial window flushed", func() bool {
		return drained.n.Load() >= int64(initialPeerWindow)
	})

	writeAsync(peer, rawFrame(9, cmdNOP, 0, nil))

	select {
	case r := <-writeDone:
		if r.err == nil {
			t.Fatalf("blocked Write returned nil error after protocol error (n=%d)", r.n)
		}
		if r.n > initialPeerWindow {
			t.Fatalf("Write reported n=%d > peer window %d", r.n, initialPeerWindow)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Write blocked on v2 window did not wake up after protocol error")
	}
	select {
	case err := <-readDone:
		if !errors.Is(err, ErrInvalidProtocol) {
			t.Fatalf("pending Read err=%v, want %v", err, ErrInvalidProtocol)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("pending Read did not wake up after protocol error")
	}
	waitUntil(t, 2*time.Second, "session closed", sess.IsClosed)
}

func TestRegressD2BufferedDataReadableAfterProtoError(t *testing.T) {
	sess, peer, _ := newRawPeer(t, true)

	st, err := sess.OpenStream()
	if err != nil {
		t.Fatalf("OpenStream: %v", err)
	}
	var b []byte
	b = append(b, rawFrame(2, cmdPSH, st.ID(), []byte("hello"))...)
	b = append(b, rawFrame(2, 0x7f, 0, nil)...)
	writeAsync(peer, b)

	waitUntil(t, 2*time.Second, "session closed after protocol error", sess.IsClosed)

	buf := make([]byte, 16)
	n, err := st.Read(buf)
	if err != nil || string(buf[:n]) != "hello" {
		t.Fatalf("buffered data lost after session close: n=%d data=%q err=%v", n, buf[:n], err)
	}
	for i := 0; i < 3; i++ {
		if _, err := st.Read(buf); !errors.Is(err, ErrInvalidProtocol) {
			t.Fatalf("Read after drain: err=%v, want %v", err, ErrInvalidProtocol)
		}
	}
}

// TestRegressD5WriteReportsSentOnAbort: Write, упёршийся в окно пира, при FIN или
// ErrConsumed обязан вернуть уже отправленные байты, а не 0.
func TestRegressD5WriteReportsSentOnAbort(t *testing.T) {
	cases := []struct {
		name    string
		abort   func(sid uint32) []byte
		wantErr error
	}{
		{"fin", func(sid uint32) []byte { return rawFrame(2, cmdFIN, sid, nil) }, io.EOF},
		{"consumed", func(sid uint32) []byte {
			var upd [szCmdUPD]byte
			binary.LittleEndian.PutUint32(upd[:], initialPeerWindow+1)
			binary.LittleEndian.PutUint32(upd[4:], initialPeerWindow)
			return rawFrame(2, cmdUPD, sid, upd[:])
		}, ErrConsumed},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			sess, peer, drained := newRawPeer(t, true)
			st, err := sess.OpenStream()
			if err != nil {
				t.Fatalf("OpenStream: %v", err)
			}
			type res struct {
				n   int
				err error
			}
			done := make(chan res, 1)
			go func() {
				n, err := st.Write(make([]byte, initialPeerWindow+100000))
				done <- res{n, err}
			}()
			waitUntil(t, 2*time.Second, "initial window flushed", func() bool {
				return drained.n.Load() >= int64(initialPeerWindow)
			})
			writeAsync(peer, tc.abort(st.ID()))
			select {
			case r := <-done:
				if !errors.Is(r.err, tc.wantErr) || r.n != initialPeerWindow {
					t.Fatalf("Write = (%d, %v), want (%d, %v)", r.n, r.err, initialPeerWindow, tc.wantErr)
				}
			case <-time.After(2 * time.Second):
				t.Fatal("Write did not return after abort")
			}
		})
	}
}

// wireConn отмечает, что sendLoop сейчас внутри conn.Write: по нему тест понимает,
// что sendLoop застрял на непрочитанном пиром батче.
type wireConn struct {
	net.Conn
	writing atomic.Int32
}

func (c *wireConn) Write(p []byte) (int, error) {
	c.writing.Add(1)
	defer c.writing.Add(-1)
	return c.Conn.Write(p)
}

// gatedPeer читает сокет маленькими порциями и умеет «замирать», чтобы
// запросы копились в writeQ, пока sendLoop висит в conn.Write.
type gatedPeer struct {
	conn   net.Conn
	paused atomic.Bool
	mu     sync.Mutex
	data   []byte
}

func (g *gatedPeer) loop() {
	buf := make([]byte, 1024)
	for {
		for g.paused.Load() {
			time.Sleep(time.Millisecond)
		}
		n, err := g.conn.Read(buf)
		g.mu.Lock()
		g.data = append(g.data, buf[:n]...)
		g.mu.Unlock()
		if err != nil {
			return
		}
	}
}

// payload разбирает захваченный поток кадров и склеивает PSH-данные стрима sid.
// Недочитанный хвостовой кадр допустим; мусорный заголовок — провал теста.
func (g *gatedPeer) payload(t *testing.T, sid uint32) []byte {
	t.Helper()
	g.mu.Lock()
	wire := append([]byte(nil), g.data...)
	g.mu.Unlock()
	var out []byte
	for len(wire) >= headerSize {
		var h rawHeader
		copy(h[:], wire)
		if h.Version() != 2 || h.Cmd() > cmdPAD {
			t.Fatalf("corrupt frame on wire: %s", h)
		}
		end := headerSize + int(h.Length())
		if len(wire) < end {
			break
		}
		if h.Cmd() == cmdPSH && h.StreamID() == sid {
			out = append(out, wire[headerSize:end]...)
		}
		wire = wire[end:]
	}
	return out
}

func newGatedSession(t *testing.T, padding bool) (*Session, *wireConn, *gatedPeer) {
	t.Helper()
	local, peer := net.Pipe()
	wc := &wireConn{Conn: local}
	cfg := regressConfig()
	cfg.Padding = padding
	sess, err := Client(wc, cfg)
	if err != nil {
		t.Fatalf("Client: %v", err)
	}
	g := &gatedPeer{conn: peer}
	go g.loop()
	t.Cleanup(func() {
		g.paused.Store(false)
		_ = sess.Close()
		_ = peer.Close()
	})
	return sess, wc, g
}

// stallSendLoop замораживает пира и отдаёт блокирующую запись blocker, после чего
// sendLoop висит в conn.Write; возвращает канал с результатом этой записи.
func stallSendLoop(t *testing.T, st *Stream, wc *wireConn, g *gatedPeer, blocker []byte) <-chan error {
	t.Helper()
	g.paused.Store(true)
	done := make(chan error, 1)
	go func() {
		n, err := st.Write(blocker)
		if err == nil && n != len(blocker) {
			err = io.ErrShortWrite
		}
		done <- err
	}()
	waitUntil(t, 2*time.Second, "sendLoop blocked in conn.Write", func() bool {
		return wc.writing.Load() == 1
	})
	return done
}

func fill(n int, b byte) []byte {
	p := make([]byte, n)
	for i := range p {
		p[i] = b
	}
	return p
}

func TestRegressD3CancelledWriteNeverReachesWire(t *testing.T) {
	for _, padding := range []bool{false, true} {
		t.Run(fmt.Sprintf("padding=%v", padding), func(t *testing.T) {
			sess, wc, g := newGatedSession(t, padding)
			st, err := sess.OpenStream()
			if err != nil {
				t.Fatalf("OpenStream: %v", err)
			}
			blocker := fill(16384, 0xBB)
			blockerDone := stallSendLoop(t, st, wc, g, blocker)

			marker := fill(4096, 0xEE)
			_ = st.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
			n, err := st.Write(marker)
			if n != 0 || err != ErrTimeout {
				t.Fatalf("timed-out Write = (%d, %v), want (0, %v)", n, err, ErrTimeout)
			}
			// Вызывающий вправе переиспользовать буфер, о котором ему сказали «не записано».
			copy(marker, fill(len(marker), 0x00))

			_ = st.SetWriteDeadline(time.Time{})
			g.paused.Store(false)
			if err := <-blockerDone; err != nil {
				t.Fatalf("blocker Write: %v", err)
			}
			tail := fill(4096, 0xAA)
			if n, err := st.Write(tail); n != len(tail) || err != nil {
				t.Fatalf("Write after timeout = (%d, %v)", n, err)
			}

			want := append(append([]byte(nil), blocker...), tail...)
			var got []byte
			waitUntil(t, 2*time.Second, "all committed bytes on the wire", func() bool {
				got = g.payload(t, st.ID())
				return len(got) >= len(want)
			})
			if !bytes.Equal(got, want) {
				t.Fatalf("stream payload mismatch: got %d bytes, want %d (cancelled write leaked to the wire)", len(got), len(want))
			}
		})
	}
}

func TestRegressD3NumWrittenNotInflated(t *testing.T) {
	sess, wc, g := newGatedSession(t, false)
	st, err := sess.OpenStream()
	if err != nil {
		t.Fatalf("OpenStream: %v", err)
	}
	blocker := fill(16384, 0xBB)
	blockerDone := stallSendLoop(t, st, wc, g, blocker)

	for i := 0; i < 4; i++ {
		_ = st.SetWriteDeadline(time.Now().Add(50 * time.Millisecond))
		if n, err := st.Write(fill(65536, 0xEE)); n != 0 || err != ErrTimeout {
			t.Fatalf("timed-out Write #%d = (%d, %v), want (0, %v)", i, n, err, ErrTimeout)
		}
	}

	g.paused.Store(false)
	if err := <-blockerDone; err != nil {
		t.Fatalf("blocker Write: %v", err)
	}
	// Пир не шлёт UPD, поэтому остаток окна — ровно initialPeerWindow минус блокер;
	// отменённые байты не должны его съедать.
	rest := initialPeerWindow - len(blocker)
	_ = st.SetWriteDeadline(time.Now().Add(2 * time.Second))
	if n, err := st.Write(fill(rest, 0xAA)); n != rest || err != nil {
		t.Fatalf("Write of remaining window = (%d, %v), want (%d, nil)", n, err, rest)
	}
}

func TestRegressD4WindowGrowthCapped(t *testing.T) {
	cfg := regressConfig()
	base := uint32(cfg.MaxStreamBuffer)
	maxRecv := uint32(cfg.MaxReceiveBuffer)
	oldCeiling := base * 4
	if oldCeiling > maxRecv/2 {
		oldCeiling = maxRecv / 2
	}

	for numStreams := 1; numStreams <= 16; numStreams++ {
		sess := &Session{config: cfg, streams: make(map[uint32]*Stream), bucket: int32(maxRecv)}
		var st *Stream
		for i := 0; i < numStreams; i++ {
			st = newStream(uint32(1+2*i), cfg.MaxFrameSize, sess)
			sess.streams[st.id] = st
		}
		w := st.effectiveStreamWindow(base * 3)
		if w < base || w > oldCeiling {
			t.Fatalf("streams=%d: window %d out of [%d, %d]", numStreams, w, base, oldCeiling)
		}
		// Выросшие сверх base окна всех стримов вместе не должны забирать
		// больше половины общего бюджета, иначе застрявшие читатели душат сессию.
		if w > base && uint64(w)*uint64(numStreams) > uint64(maxRecv/2) {
			t.Fatalf("streams=%d: window %d * streams = %d exceeds half of session budget %d",
				numStreams, w, uint64(w)*uint64(numStreams), maxRecv/2)
		}
		if numStreams == 1 && w != oldCeiling {
			t.Fatalf("single stream must keep full growth: got %d want %d", w, oldCeiling)
		}
	}
}
