package dialer

import (
	"net"
	"sync"
	"time"

	"github.com/metacubex/mihomo/log"
)

// tlsFragmentConn fragments the first write of a connection when that write is
// a TLS ClientHello. It locates the SNI hostname inside the ClientHello and
// splits the buffer so the hostname is shredded across several TCP segments,
// defeating on-path DPI that reads the SNI from a single packet. If the SNI
// cannot be parsed it falls back to cutting the record into three parts. The
// real server reassembles the TCP stream normally, so the handshake succeeds.
// Strictly opt-in.
type tlsFragmentConn struct {
	net.Conn
	size  int
	delay time.Duration
	done  bool
}

const (
	defaultFragmentSize  = 8 // max bytes per SNI fragment; small = harder to match
	defaultFragmentDelay = 5 * time.Millisecond
)

var tlsFragmentActiveOnce sync.Once

// isTLSClientHello reports whether b starts with a TLS handshake record
// (content type 0x16) of a TLS 1.x record (major version 0x03).
func isTLSClientHello(b []byte) bool {
	return len(b) >= 3 && b[0] == 0x16 && b[1] == 0x03
}

// sniHostRange returns the byte range [start,end) of the SNI hostname within a
// TLS record buffer b. It is adapted from mihomo's own ClientHello sniffer
// (component/sniffer/tls_sniffer.go ReadClientHello) but tracks absolute
// offsets instead of returning the string. ok is false if b is not a
// parseable ClientHello carrying an SNI.
func sniHostRange(b []byte) (start, end int, ok bool) {
	if len(b) < 5 || b[0] != 0x16 || b[1] != 0x03 {
		return 0, 0, false
	}
	recLen := int(b[3])<<8 | int(b[4])
	if 5+recLen > len(b) {
		return 0, 0, false
	}
	hs := b[5 : 5+recLen] // handshake message
	n := len(hs)
	if n < 42 {
		return 0, 0, false
	}
	sessionIDLen := int(hs[38])
	if sessionIDLen > 32 || n < 39+sessionIDLen {
		return 0, 0, false
	}
	i := 39 + sessionIDLen
	if n < i+2 {
		return 0, 0, false
	}
	cipherSuiteLen := int(hs[i])<<8 | int(hs[i+1])
	i += 2
	if cipherSuiteLen%2 == 1 || n < i+cipherSuiteLen {
		return 0, 0, false
	}
	i += cipherSuiteLen
	if n < i+1 {
		return 0, 0, false
	}
	compLen := int(hs[i])
	i++
	if n < i+compLen {
		return 0, 0, false
	}
	i += compLen
	if n < i+2 {
		return 0, 0, false
	}
	extLen := int(hs[i])<<8 | int(hs[i+1])
	i += 2
	if i+extLen != n {
		return 0, 0, false
	}
	extEnd := i + extLen
	for i < extEnd {
		if i+4 > n {
			return 0, 0, false
		}
		ext := int(hs[i])<<8 | int(hs[i+1])
		l := int(hs[i+2])<<8 | int(hs[i+3])
		i += 4
		if i+l > n {
			return 0, 0, false
		}
		if ext == 0x00 { // server_name
			j := i
			if l < 2 {
				return 0, 0, false
			}
			namesLen := int(hs[j])<<8 | int(hs[j+1])
			j += 2
			namesEnd := j + namesLen
			if namesEnd > i+l || namesEnd > n {
				return 0, 0, false
			}
			for j < namesEnd {
				if j+3 > n {
					return 0, 0, false
				}
				nameType := hs[j]
				nameLen := int(hs[j+1])<<8 | int(hs[j+2])
				j += 3
				if j+nameLen > n {
					return 0, 0, false
				}
				if nameType == 0 { // host_name; absolute offset into b is 5+j
					return 5 + j, 5 + j + nameLen, true
				}
				j += nameLen
			}
		}
		i += l
	}
	return 0, 0, false
}

// fragmentCuts returns sorted interior boundaries (0 < cut < len(b)) at which
// the ClientHello should be split.
func (c *tlsFragmentConn) fragmentCuts(b []byte) []int {
	if s, e, ok := sniHostRange(b); ok && e > s {
		var cuts []int
		if s > 0 {
			cuts = append(cuts, s) // isolate the bytes before the SNI
		}
		step := c.size
		if step >= e-s { // guarantee the hostname itself is split at least once
			step = (e - s + 1) / 2
		}
		if step < 1 {
			step = 1
		}
		for p := s + step; p < e; p += step {
			cuts = append(cuts, p)
		}
		if e < len(b) {
			cuts = append(cuts, e) // isolate the bytes after the SNI
		}
		return cuts
	}
	// fallback: SNI not parseable — cut into three parts so the middle, where
	// the SNI usually sits, is split, with bounded overhead.
	if len(b) >= 3 {
		return []int{len(b) / 3, 2 * len(b) / 3}
	}
	return nil
}

func (c *tlsFragmentConn) Write(b []byte) (int, error) {
	if c.done {
		return c.Conn.Write(b)
	}
	c.done = true

	if !isTLSClientHello(b) {
		return c.Conn.Write(b)
	}
	cuts := c.fragmentCuts(b)
	if len(cuts) == 0 {
		return c.Conn.Write(b)
	}

	tlsFragmentActiveOnce.Do(func() {
		log.Infoln("[TLSFragment] active: fragmenting TLS ClientHello SNI across %d segments", len(cuts)+1)
	})
	log.Debugln("[TLSFragment] ClientHello %d bytes -> %d segments (cuts=%v)", len(b), len(cuts)+1, cuts)

	total := 0
	prev := 0
	for _, cut := range cuts {
		if cut <= prev || cut >= len(b) {
			continue
		}
		n, err := c.Conn.Write(b[prev:cut])
		total += n
		if err != nil {
			return total, err
		}
		prev = cut
		if c.delay > 0 {
			time.Sleep(c.delay)
		}
	}
	n, err := c.Conn.Write(b[prev:])
	return total + n, err
}

func newTLSFragmentConn(conn net.Conn, size int, delay time.Duration) net.Conn {
	if size <= 0 {
		size = defaultFragmentSize
	}
	if delay <= 0 {
		delay = defaultFragmentDelay
	}
	return &tlsFragmentConn{Conn: conn, size: size, delay: delay}
}
