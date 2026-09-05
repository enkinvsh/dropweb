//go:build cgo

package main

/*
#include <stdlib.h>
*/
import "C"
import (
	bridge "core/dart-bridge"
	"encoding/json"
	"unsafe"

	"github.com/metacubex/mihomo/log"
)

var messagePort int64 = -1

//export initNativeApiBridge
func initNativeApiBridge(api unsafe.Pointer) {
	bridge.InitDartApi(api)
}

//export attachMessagePort
func attachMessagePort(mPort C.longlong) {
	messagePort = int64(mPort)
}

//export getTraffic
func getTraffic() *C.char {
	return C.CString(handleGetTraffic())
}

//export getTotalTraffic
func getTotalTraffic() *C.char {
	return C.CString(handleGetTotalTraffic())
}

//export freeCString
func freeCString(s *C.char) {
	C.free(unsafe.Pointer(s))
}

// pushType reports the Message type carried by a push payload. Action results
// carry arbitrary data and yield the empty type.
func pushType(payload any) MessageType {
	message, ok := payload.(Message)
	if !ok {
		return ""
	}
	return message.Type
}

func (result ActionResult) send() {
	data, err := result.Json()
	if err != nil {
		return
	}
	if !bridge.SendToPort(result.Port, string(data)) {
		// handleStartLog forwards every log event back through sendMessage, so
		// warning about a dropped log push would emit another log line, which
		// becomes another dropped push, and so on. Log pushes stay silent.
		if messageType := pushType(result.Data); messageType != LogMessage {
			log.Warnln(
				"[bridge] dropped push method=%s type=%s port=%d: message port rejected the payload",
				result.Method, messageType, result.Port,
			)
		}
	}
}

//export invokeAction
func invokeAction(paramsChar *C.char, port C.longlong) {
	params := C.GoString(paramsChar)
	i := int64(port)
	var action = &Action{}
	err := json.Unmarshal([]byte(params), action)
	if err != nil {
		// The Dart listener json.decodes every port message; posting a raw error
		// string crashes it. The action id is unknown on a parse failure, so no
		// completer could be resolved anyway -- log and drop.
		log.Errorln("invokeAction: invalid params: %v", err)
		return
	}
	result := ActionResult{
		Id:     action.Id,
		Method: action.Method,
		Port:   i,
	}
	go handleAction(action, result)
}

func sendMessage(message Message) {
	if messagePort == -1 {
		if message.Type != LogMessage {
			log.Warnln("[bridge] dropped push type=%s: no message port attached", message.Type)
		}
		return
	}
	result := ActionResult{
		Method: messageMethod,
		Port:   messagePort,
		Data:   message,
	}
	result.send()
}

//export getConfig
func getConfig(s *C.char) *C.char {
	path := C.GoString(s)
	config, err := handleGetConfig(path)
	if err != nil {
		return C.CString("")
	}
	marshal, err := json.Marshal(config)
	if err != nil {
		return C.CString("")
	}
	return C.CString(string(marshal))
}

//export startListener
func startListener() {
	handleStartListener()
}

//export stopListener
func stopListener() {
	handleStopListener()
}
