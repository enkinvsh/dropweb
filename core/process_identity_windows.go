//go:build !cgo && windows

package main

import (
	"os"

	"golang.org/x/sys/windows"
)

func currentCoreProcessIdentity() (coreProcessIdentity, error) {
	var creation windows.Filetime
	var exit windows.Filetime
	var kernel windows.Filetime
	var user windows.Filetime
	if err := windows.GetProcessTimes(
		windows.CurrentProcess(),
		&creation,
		&exit,
		&kernel,
		&user,
	); err != nil {
		return coreProcessIdentity{}, err
	}
	return coreProcessIdentity{
		pid:               os.Getpid(),
		creationTime100ns: uint64(creation.HighDateTime)<<32 | uint64(creation.LowDateTime),
	}, nil
}
