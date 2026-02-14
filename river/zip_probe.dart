import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final file = File(r'd:/Projects/river/miniapp_local_server/packages/official.react_starter_demo.zip');
  final bytes = file.readAsBytesSync();
  print('bytes=${bytes.length}');
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  print('entries=${archive.length} isEmpty=${archive.isEmpty}');
  for (final e in archive.take(8)) {
    print('${e.name} file=${e.isFile}');
  }
}
