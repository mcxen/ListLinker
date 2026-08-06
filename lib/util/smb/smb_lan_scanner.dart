import 'dart:async';
import 'dart:io';

/// Scan the local LAN for hosts with TCP port 445 open (likely SMB).
class SmbLanScanner {
  /// Discover candidate SMB hosts on the device's subnet(s).
  ///
  /// [onProgress] is called with scanned / total host counts.
  static Future<List<SmbLanHost>> scan({
    int port = 445,
    Duration timeout = const Duration(milliseconds: 350),
    int concurrency = 48,
    void Function(int scanned, int total)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final subnets = await _localSubnets();
    if (subnets.isEmpty) {
      return [];
    }

    final hosts = <String>{};
    for (final subnet in subnets) {
      for (var i = 1; i <= 254; i++) {
        hosts.add('${subnet.$1}.${subnet.$2}.${subnet.$3}.$i');
      }
    }
    // Prefer not scanning self last; order is fine as a set expansion.

    final list = hosts.toList();
    final total = list.length;
    final found = <SmbLanHost>[];
    var scanned = 0;
    var index = 0;

    Future<void> worker() async {
      while (true) {
        if (shouldCancel?.call() == true) return;
        final i = index;
        index++;
        if (i >= list.length) return;
        final ip = list[i];
        final open = await _probe(ip, port, timeout);
        scanned++;
        onProgress?.call(scanned, total);
        if (open) {
          found.add(SmbLanHost(ip: ip, port: port));
        }
      }
    }

    final workers = List.generate(
      concurrency.clamp(1, 64),
      (_) => worker(),
    );
    await Future.wait(workers);
    found.sort((a, b) => a.ip.compareTo(b.ip));
    return found;
  }

  static Future<bool> _probe(String host, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns distinct /24 prefixes as (a,b,c) for IPv4 interfaces.
  static Future<List<(int, int, int)>> _localSubnets() async {
    final result = <(int, int, int)>{};
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final a = int.tryParse(parts[0]);
          final b = int.tryParse(parts[1]);
          final c = int.tryParse(parts[2]);
          if (a == null || b == null || c == null) continue;
          // Skip some non-LAN ranges
          if (a == 127) continue;
          result.add((a, b, c));
        }
      }
    } catch (_) {}
    return result.toList();
  }
}

class SmbLanHost {
  SmbLanHost({required this.ip, required this.port});
  final String ip;
  final int port;
}
