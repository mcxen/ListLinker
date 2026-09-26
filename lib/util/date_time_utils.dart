import 'package:intl/intl.dart';

extension DateTimeDisplayX on DateTime? {
  String formattedDateTime(String localeName) {
    if (this == null) return 'N/A';
    return DateFormat(
      'd MMMM yyyy, HH:mm',
      localeName,
    ).format(this!.toLocal());
  }
}
