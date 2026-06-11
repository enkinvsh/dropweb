/// Client-side DNS-over-HTTPS (DoH) resolution of a pooled subscription domain
/// into its individual server IPs.
///
/// The panel delivers ONE pooled node per country (e.g. `🇩🇪 Германия` with
/// `server: de.meybz.asia`). That domain's A record is a POOL of several real
/// server IPs. mihomo's `tcp-concurrent` races them, so the exit IP is
/// non-deterministic — unacceptable for an arbitrage user who needs a FIXED
/// IP. Resolving the pool client-side lets the user pin one IP and the engine
/// build a proxy variant whose `server` is that exact IP.
///
/// Uses Cloudflare's DoH JSON API (`1.1.1.1/dns-query`). The parsing is split
/// into the pure [parseDohAnswer] so it is unit-testable without the network.
library;

import 'package:dio/dio.dart';
import 'package:dropweb/common/country.dart';
import 'package:dropweb/common/print.dart';

/// Cloudflare DoH JSON endpoint. The `accept: application/dns-json` header
/// selects the JSON response format (vs. RFC 8484 wire format).
const _dohEndpoint = 'https://1.1.1.1/dns-query';

/// DNS resource-record type for an IPv4 address (`A`). Records of any other
/// type (e.g. `AAAA` == 28, `CNAME` == 5) are ignored by [parseDohAnswer].
const _dnsTypeA = 1;

/// Short in-memory TTL for the resolved-IP cache. A pooled domain's A set is
/// stable for minutes, and the strict-node UI re-resolves on every rebuild, so
/// a tiny cache avoids hammering Cloudflare without risking stale pins.
const _cacheTtl = Duration(seconds: 60);

class _CacheEntry {
  _CacheEntry(this.ips, this.at);
  final List<String> ips;
  final DateTime at;
}

final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};

/// Lazily-created Dio for DoH lookups. A dedicated instance (no app User-Agent,
/// no clash proxy adapter) so resolution goes out directly — on Android/iOS the
/// app is excluded from the VPN, so this is the real DNS pool, not the proxied
/// view.
Dio? _dohDio;
Dio _dio() => _dohDio ??= Dio();

/// Resolves the pooled [host] into its ordered, de-duplicated list of IPv4
/// server IPs via Cloudflare DoH.
///
/// Returns `const []` on timeout, network error, a non-200 response, or an
/// empty/garbage answer — the caller falls back to the pooled node itself.
/// Errors are logged via [commonPrint]; never swallowed silently.
///
/// Results are cached per host for [_cacheTtl] to avoid re-resolving on every
/// UI rebuild. A previously-cached EMPTY result is also honored for the TTL so
/// a transient failure does not trigger a resolve storm.
Future<List<String>> resolvePoolIps(
  String host, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (host.isEmpty) return const [];

  final cached = _cache[host];
  if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
    return cached.ips;
  }

  try {
    final response = await _dio().get<dynamic>(
      _dohEndpoint,
      queryParameters: <String, dynamic>{'name': host, 'type': 'A'},
      options: Options(
        headers: <String, dynamic>{'accept': 'application/dns-json'},
        responseType: ResponseType.json,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    final data = response.data;
    final Map<String, dynamic> json;
    if (data is Map<String, dynamic>) {
      json = data;
    } else if (data is Map) {
      json = data.cast<String, dynamic>();
    } else {
      commonPrint.log('doh: unexpected response shape for $host');
      _cache[host] = _CacheEntry(const [], DateTime.now());
      return const [];
    }

    final ips = parseDohAnswer(json);
    _cache[host] = _CacheEntry(ips, DateTime.now());
    return ips;
  } on DioException catch (e) {
    commonPrint.log('doh: resolve failed for $host: ${e.type}');
    _cache[host] = _CacheEntry(const [], DateTime.now());
    return const [];
  } catch (e) {
    commonPrint.log('doh: resolve error for $host: $e');
    _cache[host] = _CacheEntry(const [], DateTime.now());
    return const [];
  }
}

/// Pure parser for a Cloudflare DoH JSON body.
///
/// Extracts the `data` of every `Answer[]` entry whose `type == 1` (an `A`
/// record) that is a valid IPv4 string, preserving order and de-duplicating.
/// Non-A records (AAAA/CNAME/…), malformed entries, and a missing/odd `Answer`
/// field all yield no IPs. Always returns a (possibly empty) list — never null.
List<String> parseDohAnswer(Map<String, dynamic> json) {
  final answer = json['Answer'];
  if (answer is! List) return const [];

  final ips = <String>[];
  final seen = <String>{};
  for (final entry in answer) {
    if (entry is! Map) continue;
    if (entry['type'] != _dnsTypeA) continue;
    final data = entry['data'];
    if (data is! String) continue;
    if (!isIpv4(data)) continue;
    if (seen.add(data)) ips.add(data);
  }
  return ips;
}

/// Clears the in-memory DoH cache. Test-only seam.
void debugClearDohCache() => _cache.clear();
