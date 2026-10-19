package drophaul

import (
	"context"
	"crypto/tls"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"runtime"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/transport/drophaul/smux"
)

// startRegressIngress поднимает минимальный drophaul-ingress: TLS, проверка
// токена, ack и эхо-сервер поверх smux. Возвращает адрес и функцию остановки.
func startRegressIngress(t *testing.T, srvTLS *tls.Config, token string) (string, func()) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go func(raw net.Conn) {
				defer raw.Close()
				tc := tls.Server(raw, srvTLS)
				if err := tc.Handshake(); err != nil {
					return
				}
				var hdr [3]byte
				if _, err := io.ReadFull(tc, hdr[:]); err != nil {
					return
				}
				msgLen := int(binary.BigEndian.Uint16(hdr[:2]))
				if hdr[2] != SGChan || msgLen != len(token) {
					return
				}
				tokBuf := make([]byte, msgLen)
				if _, err := io.ReadFull(tc, tokBuf); err != nil || string(tokBuf) != token {
					return
				}
				if _, err := tc.Write([]byte{SGChan}); err != nil {
					return
				}
				cfg := smux.DefaultConfig()
				cfg.Version = 2
				cfg.Padding = true
				sess, err := smux.Server(tc, cfg)
				if err != nil {
					return
				}
				defer sess.Close()
				for {
					st, err := sess.AcceptStream()
					if err != nil {
						return
					}
					go func(s *smux.Stream) {
						defer s.Close()
						_, _ = io.Copy(s, s)
					}(st)
				}
			}(c)
		}
	}()
	return ln.Addr().String(), func() { _ = ln.Close() }
}

// Фоновый дозвон второй сессии — опциональная оптимизация. Его сбой (таймаут,
// обрыв сети) не должен на 10 минут уводить всю ноду на Reality при живой
// первой сессии.
func TestBackgroundDialFailureDoesNotMarkFallback(t *testing.T) {
	newPool := func() *Pool {
		return NewPool(Options{
			Addr:  "127.0.0.1:1",
			Token: DeriveToken("pubKey1", "short01"),
			DialTCP: func(ctx context.Context) (net.Conn, error) {
				c, peer := net.Pipe()
				_ = peer.Close()
				return c, nil
			},
			HandshakeTLS: func(ctx context.Context, rawConn net.Conn) (net.Conn, error) {
				return nil, errors.New("tls: handshake timeout")
			},
		})
	}

	bg := newPool()
	defer bg.Close()
	bg.mu.Lock()
	bg.dialing++
	bg.mu.Unlock()
	if _, err := bg.dialNewSessionWithLockAdjusted(context.Background(), true); !errors.Is(err, ErrFallbackToReality) {
		t.Fatalf("фоновый дозвон: ожидали ErrFallbackToReality, получили %v", err)
	}
	if bg.ShouldFallback() {
		t.Fatalf("сбой фонового дозвона не должен включать откат на Reality")
	}

	fg := newPool()
	defer fg.Close()
	fg.mu.Lock()
	fg.dialing++
	fg.mu.Unlock()
	if _, err := fg.dialNewSessionWithLockAdjusted(context.Background(), false); !errors.Is(err, ErrFallbackToReality) {
		t.Fatalf("дозвон на переднем плане: ожидали ErrFallbackToReality, получили %v", err)
	}
	if !fg.ShouldFallback() {
		t.Fatalf("сбой дозвона, когда сессии нет, должен включать откат на Reality")
	}
}

// Дозвон-проигравший, успешно завершившийся уже после отмены гонки, раньше
// иногда не писал ничего в канал, и горутина-сборщик ждала бесконечно.
func TestHappyEyeballsLateSuccessDoesNotLeakGoroutine(t *testing.T) {
	before := runtime.NumGoroutine()

	const rounds = 40
	var wg sync.WaitGroup
	for i := 0; i < rounds; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			var calls atomic.Int32
			p := NewPool(Options{
				Addr: "127.0.0.1:1",
				DialTCP: func(ctx context.Context) (net.Conn, error) {
					c, peer := net.Pipe()
					_ = peer.Close()
					if calls.Add(1) == 1 {
						// первый дозвон «успевает» только после победы второго
						<-ctx.Done()
					}
					return c, nil
				},
			})
			defer p.Close()
			conn, err := p.dialHappyEyeballs(context.Background())
			if err != nil {
				t.Errorf("dialHappyEyeballs: %v", err)
				return
			}
			_ = conn.Close()
		}()
	}
	wg.Wait()

	deadline := time.Now().Add(3 * time.Second)
	for runtime.NumGoroutine() > before+2 && time.Now().Before(deadline) {
		time.Sleep(20 * time.Millisecond)
	}
	if got := runtime.NumGoroutine(); got > before+2 {
		t.Fatalf("утечка горутин в Happy Eyeballs: было %d, стало %d", before, got)
	}
}

// Отмена внешнего контекста тоже не должна оставлять сборщик и открытые
// соединения: все запущенные дозвоны обязаны быть дочищены.
func TestHappyEyeballsCancelledContextDrainsAllDials(t *testing.T) {
	before := runtime.NumGoroutine()

	var closed atomic.Int32
	var opened atomic.Int32
	p := NewPool(Options{
		Addr: "127.0.0.1:1",
		DialTCP: func(ctx context.Context) (net.Conn, error) {
			opened.Add(1)
			<-ctx.Done()
			c, peer := net.Pipe()
			_ = peer.Close()
			return &countingConn{Conn: c, onClose: func() { closed.Add(1) }}, nil
		},
	})
	defer p.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()
	if _, err := p.dialHappyEyeballs(ctx); err == nil {
		t.Fatalf("ожидали ошибку по таймауту контекста")
	}

	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if closed.Load() == opened.Load() && runtime.NumGoroutine() <= before+2 {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("дозвоны не дочищены: открыто %d, закрыто %d, горутин %d (было %d)",
		opened.Load(), closed.Load(), runtime.NumGoroutine(), before)
}

type countingConn struct {
	net.Conn
	once    sync.Once
	onClose func()
}

func (c *countingConn) Close() error {
	c.once.Do(c.onClose)
	return c.Conn.Close()
}

// Лог об установленной сессии читал len(p.sessions) без блокировки, а
// pickBestSession в это время перезаписывает слайс. Тест осмыслен под -race.
func TestSessionEstablishedLogDoesNotRaceWithPicker(t *testing.T) {
	srvTLS, cliTLS := makeTLSConfigPair(t)
	token := DeriveToken("pubKey1", "short01")
	addr, stop := startRegressIngress(t, srvTLS, token)
	defer stop()

	p := NewPool(Options{
		Addr:  addr,
		Token: token,
		DialTCP: func(ctx context.Context) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "tcp", addr)
		},
		HandshakeTLS: func(ctx context.Context, rawConn net.Conn) (net.Conn, error) {
			tc := tls.Client(rawConn, cliTLS)
			if err := tc.HandshakeContext(ctx); err != nil {
				return nil, err
			}
			return tc, nil
		},
	})
	defer p.Close()

	stopPick := make(chan struct{})
	pickerDone := make(chan struct{})
	go func() {
		defer close(pickerDone)
		for {
			select {
			case <-stopPick:
				return
			default:
				_ = p.pickBestSession()
			}
		}
	}()

	for i := 0; i < 8; i++ {
		p.mu.Lock()
		p.dialing++
		p.mu.Unlock()
		if _, err := p.dialNewSessionWithLockAdjusted(context.Background(), false); err != nil {
			close(stopPick)
			<-pickerDone
			t.Fatalf("dial #%d: %v", i, err)
		}
	}
	close(stopPick)
	<-pickerDone
}
