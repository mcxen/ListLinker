
import 'dart:convert';
import 'package:crypto/crypto.dart';

extension StringExtensions on String? {
  /// Display-safe text for API-backed strings.
  /// Covers null, the literal "null", and empty/whitespace-only values.
  String orPlaceholder([String placeholder = '-']) {
    if (this == null) return placeholder;
    final value = this!.trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return placeholder;
    return value;
  }

  bool get isUsable {
    if (this == null) return false;
    final value = this!.trim();
    return value.isNotEmpty && value.toLowerCase() != 'null';
  }

  String? substringAfterLast(String separator) {
    if (this == null) {
      return null;
    }

    final index = this!.lastIndexOf(separator);
    if (index == -1) {
      return this;
    }
    return this!.substring(index + separator.length);
  }

  String? substringBeforeLast(String separator) {
    if (this == null) {
      return null;
    }

    final index = this!.lastIndexOf(separator);
    if (index == -1) {
      return this;
    }
    return this!.substring(0, index);
  }

  String md5String(){
    var bytes = utf8.encode(this ?? "");
    var md5Hash = md5.convert(bytes);
    String md5String = md5Hash.toString();
    return md5String;
  }
}
