import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/localstore.dart';
import 'package:ak_reader/data/offline.dart';
import 'package:ak_reader/data/resolved.dart';
import 'package:ak_reader/stores/kv_store.dart';
import 'package:ak_reader/ui/local_image.dart';

void main() {
  group('readerImage', () {
    test('null offline -> network', () {
      expect(readerImage('http://x/a.png', null), isA<NetworkImage>());
    });

    test('offline with no local copy -> network', () {
      final off = Offline(
          store: null, resolved: ResolvedUrls(MemoryKeyValueStore()));
      expect(readerImage('http://x/a.png', off), isA<NetworkImage>());
    });

    test('a downloaded url -> file, un-downloaded -> network', () async {
      final tmp = await Directory.systemTemp.createTemp('ak_localimg');
      addTearDown(() => tmp.delete(recursive: true));
      final store = LocalStore(
        Directory('${tmp.path}/offline'),
        fetcher: (url) async => Uint8List.fromList(utf8.encode('bytes:$url')),
      );
      await store.init();
      final saved = await store.resolveAndSave(['http://x/a.png']);
      final off = Offline(
          store: store, resolved: ResolvedUrls(MemoryKeyValueStore()));

      expect(readerImage(saved!, off), isA<FileImage>());
      expect(readerImage('http://x/never.png', off), isA<NetworkImage>());
    });
  });
}
