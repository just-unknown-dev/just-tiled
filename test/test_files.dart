// File providers for the tests: the fixtures folder, and files in memory.

import 'dart:io';

import 'package:just_tiled/just_tiled.dart';

/// The folder of Tiled files the tests read.
const fixtures = 'test/fixtures';

/// Reads external tilesets and templates from a folder, by the path the
/// map writes.
class FolderFiles implements TiledFileProvider {
  /// Files under [base].
  FolderFiles([this.base = fixtures]);

  /// The folder paths are read from.
  final String base;

  @override
  Future<String> loadTileset(String source) =>
      File('$base/$source').readAsString();

  @override
  Future<String> loadTemplate(String source) =>
      File('$base/$source').readAsString();
}

/// Files by path, as the map writes it; [asked] lists every load.
class MemoryFiles implements TiledFileProvider {
  /// The files [files], by path.
  MemoryFiles(this.files);

  /// The files, by path.
  final Map<String, String> files;

  /// Every path loaded, in order.
  final asked = <String>[];

  @override
  Future<String> loadTileset(String source) async => _load(source);

  @override
  Future<String> loadTemplate(String source) async => _load(source);

  String _load(String source) {
    asked.add(source);
    final text = files[source];
    if (text == null) throw FileSystemException('no such file', source);
    return text;
  }
}

/// A fixture's text.
String fixture(String name) => File('$fixtures/$name').readAsStringSync();
