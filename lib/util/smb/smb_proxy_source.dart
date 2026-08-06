import 'dart:io';

import 'package:smb_connect/smb_connect.dart';

/// Source registered with [ProxyServer] for Range-based SMB streaming.
class SmbProxySource {
  SmbProxySource({required this.connect, required this.file});

  final SmbConnect connect;
  final SmbFile file;

  Future<int> length() async {
    final size = file.size;
    if (size > 0) return size;
    final raf = await connect.open(file);
    try {
      return await raf.length();
    } finally {
      await raf.close();
    }
  }

  Future<void> writeRange(HttpResponse response, int start, int end) async {
    final raf = await connect.open(file);
    try {
      await raf.setPosition(start);
      var remaining = end - start + 1;
      const chunk = 64 * 1024;
      while (remaining > 0) {
        final n = remaining > chunk ? chunk : remaining;
        final data = await raf.read(n);
        if (data.isEmpty) break;
        response.add(data);
        remaining -= data.length;
      }
      await response.close();
    } catch (e) {
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {}
    } finally {
      await raf.close();
    }
  }

  Future<void> writeAll(HttpResponse response) async {
    final stream = await connect.openRead(file);
    await for (final event in stream) {
      response.add(event);
    }
    await response.close();
  }
}
