package org.dropweb.vpn.core

import java.net.InetAddress
import java.net.InetSocketAddress

data object Core {
    private external fun startTun(
        fd: Int,
        cb: TunInterface
    )

    private fun parseInetSocketAddress(address: String): InetSocketAddress {
        // Runs on a JNI callback thread — any throw crashes the process. Parse
        // manually (bare IPv6 / missing port break URL) and fall back to the
        // wildcard:0 address, which the resolver call site tolerates (-1 uid → "").
        return try {
            val idx = address.lastIndexOf(':')
            if (idx < 0) return InetSocketAddress(0)
            val host = address.substring(0, idx).removePrefix("[").removeSuffix("]")
            val port = address.substring(idx + 1).toIntOrNull() ?: 0
            InetSocketAddress(InetAddress.getByName(host), port)
        } catch (e: Exception) {
            InetSocketAddress(0)
        }
    }

    fun startTun(
        fd: Int,
        protect: (Int) -> Boolean,
        resolverProcess: (protocol: Int, source: InetSocketAddress, target: InetSocketAddress, uid: Int) -> String
    ) {
        startTun(fd, object : TunInterface {
            override fun protect(fd: Int) {
                protect(fd)
            }

            override fun resolverProcess(
                protocol: Int,
                source: String,
                target: String,
                uid: Int
            ): String {
                return resolverProcess(
                    protocol,
                    parseInetSocketAddress(source),
                    parseInetSocketAddress(target),
                    uid,
                )
            }
        });
    }

    external fun stopTun()

    init {
        System.loadLibrary("core")
    }
}