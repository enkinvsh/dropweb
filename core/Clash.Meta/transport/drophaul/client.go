package drophaul

import (
	"context"
	"encoding/binary"
	"errors"
	"io"
	"math"
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/transport/drophaul/smux"
)

const (
	// SGChan совпадает с байтом управляющего сигнала SG_Chan в drophaul.
	SGChan byte = 1

	defaultMaxSessions        = 2
	defaultStreamsPerSession  = 32
	defaultIdleTimeout        = 90 * time.Second
	defaultFallbackTTL        = 10 * time.Minute
	happyEyeballsWays         = 3
	happyEyeballsStaggerDelay = 250 * time.Millisecond

	minLossSegsOut       = 25
	lossRetransRatio     = 0.05
	lossConsecutiveTicks = 3
)

// ErrFallbackToReality возвращается, когда нода ещё не поддерживает drophaul-ingress
// (например, ответила обычным HTTP от selfsteal-nginx или отклонила TLS-сертификат),
// чтобы Vless мгновенно откатился на стандартный VLESS + Reality.
var ErrFallbackToReality = errors.New("drophaul ingress not active on node, fallback to reality")

type Options struct {
	Addr         string
	Token        string
	MaxSessions  int
	IdleTimeout  time.Duration
	FallbackTTL  time.Duration
	DialTCP      func(ctx context.Context) (net.Conn, error)
	HandshakeTLS func(ctx context.Context, rawConn net.Conn) (net.Conn, error)
}

type poolSession struct {
	session          *smux.Session
	rawConn          net.Conn
	createdAt        time.Time
	lastUsedNano     atomic.Int64
	draining         atomic.Bool
	prevSegsOut      uint32
	prevTotalRetrans uint32
	hasPrevCounters  bool
	lossStreak       int
}

type inflightSessionDial struct {
	done chan struct{}
	ps   *poolSession
	err  error
}

var (
	activePoolsMu sync.Mutex
	activePools   = make(map[*Pool]struct{})
)

// ResetAllPools сбрасывает открытые smux-сессии во всех активных пулах
// (вызывается при смене сети Wi-Fi <-> LTE и сбросе соединений ядра).
func ResetAllPools() {
	activePoolsMu.Lock()
	pools := make([]*Pool, 0, len(activePools))
	for p := range activePools {
		pools = append(pools, p)
	}
	activePoolsMu.Unlock()
	for _, p := range pools {
		p.Reset()
	}
}

type Pool struct {
	opts           Options
	smuxCfg        *smux.Config
	mu             sync.Mutex
	sessions       []*poolSession
	dialing        int
	inflightDial   *inflightSessionDial
	fallbackUntil  atomic.Int64
	closed         atomic.Bool
	stopWatcher    chan struct{}
	watcherStarted atomic.Bool
}

func NewPool(opts Options) *Pool {
	if opts.MaxSessions <= 0 {
		opts.MaxSessions = defaultMaxSessions
	}
	if opts.IdleTimeout <= 0 {
		opts.IdleTimeout = defaultIdleTimeout
	}
	if opts.FallbackTTL <= 0 {
		opts.FallbackTTL = defaultFallbackTTL
	}
	smuxCfg := smux.DefaultConfig()
	smuxCfg.Version = 2
	smuxCfg.KeepAliveInterval = 30 * time.Second
	smuxCfg.KeepAliveTimeout = 90 * time.Second
	smuxCfg.MaxFrameSize = 32768
	smuxCfg.MaxReceiveBuffer = 4194304
	smuxCfg.MaxStreamBuffer = 262144
	smuxCfg.Padding = true

	p := &Pool{
		opts:        opts,
		smuxCfg:     smuxCfg,
		stopWatcher: make(chan struct{}),
	}
	activePoolsMu.Lock()
	activePools[p] = struct{}{}
	activePoolsMu.Unlock()
	return p
}

// ShouldFallback возвращает true, если для этой ноды временно зафиксирован откат
// на стандартный VLESS + Reality.
func (p *Pool) ShouldFallback() bool {
	until := p.fallbackUntil.Load()
	return until > 0 && time.Now().UnixNano() < until
}

func (p *Pool) markFallback() {
	p.fallbackUntil.Store(time.Now().Add(p.opts.FallbackTTL).UnixNano())
	log.Infoln("[drophaul] %s ingress not active, falling back to Reality for %v", p.opts.Addr, p.opts.FallbackTTL)
}

func (p *Pool) ensureWatcher() {
	if p.watcherStarted.CompareAndSwap(false, true) {
		go p.watchLoop()
	}
}

func (p *Pool) DialStream(ctx context.Context) (net.Conn, error) {
	if p.closed.Load() {
		return nil, net.ErrClosed
	}
	if p.ShouldFallback() {
		return nil, ErrFallbackToReality
	}
	p.ensureWatcher()

	if ps := p.pickBestSession(); ps != nil {
		st, err := ps.session.OpenStream()
		if err == nil {
			ps.lastUsedNano.Store(time.Now().UnixNano())
			// если текущие сессии нагружены и есть место в пуле — фоном поднимем вторую сессию
			p.maybeWarmSecondSession()
			return st, nil
		}
		ps.draining.Store(true)
	}

	ps, err := p.dialOrReuseSession(ctx)
	if err != nil {
		return nil, err
	}
	st, err := ps.session.OpenStream()
	if err != nil {
		ps.draining.Store(true)
		_ = ps.session.Close()
		return nil, err
	}
	ps.lastUsedNano.Store(time.Now().UnixNano())
	return st, nil
}

func (p *Pool) pickBestSession() *poolSession {
	p.mu.Lock()
	defer p.mu.Unlock()

	var best *poolSession
	bestInflight := int64(math.MaxInt64)
	bestStreams := int(math.MaxInt32)

	alive := p.sessions[:0]
	for _, ps := range p.sessions {
		if ps.session.IsClosed() {
			continue
		}
		alive = append(alive, ps)
		if ps.draining.Load() {
			continue
		}
		inf := ps.session.TotalInflight()
		numSt := ps.session.NumStreams()
		if best == nil || inf < bestInflight || (inf == bestInflight && numSt < bestStreams) {
			best = ps
			bestInflight = inf
			bestStreams = numSt
		}
	}
	p.sessions = alive
	return best
}

func (p *Pool) maybeWarmSecondSession() {
	p.mu.Lock()
	active := 0
	totalStreams := 0
	for _, ps := range p.sessions {
		if !ps.session.IsClosed() && !ps.draining.Load() {
			active++
			totalStreams += ps.session.NumStreams()
		}
	}
	need := active < p.opts.MaxSessions && p.dialing == 0 && totalStreams >= active*defaultStreamsPerSession
	if need {
		p.dialing++
	}
	p.mu.Unlock()

	if !need {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()
		_, _ = p.dialNewSessionWithLockAdjusted(ctx, true)
	}()
}

func (p *Pool) dialOrReuseSession(ctx context.Context) (*poolSession, error) {
	if p.ShouldFallback() {
		return nil, ErrFallbackToReality
	}
	if ps := p.pickBestSession(); ps != nil {
		return ps, nil
	}

	p.mu.Lock()
	if p.ShouldFallback() {
		p.mu.Unlock()
		return nil, ErrFallbackToReality
	}
	d := p.inflightDial
	if d == nil {
		d = &inflightSessionDial{done: make(chan struct{})}
		p.inflightDial = d
		go func(call *inflightSessionDial) {
			dialCtx, cancelDial := context.WithTimeout(context.Background(), 8*time.Second)
			defer cancelDial()
			ps, err := p.dialNewSession(dialCtx)
			call.ps = ps
			call.err = err
			p.mu.Lock()
			if p.inflightDial == call {
				p.inflightDial = nil
			}
			p.mu.Unlock()
			close(call.done)
		}(d)
	}
	p.mu.Unlock()

	select {
	case <-d.done:
		return d.ps, d.err
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func (p *Pool) dialNewSession(ctx context.Context) (*poolSession, error) {
	p.mu.Lock()
	p.dialing++
	p.mu.Unlock()
	return p.dialNewSessionWithLockAdjusted(ctx, false)
}

func (p *Pool) dialNewSessionWithLockAdjusted(ctx context.Context, background bool) (*poolSession, error) {
	defer func() {
		p.mu.Lock()
		p.dialing--
		p.mu.Unlock()
	}()

	rawConn, tlsConn, err := p.dialAndAuthenticate(ctx)
	if err != nil {
		// фоновый дозвон второй сессии не имеет права отправлять пул в откат:
		// основная сессия может быть жива, а единичный сбой TLS/ack на «прогреве»
		// (сеть мигнула, нода перегружена) иначе отключал drophaul на 10 минут.
		if errors.Is(err, ErrFallbackToReality) && !background {
			p.markFallback()
		}
		return nil, err
	}

	if tcp := unwrapTCPConn(rawConn); tcp != nil {
		_ = tcp.SetNoDelay(true)
	}

	sess, err := smux.Client(tlsConn, p.smuxCfg)
	if err != nil {
		_ = tlsConn.Close()
		return nil, err
	}

	ps := &poolSession{
		session:   sess,
		rawConn:   rawConn,
		createdAt: time.Now(),
	}
	ps.lastUsedNano.Store(time.Now().UnixNano())

	p.mu.Lock()
	if p.closed.Load() {
		p.mu.Unlock()
		_ = sess.Close()
		return nil, net.ErrClosed
	}
	p.sessions = append(p.sessions, ps)
	// длину читаем под локом: после Unlock параллельный picker/cleanup меняет слайс.
	active := len(p.sessions)
	p.mu.Unlock()
	log.Infoln("[drophaul] session established to %s (active=%d)", p.opts.Addr, active)
	return ps, nil
}

// dialAndAuthenticate запускает 5-tuple Happy Eyeballs для TCP-соединения,
// завершает TLS 1.3 и проверяет префикс/токен drophaul.
func (p *Pool) dialAndAuthenticate(ctx context.Context) (net.Conn, net.Conn, error) {
	rawConn, err := p.dialHappyEyeballs(ctx)
	if err != nil {
		return nil, nil, err
	}

	tlsConn, err := p.opts.HandshakeTLS(ctx, rawConn)
	if err != nil {
		_ = rawConn.Close()
		// если сертификат не подошёл (например, на ноде чужой SNI без нашего LE-серта) —
		// откатываемся на стандартный Reality.
		return nil, nil, ErrFallbackToReality
	}

	// отправляем [2B length][1B SGChan][token]
	tokenBytes := []byte(p.opts.Token)
	buf := make([]byte, 3+len(tokenBytes))
	binary.BigEndian.PutUint16(buf[:2], uint16(len(tokenBytes)))
	buf[2] = SGChan
	copy(buf[3:], tokenBytes)

	_ = tlsConn.SetDeadline(time.Now().Add(4 * time.Second))
	if _, err := tlsConn.Write(buf); err != nil {
		_ = tlsConn.Close()
		return nil, nil, err
	}

	var ack [1]byte
	if _, err := io.ReadFull(tlsConn, ack[:]); err != nil {
		_ = tlsConn.Close()
		return nil, nil, ErrFallbackToReality
	}
	_ = tlsConn.SetDeadline(time.Time{})

	if ack[0] != SGChan {
		_ = tlsConn.Close()
		return nil, nil, ErrFallbackToReality
	}
	return rawConn, tlsConn, nil
}

func (p *Pool) dialHappyEyeballs(ctx context.Context) (net.Conn, error) {
	raceCtx, cancelRace := context.WithCancel(ctx)
	defer cancelRace()

	type res struct {
		conn net.Conn
		err  error
	}
	ch := make(chan res, happyEyeballsWays)
	launched := 0

	// каждая горутина обязана отправить в ch РОВНО один результат (ёмкость канала
	// = максимум запусков, отправка не блокируется): drain и цикл ниже считают
	// ответы по числу запусков. Отправка через select с raceCtx.Done() ломает этот
	// инвариант — после отмены гонки результат теряется, сборщик ждёт вечно.
	launchOne := func() {
		launched++
		go func() {
			c, err := p.opts.DialTCP(raceCtx)
			if err != nil {
				ch <- res{err: err}
				return
			}
			ch <- res{conn: c}
		}()
	}

	// drain дочищает результаты проигравших/отменённых дозвонов и закрывает их
	// соединения, чтобы дескрипторы не утекали.
	drain := func(rem int) {
		if rem <= 0 {
			return
		}
		go func() {
			for i := 0; i < rem; i++ {
				if extra := <-ch; extra.conn != nil {
					_ = extra.conn.Close()
				}
			}
		}()
	}

	launchOne()
	stagger := time.NewTimer(happyEyeballsStaggerDelay)
	defer stagger.Stop()

	var firstErr error
	failures := 0
	for failures < launched {
		select {
		case r := <-ch:
			if r.err == nil && r.conn != nil {
				cancelRace()
				drain(launched - failures - 1)
				return r.conn, nil
			}
			failures++
			if firstErr == nil {
				firstErr = r.err
			}
			if launched < happyEyeballsWays && raceCtx.Err() == nil {
				if !stagger.Stop() {
					select {
					case <-stagger.C:
					default:
					}
				}
				launchOne()
				stagger.Reset(happyEyeballsStaggerDelay)
			}
		case <-stagger.C:
			if launched < happyEyeballsWays && raceCtx.Err() == nil {
				launchOne()
				if launched < happyEyeballsWays {
					stagger.Reset(happyEyeballsStaggerDelay)
				}
			}
		case <-ctx.Done():
			cancelRace()
			drain(launched - failures)
			return nil, ctx.Err()
		}
	}
	if firstErr != nil {
		return nil, firstErr
	}
	return nil, errors.New("drophaul dial failed")
}

func (p *Pool) watchLoop() {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-p.stopWatcher:
			return
		case <-ticker.C:
			if p.checkSessions() == 0 {
				p.watcherStarted.Store(false)
				p.mu.Lock()
				hasAny := len(p.sessions) > 0
				p.mu.Unlock()
				if hasAny && p.watcherStarted.CompareAndSwap(false, true) {
					continue
				}
				return
			}
		}
	}
}

func (p *Pool) checkSessions() int {
	now := time.Now()
	p.mu.Lock()
	alive := p.sessions[:0]
	for _, ps := range p.sessions {
		if ps.session.IsClosed() {
			continue
		}
		// закрываем простаивающие сессии без открытых стримов
		if ps.session.NumStreams() == 0 {
			idleFor := now.Sub(time.Unix(0, ps.lastUsedNano.Load()))
			if idleFor >= p.opts.IdleTimeout || ps.draining.Load() {
				_ = ps.session.Close()
				continue
			}
		}
		// проверяем ядерную статистику TCP_INFO (Linux/Android) на потери и RTO-зависания
		if st, ok := connTCPStats(ps.rawConn); ok && st.hasCounters {
			if st.unacked > 0 && st.retransmits >= 2 {
				ps.draining.Store(true)
				if ps.session.NumStreams() == 0 {
					_ = ps.session.Close()
					continue
				}
			}
			if !ps.hasPrevCounters {
				ps.prevSegsOut = st.segsOut
				ps.prevTotalRetrans = st.totalRetrans
				ps.hasPrevCounters = true
			} else if st.segsOut >= ps.prevSegsOut && st.totalRetrans >= ps.prevTotalRetrans {
				dSegs := st.segsOut - ps.prevSegsOut
				dRetrans := st.totalRetrans - ps.prevTotalRetrans
				ps.prevSegsOut = st.segsOut
				ps.prevTotalRetrans = st.totalRetrans
				if dSegs >= minLossSegsOut && float64(dRetrans)/float64(dSegs) >= lossRetransRatio {
					ps.lossStreak++
					if ps.lossStreak >= lossConsecutiveTicks {
						ps.draining.Store(true)
						if ps.session.NumStreams() == 0 {
							_ = ps.session.Close()
							continue
						}
					}
				} else if dSegs >= minLossSegsOut {
					ps.lossStreak = 0
				}
			}
		}
		alive = append(alive, ps)
	}
	p.sessions = alive
	count := len(p.sessions)
	p.mu.Unlock()
	return count
}

// Reset закрывает все текущие smux-сессии пула (например, при смене сетевого интерфейса),
// позволяя следующим соединениям мгновенно поднять сессию на новом маршруте.
func (p *Pool) Reset() {
	p.mu.Lock()
	list := p.sessions
	p.sessions = nil
	p.mu.Unlock()
	for _, ps := range list {
		_ = ps.session.Close()
	}
}

func (p *Pool) Close() error {
	if !p.closed.CompareAndSwap(false, true) {
		return nil
	}
	activePoolsMu.Lock()
	delete(activePools, p)
	activePoolsMu.Unlock()
	close(p.stopWatcher)
	p.Reset()
	return nil
}
