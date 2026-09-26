import 'package:flutter/cupertino.dart';
import 'package:list_linker/util/haptics_helper.dart';

class AlistCheckBox extends StatelessWidget {
  final bool? value;
  final String text;
  final ValueChanged<bool?>? onChanged;

  const AlistCheckBox({
    super.key,
    required this.value,
    required this.text,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    void handleChanged(bool? nextValue) {
      HapticsHelper.soft();
      onChanged?.call(nextValue);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoCheckbox(
          value: value,
          // materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: onChanged == null ? null : handleChanged,
        ),
        GestureDetector(
          onTap: onChanged == null
              ? null
              : () {
                  handleChanged(!(value ?? false));
                },
          child: Text(text),
        ),
      ],
    );
  }
}
