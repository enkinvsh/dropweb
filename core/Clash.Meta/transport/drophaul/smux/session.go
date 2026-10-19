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

// Состояния отменяемого запроса записи. frame.data PSH-кадра указывает в буфер
// вызывающего: после таймаута Write он вправе его переиспользовать, поэтому sendLoop
// может копировать payload только выиграв CAS reqQueued->reqCopying, а ожидающий
// возвращает таймаут только выиграв CAS reqQueued->reqCancelled.
const (
	reqQueued int32 = iota
	reqCopying
	reqCancelled
)

type writeRequest struct {
	class  CLASSID
	frame  Frame
	seq    uint32
	result chan writeResult
	glue   bool
	// state == nil у служебных кадров (SYN/FIN/UPD/NOP/keepalive): они владеют
	// своими буферами и никогда не отменяются.
	state *int32
}

type writeResult struct {
	n   int
	err error
}

type Session struct {
	conn   io.ReadWriteCloser
	config *Config
	// client: сессия создана через Client(); клиент пула никогда не вызывает
	// AcceptStream, поэтому входящий SYN для него — нарушение протокола.
	client           bool
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

	// copyMu держит sendLoop, пока захватывает запросы и копирует их payload в батч,
	// и отпускает до блокирующего conn.Write. Ожидающий, проигравший CAS отмены, ждёт
	// на нём только конца копирования в память, а не сокет.
	copyMu sync.Mutex
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
	s.client = client

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
	case <-s.chProtoError:
		return nil, s.protoError.Load().(error)
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

// recvErr возвращает сохранённую причину остановки recvLoop (ошибка чтения
// сокета или протокола) либо nil. Проверка неблокирующая и в фиксированном
// порядке: после закрытия сессии die закрыт одновременно с этими каналами,
// и случайный выбор select не должен подменять реальную причину на ErrClosedPipe.
func (s *Session) recvErr() error {
	select {
	case <-s.chSocketReadError:
		return s.socketReadError.Load().(error)
	default:
	}
	select {
	case <-s.chProtoError:
		return s.protoError.Load().(error)
	default:
	}
	return nil
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
	// Без recvLoop сессия мертва: UPD не приходят, писатели ждут окно вечно, а пул
	// продолжал бы выдавать её в OpenStream до keepalive-закрытия (до 2*KeepAliveTimeout).
	// Поэтому любой выход закрывает сессию; повторный Close безопасен (dieOnce),
	// его ErrClosedPipe здесь не несёт информации.
	defer func() { _ = s.Close() }()

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
				if s.client {
					s.notifyProtoError(ErrInvalidProtocol)
					return
				}
				s.streamLock.Lock()
				if _, ok := s.streams[sid]; !ok {
					stream := newStream(sid, s.config.MaxFrameSize, s)
					// Под streamLock блокироваться нельзя: при полном бэклоге (никто не
					// вызывает Accept) зависли бы NumStreams/OpenStream/Stream.Close.
					// Лишний SYN отбрасываем, стрим не регистрируем.
					select {
					case s.chAccepts <- stream:
						s.streams[sid] = stream
					default:
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

	// Отменённые запросы выкидываются из ordered сжатием на месте (kept <= i),
	// чтобы flush считал смещения только по реально скопированным кадрам.
	used := 0
	first := 0
	kept := 0
	s.copyMu.Lock()
	for i, r := range ordered {
		sz := headerSize + len(r.frame.data)
		need := sz
		if i+1 < len(ordered) && ordered[i+1].glue {
			need += headerSize + len(ordered[i+1].frame.data)
		}
		if used > 0 && used+need > len(buf) {
			s.copyMu.Unlock()
			if err := s.flush(buf[:used], ordered[first:kept]); err != nil {
				failRequests(ordered[i:], err)
				return err
			}
			used, first = 0, kept
			s.copyMu.Lock()
		}
		// CAS строго после возможного flush и под copyMu: захваченный запрос
		// копируется до отпускания copyMu, иначе ожидающий решил бы, что его
		// payload уже скопирован, и вернул бы буфер вызывающему раньше времени.
		if r.state != nil && !atomic.CompareAndSwapInt32(r.state, reqQueued, reqCopying) {
			continue
		}
		buf[used] = r.frame.ver
		buf[used+1] = r.frame.cmd
		binary.LittleEndian.PutUint16(buf[used+2:], uint16(len(r.frame.data)))
		binary.LittleEndian.PutUint32(buf[used+4:], r.frame.sid)
		copy(buf[used+headerSize:], r.frame.data)
		used += sz
		ordered[kept] = r
		kept++
	}
	s.copyMu.Unlock()
	if used == 0 {
		return nil
	}
	return s.flush(buf[:used], ordered[first:kept])
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
	s.enqueue([]writeRequest{req})

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

func (s *Session) enqueue(reqs []writeRequest) {
	s.writeMu.Lock()
	wasEmpty := len(s.writeQ) == 0
	s.writeQ = append(s.writeQ, reqs...)
	s.writeMu.Unlock()
	if wasEmpty {
		select {
		case s.writeNotify <- struct{}{}:
		default:
		}
	}
}

// writeData пишет PSH-кадр с байтами вызывающего; запрос отменяемый (см. reqQueued).
// deadline — канал, закрываемый в момент дедлайна: он остаётся «сработавшим» для
// всех следующих кадров того же Write, в отличие от однократного time.Timer.C.
func (s *Session) writeData(f Frame, deadline <-chan struct{}, class CLASSID) (int, error) {
	select {
	case <-s.die:
		return 0, io.ErrClosedPipe
	case <-s.chSocketWriteError:
		return 0, s.socketWriteError.Load().(error)
	case <-deadline:
		return 0, ErrTimeout
	default:
	}

	req := writeRequest{
		class:  class,
		frame:  f,
		seq:    atomic.AddUint32(&s.requestID, 1),
		result: make(chan writeResult, 1),
		state:  new(int32),
	}
	reqs := [1]writeRequest{req}
	s.enqueue(reqs[:])

	select {
	case result := <-req.result:
		return result.n, result.err
	case <-s.die:
		return s.abandon(reqs[:], 0, io.ErrClosedPipe)
	case <-s.chSocketWriteError:
		return s.abandon(reqs[:], 0, s.socketWriteError.Load().(error))
	case <-deadline:
		return s.abandon(reqs[:], 0, ErrTimeout)
	}
}

// abandon снимает ещё не отправленный хвост reqs (кадры одного Write в порядке
// очереди) после дедлайна или смерти сессии. Отмена идёт с конца, чтобы PAD,
// приклеенный к PSH, снимался раньше своего PSH, и на проводе никогда не оказалось
// PAD без данных. sendLoop захватывает кадры по порядку, поэтому захваченные образуют
// префикс: на первом проигранном CAS останавливаемся, всё до него уже в батче.
// Захваченный кадр считается записанным (байты уйдут в сокет), но никогда не
// возвращается как (n == len, err != nil): ошибку получит следующий кадр Write.
func (s *Session) abandon(reqs []writeRequest, sent int, cause error) (int, error) {
	claimed := 0
	for j := len(reqs) - 1; j >= 0; j-- {
		if !atomic.CompareAndSwapInt32(reqs[j].state, reqQueued, reqCancelled) {
			claimed = j + 1
			break
		}
	}
	if claimed == 0 {
		return sent, cause
	}
	// Копирование в батч ограничено памятью (<= maxWriteBatch), ждём только его.
	s.copyMu.Lock()
	s.copyMu.Unlock()
	for _, r := range reqs[:claimed] {
		n, err := len(r.frame.data), error(nil)
		select {
		case res := <-r.result:
			n, err = res.n, res.err
		default:
			// Сессия умирает, flush ещё не отчитался — доставка не гарантирована.
			if cause != ErrTimeout {
				n, err = 0, cause
			}
		}
		if r.frame.cmd != cmdPAD {
			sent += n
		}
		if err != nil {
			return sent, err
		}
	}
	// Снятый одиночный PAD данных не несёт: если все PSH захвачены, Write успешен.
	for _, r := range reqs[claimed:] {
		if r.frame.cmd != cmdPAD {
			return sent, cause
		}
	}
	return sent, nil
}
