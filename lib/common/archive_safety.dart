import 'package:path/path.dart' as p;

/// Resolves an untrusted archive entry name against [rootDir], guarding against
/// Zip-Slip (path-traversal) attacks.
///
/// The entry name originates from a backup ZIP and is fully attacker
/// controlled. A crafted name such as `../../evil` or `/etc/passwd` would
/// otherwise let `File.create` write outside the intended profiles directory.
///
/// Returns the joined + normalized absolute path **only** when the resolved
/// location stays strictly inside [rootDir]. Returns `null` (caller must skip
/// the entry) for:
/// * empty / whitespace-only names,
/// * absolute entry names,
/// * names whose `..` segments escape [rootDir],
/// * names that resolve to [rootDir] itself (no file to write).
String? safeArchivePath(String rootDir, String entryName) {
  if (entryName.trim().isEmpty) return null;
  // Absolute entries (`/abs/path`, `C:\...`) must never be honored: joining
  // discards [rootDir] entirely, so they would escape unconditionally.
  if (p.isAbsolute(entryName)) return null;
  final normalizedRoot = p.normalize(rootDir);
  final candidate = p.normalize(p.join(normalizedRoot, entryName));
  // `isWithin` is false when candidate == root, which correctly rejects `.`
  // and `..`-only entries as well as any escape above root.
  if (!p.isWithin(normalizedRoot, candidate)) return null;
  return candidate;
}
