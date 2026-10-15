package smux

import (
	crand "crypto/rand"
	"io"
	"math/rand"
	"sync/atomic"
	"time"
)

// В первых padWritesPerStream вызовах Write каждого стрима в тот же батч
// добавляется фрейм cmdPAD, чтобы скрыть размеры записей внутреннего хендшейка.
const (
	padWritesPerStream = 8
	padTarget          = 900
	padSmallJitter     = 500
	padLargeJitter     = 256
	maxPadLen          = padTarget + padSmallJitter
)

var padBytes = func() []byte {
	b := make([]byte, maxPadLen)
	if _, err := crand.Read(b); err != nil {
		panic(err)
	}
	return b
}()

func (s *Stream) padLen(n int) int {
	if !s.sess.config.Padding || atomic.LoadUint32(&s.padWrites) >= padWritesPerStream {
		return 0
	}
	if atomic.AddUint32(&s.padWrites, 1) > padWritesPerStream {
		return 0
	}
	if n < padTarget {
		return padTarget - n + rand.Intn(padSmallJitter)
	}
	return rand.Intn(padLargeJitter)
}

func (s *Stream) padGroup(data []byte, pad int) []Frame {
	ver := byte(s.sess.config.Version)
	frames := make([]Frame, 0, (len(data)+s.frameSize-1)/s.frameSize+1)
	for len(data) > 0 {
		sz := len(data)
		if sz > s.frameSize {
			sz = s.frameSize
		}
		f := newFrame(ver, cmdPSH, s.id)
		f.data = data[:sz]
		data = data[sz:]
		frames = append(frames, f)
	}
	last := 0
	if len(frames) > 0 {
		last = len(frames[len(frames)-1].data)
	}
	if room := maxWriteBatch - 2*headerSize - last; pad > room {
		pad = room
	}
	if pad > 0 {
		f := newFrame(ver, cmdPAD, s.id)
		f.data = padBytes[:pad]
		frames = append(frames, f)
	}
	return frames
}

func (s *Session) writeGroup(frames []Frame, deadline <-chan time.Time) (int, error) {
	select {
	case <-s.die:
		return 0, io.ErrClosedPipe
	case <-s.chSocketWriteError:
		return 0, s.socketWriteError.Load().(error)
	default:
	}

	reqs := make([]writeRequest, len(frames))
	for i, f := range frames {
		reqs[i] = writeRequest{
			class:  CLSDATA,
			frame:  f,
			seq:    atomic.AddUint32(&s.requestID, 1),
			result: make(chan writeResult, 1),
			glue:   f.cmd == cmdPAD,
		}
	}

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

	sent := 0
	for _, r := range reqs {
		select {
		case result := <-r.result:
			if r.frame.cmd != cmdPAD {
				sent += result.n
			}
			if result.err != nil {
				return sent, result.err
			}
		case <-s.die:
			return sent, io.ErrClosedPipe
		case <-s.chSocketWriteError:
			return sent, s.socketWriteError.Load().(error)
		case <-deadline:
			return sent, ErrTimeout
		}
	}
	return sent, nil
}
