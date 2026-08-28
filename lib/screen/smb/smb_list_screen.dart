import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:list_linker/util/smb/smb_connection_config.dart';
import 'package:list_linker/util/smb/smb_service.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
import 'package:list_linker/widget/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// List of saved SMB connections.
class SmbListScreen extends StatelessWidget {
  const SmbListScreen({super.key, this.onOpenConnection});

  final void Function(SmbConnectionConfig config, String startPath)?
      onOpenConnection;

  @override
  Widget build(BuildContext context) {
    final smb = Get.find<SmbService>();
    return AlistScaffold(
      appbarTitle: Text(Intl.screenName_smb.tr),
      appbarActions: [
        IconButton(
          onPressed: () => Get.toNamed(NamedRouter.smbScan),
          icon: const Icon(Icons.radar_rounded),
          tooltip: Intl.smb_scanTitle.tr,
        ),
        IconButton(
          onPressed: () => _showEditDialog(context, smb),
          icon: const Icon(Icons.add_rounded),
          tooltip: Intl.smb_addConnection.tr,
        ),
      ],
      body: Obx(() {
        if (smb.connections.isEmpty) {
          return ListView(
            padding: AppUi.pageInsets(context, top: 20),
            children: [
              AppEmptyState(
                expand: false,
                icon: Icons.dns_rounded,
                title: Intl.screenName_smb.tr,
                body: Intl.smb_emptyHint.tr,
                primaryAction: FilledButton.icon(
                  onPressed: () => _showEditDialog(context, smb),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(Intl.smb_addConnection.tr),
                ),
                secondaryAction: OutlinedButton.icon(
                  onPressed: () => Get.toNamed(NamedRouter.smbScan),
                  icon: const Icon(Icons.radar_rounded),
                  label: Text(Intl.smb_scanTitle.tr),
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: EdgeInsets.only(
            top: 8,
            bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          itemCount: smb.connections.length,
          separatorBuilder: (_, __) => const AppInsetDivider(),
          itemBuilder: (context, index) {
            final item = smb.connections[index];
            final subtitle = item.share.isEmpty
                ? [
                    item.host,
                    if (item.username.isNotEmpty) item.username,
                  ].join(' · ')
                : '\\\\${item.host}\\${item.share}';
            return AppListTile(
              leadingIcon: Icons.storage_rounded,
              title: item.name,
              subtitle: subtitle,
              showChevron: true,
              onTap: () => _open(context, smb, item),
              trailing: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _showEditDialog(context, smb, existing: item);
                  } else if (value == 'delete') {
                    await smb.deleteConnection(item.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(Intl.smb_edit.tr),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(Intl.smb_delete.tr),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  Future<void> _open(
    BuildContext context,
    SmbService smb,
    SmbConnectionConfig config,
  ) async {
    SmartDialog.showLoading();
    try {
      await smb.connect(config);
      SmartDialog.dismiss();
      final startPath = config.share.isEmpty
          ? null
          : '/${config.share.replaceAll('\\', '/')}';
      if (onOpenConnection != null) {
        onOpenConnection!(config, startPath ?? '');
        return;
      }
      Get.toNamed(
        NamedRouter.smbBrowser,
        arguments: {
          'title': config.name,
          'path': startPath ?? '',
        },
      );
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('${Intl.smb_connectFailed.tr}: $e');
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    SmbService smb, {
    SmbConnectionConfig? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final hostCtrl = TextEditingController(text: existing?.host ?? '');
    final portCtrl =
        TextEditingController(text: (existing?.port ?? 445).toString());
    final domainCtrl = TextEditingController(text: existing?.domain ?? '');
    final userCtrl = TextEditingController(text: existing?.username ?? '');
    final passCtrl = TextEditingController(text: existing?.password ?? '');
    final shareCtrl = TextEditingController(text: existing?.share ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            existing == null ? Intl.smb_addConnection.tr : Intl.smb_edit.tr,
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppFormField(
                    controller: nameCtrl,
                    label: Intl.smb_label_name.tr,
                  ),
                  AppFormField(
                    controller: hostCtrl,
                    label: Intl.smb_label_host.tr,
                    keyboardType: TextInputType.url,
                  ),
                  AppFormField(
                    controller: portCtrl,
                    label: Intl.smb_label_port.tr,
                    keyboardType: TextInputType.number,
                  ),
                  AppFormField(
                    controller: shareCtrl,
                    label: Intl.smb_label_share.tr,
                  ),
                  AppFormField(
                    controller: domainCtrl,
                    label: Intl.smb_label_domain.tr,
                  ),
                  AppFormField(
                    controller: userCtrl,
                    label: Intl.smb_label_username.tr,
                  ),
                  AppFormField(
                    controller: passCtrl,
                    label: Intl.smb_label_password.tr,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Intl.smb_cancel.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Intl.smb_save.tr),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    final host = hostCtrl.text.trim();
    if (host.isEmpty) {
      SmartDialog.showToast(Intl.smb_hostRequired.tr);
      return;
    }
    final name = nameCtrl.text.trim().isEmpty ? host : nameCtrl.text.trim();
    final port = int.tryParse(portCtrl.text.trim()) ?? 445;
    final config = existing == null
        ? SmbService.newConfig(
            name: name,
            host: host,
            port: port,
            domain: domainCtrl.text.trim(),
            username: userCtrl.text.trim(),
            password: passCtrl.text,
            share: shareCtrl.text.trim().replaceAll('\\', '/'),
          )
        : SmbConnectionConfig(
            id: existing.id,
            name: name,
            host: host,
            port: port,
            domain: domainCtrl.text.trim(),
            username: userCtrl.text.trim(),
            password: passCtrl.text,
            share: shareCtrl.text.trim().replaceAll('\\', '/'),
          );
    await smb.upsertConnection(config);
  }
}
