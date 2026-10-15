package tun

// maxConsecutiveEmptyReads bounds every tun read loop on this stack —
// both the darwin batch loops and the generic single-packet tunLoop.
//
// On macOS a torn-down utun descriptor (sleep/wake, Wi-Fi roam, interface down)
// makes recvmsg_x return either EBADF or "0 messages, no error". Neither was
// treated as terminal, so the loop re-issued the syscall immediately, forever:
// measured at 38M iterations/s for the EBADF path and 1.5B/s for the silent
// one, pinning a full core per leaked loop with no traffic and, in the silent
// case, no log output at all.
//
// A healthy tun never yields this: when idle, BatchRead blocks inside
// BlockingPollUntilStopped instead of returning empty. So a run of empty reads
// means the descriptor is gone and the loop must stop rather than spin.
const maxConsecutiveEmptyReads = 1 << 10
