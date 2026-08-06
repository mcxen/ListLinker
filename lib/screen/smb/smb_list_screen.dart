import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:list_linker/util/smb/smb_connection_config.dart';
import 'package:list_linker/util/smb/smb_service.dart';
import 'package:list_linker/util/widget_utils.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// List of saved SMB connections.
class SmbListScreen extends StatelessWidget {
  const SmbListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final smb = Get.find<SmbService>();
    return AlistScaffold(
      appbarTitle: Text(Intl.screenName_smb.tr),
      appbarActions: [
        IconButton(
          onPressed: () => Get.toNamed(NamedRouter.smbScan),
          icon: const Icon(Icons.radar),
          tooltip: Intl.smb_scanTitle.tr,
        ),
        IconButton(
          onPressed: () => _showEditDialog(context, smb),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      body: Obx(() {
        if (smb.connections.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storage_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    Intl.smb_emptyHint.tr,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showEditDialog(context, smb),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(Intl.smb_addConnection.tr),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Get.toNamed(NamedRouter.smbScan),
                    icon: const Icon(Icons.radar),
                    label: Text(Intl.smb_scanTitle.tr),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: WidgetUtils.listViewPadding(context),
          itemCount: smb.connections.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = smb.connections[index];
            return ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text(item.name),
              subtitle: Text(
                item.share.isEmpty
                    ? '${item.host}${item.username.isEmpty ? '' : ' · ${item.username}'}'
                    : '\\\\${item.host}\\${item.share}',
              ),
              onTap: () => _open(context, smb, item),
              trailing: PopupMenuButton<String>(
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
      final startPath =
          config.share.isEmpty ? null : '/${config.share.replaceAll('\\', '/')}';
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
          title: Text(existing == null
              ? Intl.smb_addConnection.tr
              : Intl.smb_edit.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: Intl.smb_label_name.tr),
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: hostCtrl,
                  decoration: InputDecoration(labelText: Intl.smb_label_host.tr),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: portCtrl,
                  decoration: InputDecoration(labelText: Intl.smb_label_port.tr),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: shareCtrl,
                  decoration:
                      InputDecoration(labelText: Intl.smb_label_share.tr),
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: domainCtrl,
                  decoration:
                      InputDecoration(labelText: Intl.smb_label_domain.tr),
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: userCtrl,
                  decoration:
                      InputDecoration(labelText: Intl.smb_label_username.tr),
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: passCtrl,
                  decoration:
                      InputDecoration(labelText: Intl.smb_label_password.tr),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
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
    final name =
        nameCtrl.text.trim().isEmpty ? host : nameCtrl.text.trim();
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
