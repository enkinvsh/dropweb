/// Разбор правил и узлов Mihomo/Clash: маршрутизируемость узла и цель правила.
library;

/// Built-in rule targets that are not proxy-groups.
const mihomoBuiltinTargets = {'DIRECT', 'REJECT', 'REJECT-DROP', 'PASS'};

/// Whether [proxy] (a top-level `proxies[]` entry) is a structurally routable
/// node, as opposed to a non-routable SENTINEL that Remnawave/xray-style panels
/// inject for expiry / device-limit / HWID-lock / bot-link states (e.g. a
/// 🇸🇴 «Подписка истекла» placeholder or a flagless «Докупите устройства»).
///
/// The check is provider-AGNOSTIC and structural — no name/flag regex: a real
/// proxy never points at `0.0.0.0`/loopback, a port ≤ 1, or the all-zero
/// VLESS/VMess UUID. Dropping these keeps dead "countries" out of routing
/// candidate sets before any liveness probe runs. Shared single source of truth
/// for `work_mode_patch` (Smart/Country candidate filtering).
bool isRoutableProxy(Map proxy) {
  final server = proxy['server']?.toString().trim() ?? '';
  if (server.isEmpty ||
      server == '0.0.0.0' ||
      server == '::' ||
      server == '127.0.0.1' ||
      server == '::1') {
    return false;
  }
  final rawPort = proxy['port'];
  final port =
      rawPort is int ? rawPort : int.tryParse(rawPort?.toString() ?? '');
  if (port != null && port <= 1) return false;
  final uuid = proxy['uuid']?.toString();
  if (uuid == '00000000-0000-0000-0000-000000000000') return false;
  return true;
}

/// Extracts the TARGET token of a mihomo rule string.
///
/// Rules take the form `TYPE,arg,TARGET[,opts]` or `MATCH,TARGET`. The TARGET
/// is the second field for `MATCH`/`RULE-SET`-style two-field rules and the
/// third field otherwise, but logical rules (`AND`/`OR`/`NOT`) wrap their
/// matcher in nested parentheses, so a naive comma split fails.
String? ruleTarget(String rule) {
  final fields = splitTopLevel(rule);
  if (fields.isEmpty) return null;
  final type = fields.first.trim();
  if (type == 'MATCH') {
    return fields.length >= 2 ? fields[1].trim() : null;
  }
  // For TYPE,arg,TARGET[,opts]: target is field index 2 when present,
  // otherwise the last field (covers TYPE,TARGET shapes defensively).
  if (fields.length >= 3) {
    return fields[2].trim();
  }
  if (fields.length == 2) {
    return fields[1].trim();
  }
  return null;
}

/// Splits [s] on commas that are NOT nested inside parentheses, so logical
/// rules like `AND,((NETWORK,udp),(DST-PORT,443)),REJECT` split into three
/// fields: `AND`, `((NETWORK,udp),(DST-PORT,443))`, `REJECT`.
List<String> splitTopLevel(String s) {
  final fields = <String>[];
  final buf = StringBuffer();
  var depth = 0;
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '(') {
      depth++;
      buf.write(ch);
    } else if (ch == ')') {
      if (depth > 0) depth--;
      buf.write(ch);
    } else if (ch == ',' && depth == 0) {
      fields.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  if (buf.isNotEmpty) fields.add(buf.toString());
  return fields;
}
