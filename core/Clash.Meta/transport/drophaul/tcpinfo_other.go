//go:build !linux

package drophaul

import (
	"net"
	"time"
)

type tcpSample struct {
	rtt          time.Duration
	segsOut      uint32
	totalRetrans uint32
	unacked      uint32
	retransmits  uint8
	hasCounters  bool
}

func unwrapTCPConn(conn net.Conn) *net.TCPConn {
	for conn != nil {
		switch c := conn.(type) {
		case *net.TCPConn:
			return c
		case interface{ NetConn() net.Conn }:
			conn = c.NetConn()
		default:
			return nil
		}
	}
	return nil
}

func connTCPStats(net.Conn) (tcpSample, bool) {
	return tcpSample{}, false
}
