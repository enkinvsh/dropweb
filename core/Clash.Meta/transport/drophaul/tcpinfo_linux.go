//go:build linux

package drophaul

import (
	"net"
	"time"

	"golang.org/x/sys/unix"
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

func connTCPStats(conn net.Conn) (tcpSample, bool) {
	tcp := unwrapTCPConn(conn)
	if tcp == nil {
		return tcpSample{}, false
	}
	raw, err := tcp.SyscallConn()
	if err != nil {
		return tcpSample{}, false
	}
	var info *unix.TCPInfo
	var sockErr error
	if err := raw.Control(func(fd uintptr) {
		info, sockErr = unix.GetsockoptTCPInfo(int(fd), unix.IPPROTO_TCP, unix.TCP_INFO)
	}); err != nil || sockErr != nil || info == nil || info.Rtt == 0 {
		return tcpSample{}, false
	}
	return tcpSample{
		rtt:          time.Duration(info.Rtt) * time.Microsecond,
		segsOut:      info.Segs_out,
		totalRetrans: info.Total_retrans,
		unacked:      info.Unacked,
		retransmits:  info.Retransmits,
		hasCounters:  true,
	}, true
}
