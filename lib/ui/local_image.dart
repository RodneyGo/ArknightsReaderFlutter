// Chooses between a downloaded copy and the network for an image URL.
//
// Every scene background, CG, sprite and avatar the reader shows goes through
// here so a downloaded chapter renders fully offline: if the URL has a saved
// file on disk (see Offline.localFile), load that; otherwise fall back to the
// network. Replaces the web build's localAsset()/convertFileSrc() branch.

import 'dart:io' show File;

import 'package:flutter/widgets.dart';

import '../data/offline.dart';

ImageProvider readerImage(String url, Offline? offline) {
  final path = offline?.localFile(url);
  return path != null ? FileImage(File(path)) : NetworkImage(url);
}
