//go:build !cgo

package main

import (
	"fmt"
	"os"
)

func main() {
	config, err := parseServerArgs(os.Args[1:])
	if err != nil {
		fmt.Printf("Arguments error: %v\n", err)
		os.Exit(1)
	}
	if err := startServer(config); err != nil {
		fmt.Printf("ERROR: %v\n", err)
		os.Exit(1)
	}
}
