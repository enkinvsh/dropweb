//go:build !cgo

package main

import (
	"bufio"
	"encoding/json"
	"io"
	"net"
	"os"
	"strings"
	"testing"
)

func captureStderr(t *testing.T, run func()) string {
	t.Helper()
	reader, writer, err := os.Pipe()
	if err != nil {
		t.Fatalf("create stderr pipe: %v", err)
	}
	previous := os.Stderr
	os.Stderr = writer
	t.Cleanup(func() { os.Stderr = previous })

	run()

	os.Stderr = previous
	if err := writer.Close(); err != nil {
		t.Fatalf("close stderr writer: %v", err)
	}
	output, err := io.ReadAll(reader)
	if err != nil {
		t.Fatalf("read stderr: %v", err)
	}
	if err := reader.Close(); err != nil {
		t.Fatalf("close stderr reader: %v", err)
	}
	return string(output)
}

func TestParseServerArgsRequiresBridgeAndLowercaseRunToken(t *testing.T) {
	tests := []struct {
		name    string
		args    []string
		wantErr bool
	}{
		{name: "accepts exact contract", args: []string{"59750", "--run-token", "0123456789abcdef0123456789abcdef"}},
		{name: "rejects missing token", args: []string{"59750"}, wantErr: true},
		{name: "rejects short token", args: []string{"59750", "--run-token", "0123"}, wantErr: true},
		{name: "rejects uppercase token", args: []string{"59750", "--run-token", "0123456789ABCDEF0123456789ABCDEF"}, wantErr: true},
		{name: "rejects extra arguments", args: []string{"59750", "--run-token", "0123456789abcdef0123456789abcdef", "extra"}, wantErr: true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			config, err := parseServerArgs(test.args)
			if test.wantErr {
				if err == nil {
					t.Fatal("expected parse error")
				}
				return
			}
			if err != nil {
				t.Fatalf("parseServerArgs returned error: %v", err)
			}
			if config.bridge != "59750" || config.runToken != "0123456789abcdef0123456789abcdef" {
				t.Fatalf("unexpected config: %#v", config)
			}
		})
	}
}

func TestServeCoreBridgeWritesHelloAsFirstFrame(t *testing.T) {
	server, client := net.Pipe()
	done := make(chan struct{})
	go func() {
		serveCoreBridge(server, serverConfig{
			bridge:   "59750",
			runToken: "0123456789abcdef0123456789abcdef",
		}, coreProcessIdentity{pid: 42, creationTime100ns: 1337})
		close(done)
	}()

	line, err := bufio.NewReader(client).ReadBytes('\n')
	if err != nil {
		t.Fatalf("read hello: %v", err)
	}
	var hello coreBridgeHello
	if err := json.Unmarshal(line, &hello); err != nil {
		t.Fatalf("decode hello: %v", err)
	}
	if hello.Type != "dropweb-core-hello" || hello.Protocol != 1 {
		t.Fatalf("unexpected hello header: %#v", hello)
	}
	if hello.RunToken != "0123456789abcdef0123456789abcdef" || hello.CorePID != 42 || hello.CoreCreationTime100ns != 1337 {
		t.Fatalf("unexpected hello identity: %#v", hello)
	}

	_ = client.Close()
	<-done
}

func TestServeCoreBridgeLogsActionLoopReadEOFWhenPeerCloses(t *testing.T) {
	output := captureStderr(t, func() {
		server, client := net.Pipe()
		done := make(chan struct{})
		go func() {
			serveCoreBridge(server, serverConfig{
				bridge:   "59750",
				runToken: "0123456789abcdef0123456789abcdef",
			}, coreProcessIdentity{pid: 42, creationTime100ns: 1337})
			close(done)
		}()

		if _, err := bufio.NewReader(client).ReadBytes('\n'); err != nil {
			t.Fatalf("read hello: %v", err)
		}
		if err := client.Close(); err != nil {
			t.Fatalf("close peer: %v", err)
		}
		<-done
	})

	if !strings.Contains(output, "[core-bridge] action loop ended: read: EOF") {
		t.Fatalf("missing action-loop EOF diagnostic: %q", output)
	}
}
