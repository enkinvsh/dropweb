//go:build !cgo

package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"strconv"
)

var conn net.Conn

type serverConfig struct {
	bridge   string
	runToken string
}

type coreProcessIdentity struct {
	pid               int
	creationTime100ns uint64
}

type coreBridgeHello struct {
	Type                  string `json:"type"`
	Protocol              int    `json:"protocol"`
	RunToken              string `json:"runToken"`
	CorePID               int    `json:"corePid"`
	CoreCreationTime100ns uint64 `json:"coreCreationTime100ns"`
}

func parseServerArgs(args []string) (serverConfig, error) {
	if len(args) != 3 || args[0] == "" || args[1] != "--run-token" {
		return serverConfig{}, errors.New("expected <bridge> --run-token <32 lowercase hex>")
	}
	if len(args[2]) != 32 {
		return serverConfig{}, errors.New("run token must contain 32 lowercase hexadecimal characters")
	}
	for _, char := range args[2] {
		if !((char >= '0' && char <= '9') || (char >= 'a' && char <= 'f')) {
			return serverConfig{}, errors.New("run token must contain 32 lowercase hexadecimal characters")
		}
	}
	return serverConfig{bridge: args[0], runToken: args[2]}, nil
}

func (result ActionResult) send() {
	data, err := result.Json()
	if err != nil {
		return
	}
	send(data)
}

func sendMessage(message Message) {
	result := ActionResult{
		Method: messageMethod,
		Data:   message,
	}
	result.send()
}

func send(data []byte) {
	if conn == nil {
		return
	}
	_, _ = conn.Write(append(data, []byte("\n")...))
}

func startServer(config serverConfig) error {
	_, err := strconv.Atoi(config.bridge)
	if err != nil {
		conn, err = net.Dial("unix", config.bridge)
	} else {
		conn, err = net.Dial("tcp", fmt.Sprintf("127.0.0.1:%s", config.bridge))
	}
	if err != nil {
		return fmt.Errorf("failed to connect to server: %w", err)
	}
	defer func(conn net.Conn) {
		_ = conn.Close()
	}(conn)
	identity, err := currentCoreProcessIdentity()
	if err != nil {
		return fmt.Errorf("read core process identity: %w", err)
	}
	serveCoreBridge(conn, config, identity)
	return nil
}

func serveCoreBridge(connection net.Conn, config serverConfig, identity coreProcessIdentity) {
	conn = connection
	hello := coreBridgeHello{
		Type:                  "dropweb-core-hello",
		Protocol:              1,
		RunToken:              config.runToken,
		CorePID:               identity.pid,
		CoreCreationTime100ns: identity.creationTime100ns,
	}
	data, err := json.Marshal(hello)
	if err != nil {
		return
	}
	if _, err := connection.Write(append(data, '\n')); err != nil {
		return
	}

	reader := bufio.NewReader(connection)

	for {
		data, err := reader.ReadString('\n')
		if err != nil {
			return
		}
		var action = &Action{}

		err = json.Unmarshal([]byte(data), action)

		if err != nil {
			return
		}

		result := ActionResult{
			Id:     action.Id,
			Method: action.Method,
		}

		go handleAction(action, result)
	}
}

func nextHandle(action *Action, result ActionResult) bool {
	return false
}
