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

/// Returns the 0-based index of the proxy-group named [name] in the parsed
/// document's `proxy-groups` list, or `null` if absent.
int? findGroupIndex(Object? parsed, String name) {
  if (parsed is! Map) return null;
  final groups = parsed['proxy-groups'];
  if (groups is! List) return null;
  for (var i = 0; i < groups.length; i++) {
    final g = groups[i];
    if (g is Map && g['name']?.toString() == name) return i;
  }
  return null;
}

/// Appends [itemText] (already rendered as one or more block-list items at the
/// correct indentation) to the end of the top-level [key] block in [yaml].
///
/// The block ends at the first subsequent line that begins a new top-level key
/// (column 0, `something:`) or at end of file. Insertion happens immediately
/// before any trailing blank lines / comments that separate this block from the
/// next, so the new items sit inside the block. This preserves the original
/// text verbatim everywhere else.
String appendToTopLevelBlock(String yaml, String key, String itemText) {
  final lines = yaml.split('\n');
  var keyLine = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i] == '$key:' || lines[i].startsWith('$key:')) {
      // Top-level key: no leading whitespace.
      if (!lines[i].startsWith(' ') && !lines[i].startsWith('\t')) {
        keyLine = i;
        break;
      }
    }
  }
  if (keyLine == -1) {
    // Key not present at top level — append a fresh block at end of document.
    final buf = StringBuffer(yaml);
    if (!yaml.endsWith('\n')) buf.write('\n');
    buf
      ..write('$key:\n')
      ..write(itemText);
    return buf.toString();
  }

  // Find the end of this block: first later line that is a new top-level key.
  var blockEnd = lines.length; // exclusive
  for (var i = keyLine + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty) continue;
    final isIndented = line.startsWith(' ') || line.startsWith('\t');
    final isComment = line.trimLeft().startsWith('#');
    if (!isIndented && !isComment) {
      blockEnd = i;
      break;
    }
  }

  // Back up over trailing blank lines so the new items join the block body.
  var insertAt = blockEnd;
  while (insertAt - 1 > keyLine && lines[insertAt - 1].trim().isEmpty) {
    insertAt--;
  }

  final itemLines = itemText.split('\n');
  // emitListItemMap ends with a trailing newline → drop the empty tail.
  if (itemLines.isNotEmpty && itemLines.last.isEmpty) {
    itemLines.removeLast();
  }
  lines.insertAll(insertAt, itemLines);
  return lines.join('\n');
}

/// Renders [map] as a single YAML block-list item (`- key: value` ...), with
/// each line prefixed by [indent]. The first key is emitted on the `- ` line;
/// subsequent keys align under it. Returns text terminated by a newline.
String emitListItemMap(Map<String, Object> map, String indent) {
  final buf = StringBuffer();
  final entries = map.entries.toList();
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final prefix = i == 0 ? '$indent- ' : '$indent  ';
    _emitField(buf, entry.key, entry.value, prefix, '$indent    ');
  }
  return buf.toString();
}

/// Emits a single `key: value` (or nested) field. [linePrefix] is written
/// before the key; [childIndent] is the indentation for nested map/list bodies.
void _emitField(
  StringBuffer buf,
  String key,
  Object value,
  String linePrefix,
  String childIndent,
) {
  if (value is Map) {
    buf.writeln('$linePrefix$key:');
    value.forEach((k, v) {
      _emitField(buf, k.toString(), v as Object, childIndent, '$childIndent  ');
    });
  } else if (value is List) {
    buf.writeln('$linePrefix$key:');
    for (final item in value) {
      // Numeric / bool list items must stay bare so they parse as numbers /
      // booleans, not strings; everything else is quoted conservatively like a
      // proxy name.
      final rendered = (item is bool || item is int || item is double)
          ? '$item'
          : yamlScalar(item.toString());
      buf.writeln('$childIndent- $rendered');
    }
  } else if (value is bool || value is int || value is double) {
    buf.writeln('$linePrefix$key: $value');
  } else {
    buf.writeln('$linePrefix$key: ${yamlScalar(value.toString())}');
  }
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
