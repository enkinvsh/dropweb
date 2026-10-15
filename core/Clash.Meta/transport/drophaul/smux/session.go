package smux

import (
	"bufio"
	"encoding/binary"
	"errors"
	"io"
	"math/rand"
	"net"
	"runtime"
	"sync"
	"sync/atomic"
	"time"
)

const (
	defaultAcceptBacklog = 1024
	openCloseTimeout     = 30 * time.Second
	maxWriteBatch        = (1 << 16) + headerSize
	recvBufferSize       = 1 << 16
)

type CLASSID int

const (
	CLSCTRL CLASSID = iota
	// CLSREALTIME выделяет интерактивные микро-кадры (VoIP/RTP/STUN/SSH), обгоняющие bulk-данные других стримов.
	CLSREALTIME
	CLSDATA
)

type timeoutError struct{}

func (timeoutError) Error() string   { return "timeout" }
func (timeoutError) Temporary() bool { return true }
func (timeoutError) Timeout() bool   { return true }

var (
	ErrInvalidProtocol           = errors.New("invalid protocol")
	ErrConsumed                  = errors.New("peer consumed more than sent")
	ErrGoAway                    = errors.New("stream id overflows, should start a new connection")
	ErrTimeout         net.Error = &timeoutError{}
	ErrWouldBlock                = errors.New("operation would block on IO")
)

type writeRequest struct {
	class  CLASSID
	frame  Frame
	seq    uint32
	result chan writeResult
	glue   bool
}

type writeResult struct {
	n   int
	err error
}

type Session struct {
	conn             io.ReadWriteCloser
	config           *Config
	nextStreamID     uint32
	nextStreamIDLock sync.Mutex

	bucket       int32
	bucketNotify chan struct{}

	streams    map[uint32]*Stream
	streamLock sync.Mutex

	die     chan struct{}
	dieOnce sync.Once

	socketReadError      atomic.Value
	socketWriteError     atomic.Value
	chSocketReadError    chan struct{}
	chSocketWriteError   chan struct{}
	socketReadErrorOnce  sync.Once
	socketWriteErrorOnce sync.Once

	protoError     atomic.Value
	chProtoError   chan struct{}
	protoErrorOnce sync.Once

	chAccepts chan *Stream

	dataReady    int32
	pingInFlight int32
	goAway       int32
	deadline     atomic.Value
	requestID    uint32

	writeMu     sync.Mutex
	writeQ      []writeRequest
	writeNotify chan struct{}
}

func newSession(config *Config, conn io.ReadWriteCloser, client bool) *Session {
	s := new(Session)
	s.die = make(chan struct{})
	s.conn = conn
	s.config = config
	s.streams = make(map[uint32]*Stream)
	s.chAccepts = make(chan *Stream, defaultAcceptBacklog)
	s.bucket = int32(config.MaxReceiveBuffer)
	s.bucketNotify = make(chan struct{}, 1)
	s.writeNotify = make(chan struct{}, 1)
	s.chSocketReadError = make(chan struct{})
	s.chSocketWriteError = make(chan struct{})
	s.chProtoError = make(chan struct{})

	if client {
		s.nextStreamID = 1
	} else {
		s.nextStreamID = 0
	}

	go s.recvLoop()
	go s.sendLoop()
	if !config.KeepAliveDisabled {
		go s.keepalive()
	}
	return s
}

func (s *Session) OpenStream() (*Stream, error) {
	if s.IsClosed() {
		return nil, io.ErrClosedPipe
	}

	s.nextStreamIDLock.Lock()
	if s.goAway > 0 {
		s.nextStreamIDLock.Unlock()
		return nil, ErrGoAway
	}

	s.nextStreamID += 2
	sid := s.nextStreamID
	if sid == sid%2 {
		s.goAway = 1
		s.nextStreamIDLock.Unlock()
		return nil, ErrGoAway
	}
	s.nextStreamIDLock.Unlock()

	stream := newStream(sid, s.config.MaxFrameSize, s)

	if _, err := s.writeFrame(newFrame(byte(s.config.Version), cmdSYN, sid)); err != nil {
		return nil, err
	}

	s.streamLock.Lock()
	defer s.streamLock.Unlock()

	select {
	case <-s.chSocketReadError:
		return nil, s.socketReadError.Load().(error)
	case <-s.chSocketWriteError:
		return nil, s.socketWriteError.Load().(error)
	case <-s.die:
		return nil, io.ErrClosedPipe
	default:
		s.streams[sid] = stream
		return stream, nil
	}
}

func (s *Session) Open() (io.ReadWriteCloser, error) {
	return s.OpenStream()
}

func (s *Session) AcceptStream() (*Stream, error) {
	var deadline <-chan time.Time
	if d, ok := s.deadline.Load().(time.Time); ok && !d.IsZero() {
		timer := time.NewTimer(time.Until(d))
		defer timer.Stop()
		deadline = timer.C
	}

	select {
	case stream := <-s.chAccepts:
		return stream, nil
	case <-deadline:
		return nil, ErrTimeout
	case <-s.chSocketReadError:
		return nil, s.socketReadError.Load().(error)
	case <-s.chProtoError:
		return nil, s.protoError.Load().(error)
	case <-s.die:
		return nil, io.ErrClosedPipe
	}
}

func (s *Session) Accept() (io.ReadWriteCloser, error) {
	return s.AcceptStream()
}

func (s *Session) Close() error {
	var once bool
	s.dieOnce.Do(func() {
		close(s.die)
		once = true
	})

	if once {
		s.streamLock.Lock()
		for k := range s.streams {
			s.streams[k].sessionClose()
		}
		s.streamLock.Unlock()
		return s.conn.Close()
	}
	return io.ErrClosedPipe
}

func (s *Session) CloseChan() <-chan struct{} {
	return s.die
}

func (s *Session) notifyBucket() {
	select {
	case s.bucketNotify <- struct{}{}:
	default:
	}
}

func (s *Session) notifyReadError(err error) {
	s.socketReadErrorOnce.Do(func() {
		s.socketReadError.Store(err)
		close(s.chSocketReadError)
	})
}

func (s *Session) notifyWriteError(err error) {
	s.socketWriteErrorOnce.Do(func() {
		s.socketWriteError.Store(err)
		close(s.chSocketWriteError)
	})
}

func (s *Session) notifyProtoError(err error) {
	s.protoErrorOnce.Do(func() {
		s.protoError.Store(err)
		close(s.chProtoError)
	})
}

func (s *Session) IsClosed() bool {
	select {
	case <-s.die:
		return true
	default:
		return false
	}
}

func (s *Session) NumStreams() int {
	if s.IsClosed() {
		return 0
	}
	s.streamLock.Lock()
	defer s.streamLock.Unlock()
	return len(s.streams)
}

// TotalInflight возвращает суммарное число отправленных, но ещё не подтверждённых
// пиром байт по всем открытым стримам сессии (для выбора наименее загруженной сессии).
func (s *Session) TotalInflight() int64 {
	if s.IsClosed() {
		return 0
	}
	s.streamLock.Lock()
	defer s.streamLock.Unlock()
	var total int64
	for _, st := range s.streams {
		inf := int32(atomic.LoadUint32(&st.numWritten) - atomic.LoadUint32(&st.peerConsumed))
		if inf > 0 {
			total += int64(inf)
		}
	}
	return total
}

func (s *Session) SetDeadline(t time.Time) error {
	s.deadline.Store(t)
	return nil
}

func (s *Session) LocalAddr() net.Addr {
	if ts, ok := s.conn.(interface{ LocalAddr() net.Addr }); ok {
		return ts.LocalAddr()
	}
	return nil
}

func (s *Session) RemoteAddr() net.Addr {
	if ts, ok := s.conn.(interface{ RemoteAddr() net.Addr }); ok {
		return ts.RemoteAddr()
	}
	return nil
}

func (s *Session) streamClosed(sid uint32) {
	s.streamLock.Lock()
	if stream, ok := s.streams[sid]; ok {
		if n := stream.recycleTokens(); n > 0 {
			if atomic.AddInt32(&s.bucket, int32(n)) > 0 {
				s.notifyBucket()
			}
		}
	}
	delete(s.streams, sid)
	s.streamLock.Unlock()
}

func (s *Session) returnTokens(n int) {
	if atomic.AddInt32(&s.bucket, int32(n)) > 0 {
		s.notifyBucket()
	}
}

func (s *Session) recvLoop() {
	var hdr rawHeader
	var updHdr updHeader
	conn := bufio.NewReaderSize(s.conn, recvBufferSize)

	for {
		for atomic.LoadInt32(&s.bucket) <= 0 && !s.IsClosed() {
			select {
			case <-s.bucketNotify:
			case <-s.die:
				return
			}
		}

		if _, err := io.ReadFull(conn, hdr[:]); err == nil {
			atomic.StoreInt32(&s.dataReady, 1)
			if hdr.Version() != byte(s.config.Version) {
				s.notifyProtoError(ErrInvalidProtocol)
				return
			}
			sid := hdr.StreamID()
			cmd := hdr.Cmd()
			if bad := ((cmd == cmdSYN || cmd == cmdFIN || cmd == cmdNOP) && hdr.Length() != 0) ||
				(cmd == cmdUPD && (s.config.Version != 2 || hdr.Length() != szCmdUPD)); bad {
				s.notifyProtoError(ErrInvalidProtocol)
				return
			}
			switch hdr.Cmd() {
			case cmdNOP:
			case cmdSYN:
				s.streamLock.Lock()
				if _, ok := s.streams[sid]; !ok {
					stream := newStream(sid, s.config.MaxFrameSize, s)
					s.streams[sid] = stream
					select {
					case s.chAccepts <- stream:
					case <-s.die:
					}
				}
				s.streamLock.Unlock()
			case cmdFIN:
				s.streamLock.Lock()
				if stream, ok := s.streams[sid]; ok {
					stream.fin()
					stream.notifyReadEvent()
				}
				s.streamLock.Unlock()
			case cmdPSH:
				if hdr.Length() > 0 {
					newbuf := defaultAllocator.Get(int(hdr.Length()))
					if written, err := io.ReadFull(conn, newbuf); err == nil {
						s.streamLock.Lock()
						if stream, ok := s.streams[sid]; ok {
							stream.pushBytes(newbuf)
							atomic.AddInt32(&s.bucket, -int32(written))
							stream.notifyReadEvent()
						}
						s.streamLock.Unlock()
					} else {
						s.notifyReadError(err)
						return
					}
				}
			case cmdUPD:
				if _, err := io.ReadFull(conn, updHdr[:]); err == nil {
					s.streamLock.Lock()
					if stream, ok := s.streams[sid]; ok {
						stream.update(updHdr.Consumed(), updHdr.Window())
					}
					s.streamLock.Unlock()
				} else {
					s.notifyReadError(err)
					return
				}
			case cmdPAD:
				if _, err := conn.Discard(int(hdr.Length())); err != nil {
					s.notifyReadError(err)
					return
				}
			default:
				s.notifyProtoError(ErrInvalidProtocol)
				return
			}
		} else {
			s.notifyReadError(err)
			return
		}
	}
}

func keepaliveDelay(interval time.Duration) time.Duration {
	if interval <= 1 {
		return interval
	}
	return interval/2 + time.Duration(rand.Int63n(int64(interval)))
}

func (s *Session) keepaliveFrame() Frame {
	ver := byte(s.config.Version)
	if !s.config.Padding {
		return newFrame(ver, cmdNOP, 0)
	}
	f := newFrame(ver, cmdPAD, 0)
	n := 16 + rand.Intn(225)
	f.data = padBytes[:n]
	return f
}

func (s *Session) keepalive() {
	timerPing := time.NewTimer(keepaliveDelay(s.config.KeepAliveInterval))
	tickerTimeout := time.NewTicker(s.config.KeepAliveTimeout)
	defer timerPing.Stop()
	defer tickerTimeout.Stop()

	for {
		select {
		case <-timerPing.C:
			delay := keepaliveDelay(s.config.KeepAliveInterval)
			timerPing.Reset(delay)
			if atomic.CompareAndSwapInt32(&s.pingInFlight, 0, 1) {
				frame := s.keepaliveFrame()
				go func() {
					deadline := time.NewTimer(delay)
					s.writeFrameInternal(frame, deadline.C, CLSCTRL)
					deadline.Stop()
					atomic.StoreInt32(&s.pingInFlight, 0)
				}()
			}
			s.notifyBucket()
		case <-tickerTimeout.C:
			if !atomic.CompareAndSwapInt32(&s.dataReady, 1, 0) {
				if atomic.LoadInt32(&s.bucket) > 0 {
					s.Close()
					return
				}
			}
		case <-s.die:
			return
		}
	}
}

func (s *Session) sendLoop() {
	buf := make([]byte, maxWriteBatch)
	var batch, spare []writeRequest

	for {
		select {
		case <-s.die:
			return
		case <-s.writeNotify:
		}

		runtime.Gosched()

		for {
			s.writeMu.Lock()
			batch, s.writeQ = s.writeQ, spare[:0]
			s.writeMu.Unlock()
			if len(batch) == 0 {
				spare = batch
				break
			}

			if err := s.writeBatch(buf, batch); err != nil {
				s.notifyWriteError(err)
				return
			}

			for i := range batch {
				batch[i] = writeRequest{}
			}
			spare = batch
		}
	}
}

func (s *Session) writeBatch(buf []byte, batch []writeRequest) error {
	ordered := reorderBatch(batch)

	used := 0
	first := 0
	for i, r := range ordered {
		sz := headerSize + len(r.frame.data)
		need := sz
		if i+1 < len(ordered) && ordered[i+1].glue {
			need += headerSize + len(ordered[i+1].frame.data)
		}
		if used > 0 && used+need > len(buf) {
			if err := s.flush(buf[:used], ordered[first:i]); err != nil {
				failRequests(ordered[i:], err)
				return err
			}
			used, first = 0, i
		}
		buf[used] = r.frame.ver
		buf[used+1] = r.frame.cmd
		binary.LittleEndian.PutUint16(buf[used+2:], uint16(len(r.frame.data)))
		binary.LittleEndian.PutUint32(buf[used+4:], r.frame.sid)
		copy(buf[used+headerSize:], r.frame.data)
		used += sz
	}
	return s.flush(buf[:used], ordered[first:])
}

func (s *Session) flush(p []byte, reqs []writeRequest) error {
	n, err := s.conn.Write(p)
	off := 0
	for _, r := range reqs {
		sz := headerSize + len(r.frame.data)
		written := n - off - headerSize
		if written < 0 {
			written = 0
		} else if written > len(r.frame.data) {
			written = len(r.frame.data)
		}
		off += sz
		r.result <- writeResult{n: written, err: err}
		close(r.result)
	}
	return err
}

func failRequests(reqs []writeRequest, err error) {
	for _, r := range reqs {
		r.result <- writeResult{err: err}
		close(r.result)
	}
}

func hasClass(reqs []writeRequest, class CLASSID) bool {
	for _, r := range reqs {
		if r.class == class {
			return true
		}
	}
	return false
}

// reorderBatch выстраивает очередь записи в порядке CLSCTRL -> CLSREALTIME -> CLSDATA,
// сохраняя строгий порядок кадров внутри каждого отдельного стрима (sid).
func reorderBatch(batch []writeRequest) []writeRequest {
	hasCtrl := hasClass(batch, CLSCTRL)
	hasRT := hasClass(batch, CLSREALTIME)
	hasData := hasClass(batch, CLSDATA)
	if (!hasCtrl && !hasRT) || (!hasRT && !hasData) && (!hasCtrl || !hasData) {
		return batch
	}

	ordered := make([]writeRequest, 0, len(batch))
	if hasCtrl {
		for _, r := range batch {
			if r.class == CLSCTRL {
				ordered = append(ordered, r)
			}
		}
	}
	if !hasRT || !hasData {
		for _, r := range batch {
			if r.class != CLSCTRL {
				ordered = append(ordered, r)
			}
		}
		return ordered
	}

	var bulkRestricted map[uint32]struct{}
	var demoted []int
	for i, r := range batch {
		if r.class == CLSDATA {
			if bulkRestricted == nil {
				bulkRestricted = make(map[uint32]struct{}, 4)
			}
			bulkRestricted[r.frame.sid] = struct{}{}
		} else if r.class == CLSREALTIME {
			if _, blocked := bulkRestricted[r.frame.sid]; !blocked {
				ordered = append(ordered, r)
			} else {
				demoted = append(demoted, i)
			}
		}
	}
	demotedIdx := 0
	for i, r := range batch {
		if r.class == CLSDATA {
			ordered = append(ordered, r)
		} else if demotedIdx < len(demoted) && demoted[demotedIdx] == i {
			ordered = append(ordered, r)
			demotedIdx++
		}
	}
	return ordered
}

func (s *Session) writeFrame(f Frame) (n int, err error) {
	return s.writeFrameInternal(f, time.After(openCloseTimeout), CLSCTRL)
}

func (s *Session) writeFrameInternal(f Frame, deadline <-chan time.Time, class CLASSID) (int, error) {
	select {
	case <-s.die:
		return 0, io.ErrClosedPipe
	case <-s.chSocketWriteError:
		return 0, s.socketWriteError.Load().(error)
	default:
	}

	req := writeRequest{
		class:  class,
		frame:  f,
		seq:    atomic.AddUint32(&s.requestID, 1),
		result: make(chan writeResult, 1),
	}

	s.writeMu.Lock()
	wasEmpty := len(s.writeQ) == 0
	s.writeQ = append(s.writeQ, req)
	s.writeMu.Unlock()
	if wasEmpty {
		select {
		case s.writeNotify <- struct{}{}:
		default:
		}
	}

	select {
	case result := <-req.result:
		return result.n, result.err
	case <-s.die:
		return 0, io.ErrClosedPipe
	case <-s.chSocketWriteError:
		return 0, s.socketWriteError.Load().(error)
	case <-deadline:
		return 0, ErrTimeout
	}
}
