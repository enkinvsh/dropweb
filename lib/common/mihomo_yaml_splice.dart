/// Deterministic text-splice helpers for additively patching a Mihomo/Clash
/// YAML document while preserving the rest of the file — comments, formatting,
/// key order — byte-for-byte.
///
/// These intentionally do NOT use `package:yaml_edit` for list appends:
/// yaml_edit mis-indents a complex map appended to a list whose final item
/// carries an empty/comment-only nested block (the mihomo
/// `proxies:\n  # LEAVE THIS LINE!` placeholder). Rendering blocks to
/// correctly-indented YAML text and splicing them in avoids that.
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

/// Inserts [ruleLines] (rendered block-list items at correct indentation) at the
/// TOP of the top-level `rules` block so they take precedence (mihomo evaluates
/// rules top-down, first match wins). Creates a `rules` block at end of document
/// if one is absent.
String prependRules(String yaml, String ruleLines) {
  final items = ruleLines.split('\n');
  if (items.isNotEmpty && items.last.isEmpty) items.removeLast();
  if (items.isEmpty) return yaml;

  final lines = yaml.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if ((line == 'rules:' || line.startsWith('rules:')) &&
        !line.startsWith(' ') &&
        !line.startsWith('\t')) {
      lines.insertAll(i + 1, items);
      return lines.join('\n');
    }
  }
  final buf = StringBuffer(yaml);
  if (!yaml.endsWith('\n')) buf.write('\n');
  buf
    ..write('rules:\n')
    ..write(ruleLines);
  return buf.toString();
}

/// Render [s] as a YAML scalar, single-quoting + escaping when the value could
/// otherwise change YAML semantics. Mirrors the conservative quoting used by
/// the share-link emitter so emitted nodes parse back identically.
String yamlScalar(String s) {
  if (s.isEmpty) return "''";
  if (_needsQuoting(s)) {
    return "'${s.replaceAll("'", "''")}'";
  }
  return s;
}

bool _needsQuoting(String s) {
  if (s != s.trim()) return true;
  if (s.contains('#')) return true;
  if (s.contains(': ')) return true;
  if (s.contains(' #')) return true;
  if (s.contains('\n') || s.contains('\t') || s.contains('\r')) return true;
  const reserved = {'true', 'false', 'null', 'yes', 'no', 'on', 'off', '~'};
  if (reserved.contains(s.toLowerCase())) return true;
  const indicators = {
    '?', ':', '-', ',', '[', ']', '{', '}', '&', '*',
    '!', '|', '>', "'", '"', '%', '@', '`',
  };
  if (indicators.contains(s[0])) return true;
  if (RegExp(r'^-?\d').hasMatch(s) && double.tryParse(s) != null) return true;
  return false;
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
