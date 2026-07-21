//go:build !cgo && !windows

package main

import (
	"os"
	"time"
)

const filetimeUnixEpochOffsetSeconds = 11_644_473_600

var processCreationTime100ns = func() uint64 {
	startedAt := time.Now()
	return uint64(startedAt.Unix()+filetimeUnixEpochOffsetSeconds)*10_000_000 +
		uint64(startedAt.Nanosecond()/100)
}()

func currentCoreProcessIdentity() (coreProcessIdentity, error) {
	return coreProcessIdentity{
		pid:               os.Getpid(),
		creationTime100ns: processCreationTime100ns,
	}, nil
}
