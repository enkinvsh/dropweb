//go:build ios && cgo

package main

/*
#include <stdlib.h>
#include <os/proc.h>
*/
import "C"
import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"sync"
	"sync/atomic"
	"time"

	"core/state"
	t "core/tun"

	"github.com/metacubex/mihomo/component/resource"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/listener/sing_tun"
	singtun "github.com/metacubex/sing-tun"
	"golang.org/x/sys/unix"
)

// The utun MTU, shared by NEPacketTunnelNetworkSettings and sing-tun.
// iOS rejects 9000 (nehelper "Cannot set MTU, Invalid argument").
const iosTunMTU = 1500

// The only TUN stack that works inside NetworkExtension. The system stack hands
// TCP to a kernel listener, but the provider's own sockets bypass its tunnel,
// so the listener's replies never come back through utun. gVisor is not built.
const iosTunStack = constant.TunMips

// Lite mode (iOS 13–14) caps the Go scheduler too: every P carries its own
// caches and GC worker, which the 15 MB extension cannot spare.
const iosLiteMaxProcs = 2

var (
	iosTunLock sync.Mutex
	iosTun     *sing_tun.Listener
)

// iosTunnelProcess истинно в процессе расширения PacketTunnel: iosQuickStart
// вызывает только оно, приложение ходит в ядро через invokeAction.
var iosTunnelProcess atomic.Bool

func init() {
	// Nothing on iOS reads allocation profiles, and the first sampled
	// allocation maps the profiler's 1.4 MB bucket table.
	runtime.MemProfileRate = 0
	privateCacheDir = iosPrivateCacheDir
}

// iosPrivateCacheDir уводит cache.db ядра приложения из общего контейнера
// App Group. Приложение засыпает на ходу, а bbolt держит flock до конца
// процесса: на свежей установке первый же запуск ядра без профиля открывал
// <group>/dropweb/cache.db, и через секунды RunningBoard убивал Runner с
// 0xdead10cc. Расширение не усыпляется, пока туннель поднят, и остаётся со
// своим кэшем в группе. Если Library/Caches недоступен, берём tmp: при
// невозможности открыть БД кэш просто отключается, замка в группе не будет.
func iosPrivateCacheDir() string {
	if iosTunnelProcess.Load() {
		return ""
	}
	base, err := os.UserCacheDir()
	if err != nil {
		base = os.TempDir()
	}
	return filepath.Join(base, "dropweb")
}

func nextHandle(action *Action, result ActionResult) bool { return false }

// iosQuickStart mirrors Android quickStart synchronously: init, state, setup.
// Returns "" on success, otherwise the error text.
//
//export iosQuickStart
func iosQuickStart(initParams, setupParams, stateParams *C.char) *C.char {
	initJSON := C.GoString(initParams)
	setupJSON := C.GoString(setupParams)
	stateJSON := C.GoString(stateParams)
	// Parse on a fresh goroutine: the YAML parse grows the stack deep, and the
	// goroutine of a cgo callback keeps its grown stack for the thread's life,
	// while an exited goroutine hands it back to the heap.
	done := make(chan string, 1)
	go func() { done <- iosQuickStartGo(initJSON, setupJSON, stateJSON) }()
	return C.CString(<-done)
}

func iosQuickStartGo(initJSON, setupJSON, stateJSON string) string {
	// The app restarts the tunnel on every config change, so file providers
	// need no watchers (two goroutines and a kqueue each, ~40 per config).
	resource.DisableFileWatch = true
	singtun.AdmitConnection = iosAdmitConnection
	// До handleInitClash: он выбирает каталог cache.db по этому флагу.
	iosTunnelProcess.Store(true)
	if !handleInitClash(initJSON) {
		return "init error"
	}
	// handleInitClash has just set the Android defaults (192 MiB, GOGC 70).
	// Restore the lite budget before parsing the config: that is the
	// allocation peak, and jetsam kills the extension at 15 MB on iOS 13–14.
	applyIosMemoryLimit()
	_ = handleSetState(stateJSON)
	result := handleSetupConfig([]byte(setupJSON))
	// jetsam counts resident pages, not the live heap: hand the parse garbage
	// back to the OS now instead of waiting for the background scavenger.
	debug.FreeOSMemory()
	return result
}

// Lite memory budget (iOS 13–14); zero keeps the defaults from handleInitClash.
var (
	iosMemoryLimit int64
	iosGCPercent   int
)

// iosSetMemoryLimit must run BEFORE iosQuickStart, so the budget already
// holds while the config is parsed; iosQuickStart re-applies it after init.
//
//export iosSetMemoryLimit
func iosSetMemoryLimit(limitBytes C.longlong, gcPercent C.int) {
	iosMemoryLimit = int64(limitBytes)
	iosGCPercent = int(gcPercent)
	applyIosMemoryLimit()
}

func applyIosMemoryLimit() {
	if iosMemoryLimit == 0 {
		return
	}
	debug.SetMemoryLimit(iosMemoryLimit)
	debug.SetGCPercent(iosGCPercent)
	runtime.GOMAXPROCS(iosLiteMaxProcs)
}

// New TCP connections are paced by the headroom left before jetsam's
// per-process limit: a burst of them (an app reconnecting all at once) is what
// pushes the 15 MB extension of iOS 13-14 over. Open connections keep working,
// and the client retransmits a refused SYN about a second later.
var iosAdmission = connectionAdmission{
	floor:  1 << 20,     // never spent on new connections
	cost:   128 << 10,   // one proxied connection, settled (~100 KB on iPhone 8)
	window: time.Second, // until its handshakes are done
}

// Forcing the scavenger costs a full GC, so at most once per interval.
const iosReclaimInterval = time.Second

var iosLastReclaim atomic.Int64

func iosAdmitConnection() bool {
	available := int64(C.os_proc_available_memory())
	// 0: no per-process limit to guard (or it is already exceeded).
	if available == 0 || iosAdmission.admit(available, time.Now()) {
		return true
	}
	now := time.Now().UnixNano()
	last := iosLastReclaim.Load()
	if now-last >= int64(iosReclaimInterval) && iosLastReclaim.CompareAndSwap(last, now) {
		go debug.FreeOSMemory()
	}
	return false
}

// iosMemStats splits the Go side of the extension footprint for the
// dropweb-mem log (KiB): what jetsam counts minus this is Swift, NE and
// dirty binary pages.
//
//export iosMemStats
func iosMemStats() *C.char {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	const kib = 1024
	data, _ := json.Marshal(map[string]uint64{
		"sys":        m.Sys / kib,
		"heapInuse":  m.HeapInuse / kib,
		"heapIdle":   m.HeapIdle / kib,
		"heapRel":    m.HeapReleased / kib,
		"stack":      m.StackInuse / kib,
		"span":       m.MSpanInuse / kib,
		"buckhash":   m.BuckHashSys / kib,
		"gcSys":      m.GCSys / kib,
		"other":      (m.MCacheInuse + m.OtherSys) / kib,
		"stackSys":   m.StackSys / kib,
		"numGC":      uint64(m.NumGC),
		"goroutines": uint64(runtime.NumGoroutine()),
		"avail":      uint64(C.os_proc_available_memory()) / kib,
	})
	return C.CString(string(data))
}

// iosTunSettings tells Swift which addresses to give NEPacketTunnelNetworkSettings.
//
//export iosTunSettings
func iosTunSettings() *C.char {
	data, _ := json.Marshal(map[string]any{
		"ipv4": state.DefaultIpv4Address,
		"ipv6": state.GetIpv6Address(),
		"dns":  state.GetDnsServerAddress(),
		"mtu":  iosTunMTU,
	})
	return C.CString(string(data))
}

// iosStartTun finds the utun socket NetworkExtension opened for us and hands it
// to sing-tun. Call after setTunnelNetworkSettings completed.
//
//export iosStartTun
func iosStartTun() *C.char {
	iosTunLock.Lock()
	defer iosTunLock.Unlock()
	closeIosTun()
	fd := findUtunFd()
	if fd < 0 {
		return C.CString("utun fd not found")
	}
	listener, err := t.Start(fd, currentConfig.General.Tun.Device, iosTunStack, iosTunMTU)
	if err != nil {
		return C.CString(err.Error())
	}
	iosTun = listener
	return C.CString("")
}

//export iosStopTun
func iosStopTun() {
	iosTunLock.Lock()
	defer iosTunLock.Unlock()
	closeIosTun()
}

func closeIosTun() {
	if iosTun != nil {
		_ = iosTun.Close()
		iosTun = nil
	}
}

// iosInvokeAction runs the same JSON action protocol as invokeAction and
// blocks until the result is ready (call it off the main queue).
//
//export iosInvokeAction
func iosInvokeAction(paramsChar *C.char) *C.char {
	action := &Action{}
	if err := json.Unmarshal([]byte(C.GoString(paramsChar)), action); err != nil {
		return C.CString(`{"code":-1,"data":"invalid params"}`)
	}
	port, ch := registerSyncSink()
	go handleAction(action, ActionResult{Id: action.Id, Method: action.Method, Port: port})
	select {
	case result := <-ch:
		data, _ := result.Json()
		return C.CString(string(data))
	case <-time.After(30 * time.Second):
		syncSinks.Delete(port)
		return C.CString(`{"code":-1,"data":"timeout"}`)
	}
}

// findUtunFd: same scan WireGuard uses — the utun control socket of this process.
func findUtunFd() int {
	info := &unix.CtlInfo{}
	copy(info.Name[:], "com.apple.net.utun_control")
	for fd := 0; fd < 1024; fd++ {
		addr, err := unix.Getpeername(fd)
		if err != nil {
			continue
		}
		ctl, ok := addr.(*unix.SockaddrCtl)
		if !ok {
			continue
		}
		if info.Id == 0 {
			if err := unix.IoctlCtlInfo(fd, info); err != nil {
				continue
			}
		}
		if ctl.ID == info.Id {
			return fd
		}
	}
	return -1
}
