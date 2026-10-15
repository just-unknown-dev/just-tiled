/// Path arithmetic for the paths Tiled writes: always relative to the file
/// that holds them, with `/` (or, from Windows, `\`) between folders.
library;

/// [path] with `\` read as `/`, and `.`, `..` and empty segments collapsed.
/// A `..` that climbs above the start is kept; a leading `/` is dropped.
String normalizePath(String path) {
  final out = <String>[];
  for (final part in path.replaceAll('\\', '/').split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..' && out.isNotEmpty && out.last != '..') {
      out.removeLast();
    } else {
      out.add(part);
    }
  }
  return out.join('/');
}

/// [relative], written in [file], as a path from where [file]'s own path
/// starts: resolved against the folder [file] is in.
String resolveFrom(String file, String relative) {
  final normalized = file.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  return normalizePath(
    slash < 0 ? relative : '${normalized.substring(0, slash)}/$relative',
  );
}
