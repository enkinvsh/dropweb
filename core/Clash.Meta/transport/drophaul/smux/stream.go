package smux

import (
	"encoding/binary"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

const (
	// Голосовые и интерактивные датаграммы (RTP/SRTP/STUN/XUDP) помещаются в один MTU
	// и не накапливают большой хвост неподтверждённых байт в стриме.
	realtimeMaxPayload  = 1400
	realtimeMaxInflight = 32 * 1024
)

type Stream struct {
	id   uint32
	sess *Session

	buffers [][]byte
	heads   [][]byte

	bufferLock sync.Mutex
	frameSize  int

	chReadEvent chan struct{}

	die     chan struct{}
	dieOnce sync.Once

	chFinEvent   chan struct{}
	finEventOnce sync.Once

	readDeadline  atomic.Value
	writeDeadline atomic.Value

	numRead    uint32
	numWritten uint32
	incr       uint32

	peerConsumed uint32
	peerWindow   uint32
	chUpdate     chan struct{}

	padWrites uint32
}

func newStream(id uint32, frameSize int, sess *Session) *Stream {
	s := new(Stream)
	s.id = id
	s.chReadEvent = make(chan struct{}, 1)
	s.chUpdate = make(chan struct{}, 1)
	s.frameSize = frameSize
	s.sess = sess
	s.die = make(chan struct{})
	s.chFinEvent = make(chan struct{})
	s.peerWindow = initialPeerWindow
	return s
}

func (s *Stream) ID() uint32 {
	return s.id
}

func (s *Stream) Read(b []byte) (n int, err error) {
	for {
		n, err = s.tryRead(b)
		if err == ErrWouldBlock {
			if ew := s.waitRead(); ew != nil {
				return 0, ew
			}
		} else {
			return n, err
		}
	}
}

func (s *Stream) tryRead(b []byte) (n int, err error) {
	if s.sess.config.Version == 2 {
		return s.tryReadv2(b)
	}

	if len(b) == 0 {
		return 0, nil
	}

	s.bufferLock.Lock()
	if len(s.buffers) > 0 {
		n = copy(b, s.buffers[0])
		s.buffers[0] = s.buffers[0][n:]
		if len(s.buffers[0]) == 0 {
			s.buffers[0] = nil
			s.buffers = s.buffers[1:]
			defaultAllocator.Put(s.heads[0])
			s.heads = s.heads[1:]
		}
	}
	s.bufferLock.Unlock()

	if n > 0 {
		s.sess.returnTokens(n)
		return n, nil
	}

	select {
	case <-s.die:
		return 0, s.dieReadErr()
	default:
		return 0, ErrWouldBlock
	}
}

// dieReadErr — ошибка чтения из закрытого и уже вычитанного стрима. Сессия
// закрывается при остановке recvLoop, поэтому die закрыт и при ошибке сокета/протокола:
// отдаём реальную причину, а не io.EOF, чтобы обрыв не выглядел как штатный конец данных.
// Полученный FIN или обычный Close по-прежнему дают io.EOF.
func (s *Stream) dieReadErr() error {
	select {
	case <-s.chFinEvent:
		return io.EOF
	default:
	}
	if err := s.sess.recvErr(); err != nil {
		return err
	}
	return io.EOF
}

func (s *Stream) hasBuffered() bool {
	s.bufferLock.Lock()
	defer s.bufferLock.Unlock()
	return len(s.buffers) > 0
}

func (s *Stream) tryReadv2(b []byte) (n int, err error) {
	if len(b) == 0 {
		return 0, nil
	}

	var notifyConsumed uint32
	s.bufferLock.Lock()
	if len(s.buffers) > 0 {
		n = copy(b, s.buffers[0])
		s.buffers[0] = s.buffers[0][n:]
		if len(s.buffers[0]) == 0 {
			s.buffers[0] = nil
			s.buffers = s.buffers[1:]
			defaultAllocator.Put(s.heads[0])
			s.heads = s.heads[1:]
		}
	}

	s.numRead += uint32(n)
	s.incr += uint32(n)

	if s.incr >= s.windowUpdateThreshold() || s.numRead == uint32(n) {
		notifyConsumed = s.numRead
		s.incr = 0
	}
	s.bufferLock.Unlock()

	if n > 0 {
		s.sess.returnTokens(n)
		if notifyConsumed > 0 {
			err := s.sendWindowUpdate(notifyConsumed)
			// Дочитывание буфера после обрыва: UPD мёртвой сессии некому слать, а его
			// ErrClosedPipe замаскировал бы реальную причину, которую вернёт следующий Read.
			if err != nil && s.sess.IsClosed() {
				return n, nil
			}
			return n, err
		}
		return n, nil
	}

	select {
	case <-s.die:
		return 0, s.dieReadErr()
	default:
		return 0, ErrWouldBlock
	}
}

func (s *Stream) WriteTo(w io.Writer) (n int64, err error) {
	if s.sess.config.Version == 2 {
		return s.writeTov2(w)
	}

	for {
		var buf []byte
		s.bufferLock.Lock()
		if len(s.buffers) > 0 {
			buf = s.buffers[0]
			s.buffers = s.buffers[1:]
			s.heads = s.heads[1:]
		}
		s.bufferLock.Unlock()

		if buf != nil {
			nw, ew := w.Write(buf)
			s.sess.returnTokens(len(buf))
			defaultAllocator.Put(buf)
			if nw > 0 {
				n += int64(nw)
			}
			if ew != nil {
				return n, ew
			}
		} else if ew := s.waitRead(); ew != nil {
			return n, ew
		}
	}
}

func (s *Stream) writeTov2(w io.Writer) (n int64, err error) {
	for {
		var notifyConsumed uint32
		var buf []byte
		s.bufferLock.Lock()
		if len(s.buffers) > 0 {
			buf = s.buffers[0]
			s.buffers = s.buffers[1:]
			s.heads = s.heads[1:]
		}
		s.numRead += uint32(len(buf))
		s.incr += uint32(len(buf))
		if s.incr >= s.windowUpdateThreshold() || s.numRead == uint32(len(buf)) {
			notifyConsumed = s.numRead
			s.incr = 0
		}
		s.bufferLock.Unlock()

		if buf != nil {
			nw, ew := w.Write(buf)
			s.sess.returnTokens(len(buf))
			defaultAllocator.Put(buf)
			if nw > 0 {
				n += int64(nw)
			}
			if ew != nil {
				return n, ew
			}
			if notifyConsumed > 0 {
				// Как в tryReadv2: после обрыва дочитываем буфер, причину отдаст waitRead.
				if err := s.sendWindowUpdate(notifyConsumed); err != nil && !s.sess.IsClosed() {
					return n, err
				}
			}
		} else if ew := s.waitRead(); ew != nil {
			return n, ew
		}
	}
}

func (s *Stream) windowUpdateThreshold() uint32 {
	half := uint32(s.sess.config.MaxStreamBuffer / 2)
	if half <= initialPeerWindow {
		return half
	}
	eighth := uint32(s.sess.config.MaxStreamBuffer / 8)
	if eighth > initialPeerWindow {
		return eighth
	}
	return initialPeerWindow
}

func (s *Stream) effectiveStreamWindow(consumed uint32) uint32 {
	base := uint32(s.sess.config.MaxStreamBuffer)
	maxRecv := uint32(s.sess.config.MaxReceiveBuffer)
	if consumed < base || maxRecv <= base*2 {
		return base
	}
	if atomic.LoadInt32(&s.sess.bucket) <= int32(maxRecv/2) {
		return base
	}
	capWin := maxRecv / 2
	target := base * 2
	if consumed >= base*2 {
		target = base * 4
	}
	if target > capWin {
		target = capWin
	}
	// Все стримы делят один bucket (MaxReceiveBuffer). Без доли на стрим четыре
	// застрявших читателя по 4*base выбирают весь бюджет, recvLoop перестаёт читать
	// сокет и встают все стримы сессии, включая realtime и keepalive. Сумма выросших
	// окон ограничена половиной бюджета; меньше base окно не опускаем.
	if n := s.sess.NumStreams(); n > 1 {
		if share := capWin / uint32(n); target > share {
			target = share
		}
	}
	if target < base {
		return base
	}
	return target
}

func (s *Stream) sendWindowUpdate(consumed uint32) error {
	var timer *time.Timer
	var deadline <-chan time.Time
	if d, ok := s.readDeadline.Load().(time.Time); ok && !d.IsZero() {
		timer = time.NewTimer(time.Until(d))
		defer timer.Stop()
		deadline = timer.C
	}

	frame := newFrame(byte(s.sess.config.Version), cmdUPD, s.id)
	var hdr updHeader
	binary.LittleEndian.PutUint32(hdr[:], consumed)
	binary.LittleEndian.PutUint32(hdr[4:], s.effectiveStreamWindow(consumed))
	frame.data = hdr[:]
	_, err := s.sess.writeFrameInternal(frame, deadline, CLSCTRL)
	return err
}

func (s *Stream) waitRead() error {
	var timer *time.Timer
	var deadline <-chan time.Time
	if d, ok := s.readDeadline.Load().(time.Time); ok && !d.IsZero() {
		timer = time.NewTimer(time.Until(d))
		defer timer.Stop()
		deadline = timer.C
	}

	select {
	case <-s.chReadEvent:
		return nil
	case <-s.chFinEvent:
		s.bufferLock.Lock()
		defer s.bufferLock.Unlock()
		if len(s.buffers) > 0 {
			return nil
		}
		return io.EOF
	case <-s.sess.chSocketReadError:
		return s.recvErrUnlessBuffered()
	case <-s.sess.chProtoError:
		return s.recvErrUnlessBuffered()
	case <-deadline:
		return ErrTimeout
	case <-s.die:
		// Данные, принятые до обрыва, должны дочитываться: select мог выбрать die
		// раньше chReadEvent, тогда tryRead отдаст буфер, а затем причину закрытия.
		if s.hasBuffered() {
			return nil
		}
		if err := s.sess.recvErr(); err != nil {
			return err
		}
		return io.ErrClosedPipe
	}
}

func (s *Stream) recvErrUnlessBuffered() error {
	if s.hasBuffered() {
		return nil
	}
	return s.sess.recvErr()
}

// writeDeadlineChan возвращает канал, закрываемый в момент write-дедлайна (nil без
// дедлайна). Закрытый канал «помнит» истёкший дедлайн для всех кадров одного Write,
// поэтому после кадра, засчитанного как ушедший, следующий кадр сразу получит ErrTimeout.
func (s *Stream) writeDeadlineChan() (<-chan struct{}, func()) {
	d, ok := s.writeDeadline.Load().(time.Time)
	if !ok || d.IsZero() {
		return nil, func() {}
	}
	ch := make(chan struct{})
	timer := time.AfterFunc(time.Until(d), func() { close(ch) })
	return ch, func() { timer.Stop() }
}

func (s *Stream) Write(b []byte) (n int, err error) {
	if s.sess.config.Version == 2 {
		return s.writeV2(b)
	}

	deadline, stop := s.writeDeadlineChan()
	defer stop()

	select {
	case <-s.chFinEvent:
		return 0, io.EOF
	case <-s.die:
		return 0, io.ErrClosedPipe
	default:
	}

	if len(b) > 0 {
		if pad := s.padLen(len(b)); pad > 0 {
			frames := s.padGroup(b, pad)
			sent, err := s.sess.writeGroup(frames, deadline)
			s.numWritten += uint32((len(b) + s.frameSize - 1) / s.frameSize)
			return sent, err
		}
	}

	sent := 0
	frame := newFrame(byte(s.sess.config.Version), cmdPSH, s.id)
	class := CLSDATA
	if len(b) <= realtimeMaxPayload {
		class = CLSREALTIME
	}
	bts := b
	for len(bts) > 0 {
		sz := len(bts)
		if sz > s.frameSize {
			sz = s.frameSize
		}
		frame.data = bts[:sz]
		bts = bts[sz:]
		n, err := s.sess.writeData(frame, deadline, class)
		s.numWritten++
		sent += n
		if err != nil {
			return sent, err
		}
	}

	return sent, nil
}

func (s *Stream) writeV2(b []byte) (n int, err error) {
	if len(b) == 0 {
		return 0, nil
	}

	select {
	case <-s.chFinEvent:
		return 0, io.EOF
	case <-s.die:
		return 0, io.ErrClosedPipe
	default:
	}

	deadline, stop := s.writeDeadlineChan()
	defer stop()

	sent := 0
	frame := newFrame(byte(s.sess.config.Version), cmdPSH, s.id)
	pad := s.padLen(len(b))

	for {
		var bts []byte
		inflight := int32(atomic.LoadUint32(&s.numWritten) - atomic.LoadUint32(&s.peerConsumed))
		// Уже отправленные байты ушли пиру: вызывающий должен знать точный счёт,
		// иначе повтор записи их продублирует.
		if inflight < 0 {
			return sent, ErrConsumed
		}

		win := int32(atomic.LoadUint32(&s.peerWindow)) - inflight

		if win > 0 {
			if win > int32(len(b)) {
				bts = b
				b = nil
			} else {
				bts = b[:win]
				b = b[win:]
			}

			if pad > 0 {
				n, err := s.sess.writeGroup(s.padGroup(bts, pad), deadline)
				// Окно пира расходуют только реально ушедшие байты: отменённые по
				// дедлайну иначе навсегда съедали бы окно, и повторные таймауты душили стрим.
				atomic.AddUint32(&s.numWritten, uint32(n))
				sent += n
				pad = 0
				if err != nil {
					return sent, err
				}
				bts = nil
			}

			class := CLSDATA
			if len(bts) <= realtimeMaxPayload && inflight <= realtimeMaxInflight {
				class = CLSREALTIME
			}
			for len(bts) > 0 {
				sz := len(bts)
				if sz > s.frameSize {
					sz = s.frameSize
				}
				frame.data = bts[:sz]
				bts = bts[sz:]

				n, err := s.sess.writeData(frame, deadline, class)
				atomic.AddUint32(&s.numWritten, uint32(n))
				sent += n
				if err != nil {
					return sent, err
				}
			}
		}

		if len(b) > 0 {
			select {
			case <-s.chFinEvent:
				return sent, io.EOF
			case <-s.die:
				if err := s.sess.recvErr(); err != nil {
					return sent, err
				}
				return sent, io.ErrClosedPipe
			case <-deadline:
				return sent, ErrTimeout
			case <-s.sess.chSocketWriteError:
				return sent, s.sess.socketWriteError.Load().(error)
			// Окно расширяют только UPD из recvLoop; если он остановился, ждать нечего.
			case <-s.sess.chSocketReadError:
				return sent, s.sess.socketReadError.Load().(error)
			case <-s.sess.chProtoError:
				return sent, s.sess.protoError.Load().(error)
			case <-s.chUpdate:
				continue
			}
		} else {
			return sent, nil
		}
	}
}

func (s *Stream) Close() error {
	var once bool
	var err error
	s.dieOnce.Do(func() {
		close(s.die)
		once = true
	})

	if once {
		timer := time.NewTimer(openCloseTimeout)
		defer timer.Stop()
		_, err = s.sess.writeFrameInternal(newFrame(byte(s.sess.config.Version), cmdFIN, s.id), timer.C, CLSDATA)
		s.sess.streamClosed(s.id)
		return err
	}
	return io.ErrClosedPipe
}

func (s *Stream) GetDieCh() <-chan struct{} {
	return s.die
}

func (s *Stream) SetReadDeadline(t time.Time) error {
	s.readDeadline.Store(t)
	s.notifyReadEvent()
	return nil
}

func (s *Stream) SetWriteDeadline(t time.Time) error {
	s.writeDeadline.Store(t)
	return nil
}

func (s *Stream) SetDeadline(t time.Time) error {
	if err := s.SetReadDeadline(t); err != nil {
		return err
	}
	if err := s.SetWriteDeadline(t); err != nil {
		return err
	}
	return nil
}

func (s *Stream) sessionClose() { s.dieOnce.Do(func() { close(s.die) }) }

func (s *Stream) LocalAddr() net.Addr {
	if ts, ok := s.sess.conn.(interface{ LocalAddr() net.Addr }); ok {
		return ts.LocalAddr()
	}
	return nil
}

func (s *Stream) RemoteAddr() net.Addr {
	if ts, ok := s.sess.conn.(interface{ RemoteAddr() net.Addr }); ok {
		return ts.RemoteAddr()
	}
	return nil
}

func (s *Stream) pushBytes(buf []byte) (written int, err error) {
	s.bufferLock.Lock()
	s.buffers = append(s.buffers, buf)
	s.heads = append(s.heads, buf)
	s.bufferLock.Unlock()
	return
}

func (s *Stream) recycleTokens() (n int) {
	s.bufferLock.Lock()
	for k := range s.buffers {
		n += len(s.buffers[k])
		defaultAllocator.Put(s.heads[k])
	}
	s.buffers = nil
	s.heads = nil
	s.bufferLock.Unlock()
	return
}

func (s *Stream) notifyReadEvent() {
	select {
	case s.chReadEvent <- struct{}{}:
	default:
	}
}

func (s *Stream) update(consumed uint32, window uint32) {
	atomic.StoreUint32(&s.peerConsumed, consumed)
	atomic.StoreUint32(&s.peerWindow, window)
	select {
	case s.chUpdate <- struct{}{}:
	default:
	}
}

func (s *Stream) fin() {
	s.finEventOnce.Do(func() {
		close(s.chFinEvent)
	})
}
