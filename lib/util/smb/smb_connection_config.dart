import 'dart:convert';

/// Saved SMB share connection (persisted as JSON in SpUtil).
class SmbConnectionConfig {
  SmbConnectionConfig({
    required this.id,
    required this.name,
    required this.host,
    this.port = 445,
    this.domain = '',
    required this.username,
    required this.password,
    this.share = '',
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String domain;
  final String username;
  final String password;

  /// Optional default share; empty means list all shares first.
  final String share;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'domain': domain,
        'username': username,
        'password': password,
        'share': share,
      };

  factory SmbConnectionConfig.fromJson(Map<String, dynamic> json) {
    return SmbConnectionConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 445,
      domain: json['domain'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      share: json['share'] as String? ?? '',
    );
  }

  static List<SmbConnectionConfig> listFromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SmbConnectionConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJsonString(List<SmbConnectionConfig> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }
}
