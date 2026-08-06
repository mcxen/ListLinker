import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/util/file_utils.dart';
import 'package:list_linker/util/string_utils.dart';
import 'package:list_linker/widget/smooth_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FileDetailsDialog extends StatelessWidget {
  const FileDetailsDialog({
    Key? key,
    required this.name,
    required this.size,
    required this.path,
    required this.modified,
    required this.thumb,
    required this.provider,
  }) : super(key: key);
  final String name;
  final String? size;
  final String path;
  final String modified;
  final String? thumb;
  final String? provider;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 30, 15, 10),
          child: _buildInfoColumn(),
        ));
  }

  Column _buildInfoColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInfoRow("${Intl.fileDetailsDialog_name.tr}:", name.orPlaceholder()),
        if (size.isUsable)
          _buildInfoRow("${Intl.fileDetailsDialog_size.tr}:", size.orPlaceholder()),
        _buildInfoRow("${Intl.fileDetailsDialog_where.tr}:", path.orPlaceholder()),
        _buildInfoRow("${Intl.fileDetailsDialog_modified.tr}:", modified.orPlaceholder()),
        if (provider.isUsable)
          _buildInfoRow("${Intl.fileDetailsDialog_provider.tr}:", provider.orPlaceholder()),
        if (thumb != null && thumb!.isNotEmpty)
          _buildThumb(thumb!, FileUtils.getFileIcon(false, name))
      ],
    );
  }

  Row _buildInfoRow(String text1, String text2) {
    return Row(
      children: [
        Container(
          alignment: Alignment.bottomRight,
          width: 80,
          child: Text(
            text1,
            style: Get.textTheme.bodyMedium
                ?.copyWith(color: Get.theme.colorScheme.outline),
          ),
        ),
        Expanded(
            child: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(text2),
        )),
      ],
    );
  }

  Widget _buildThumb(String thumb, String icon) {
    String thumbnail = FileUtils.getCompleteThumbnail(thumb)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SmoothNetworkImage(
        url: thumbnail,
        width: 200,
        height: 100,
        fit: BoxFit.cover,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        fallback: Image.asset(icon, width: 200, height: 100, fit: BoxFit.cover),
      ),
    );
  }
}
