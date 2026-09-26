import 'package:intl/intl.dart';

extension HumanizedNumber on num {
  String humanizedCount({int? decimalDigits}) {
    return NumberFormat.decimalPatternDigits(
      decimalDigits: decimalDigits,
    ).format(this);
  }

  String humanizedCompact() {
    return NumberFormat.compact().format(this);
  }
}
