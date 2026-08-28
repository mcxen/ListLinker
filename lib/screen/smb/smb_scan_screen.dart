import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/util/smb/smb_lan_scanner.dart';
import 'package:list_linker/util/smb/smb_service.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
import 'package:list_linker/widget/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// Scan LAN for open SMB ports and add connections.
class SmbScanScreen extends StatefulWidget {
  const SmbScanScreen({super.key});

  @override
  State<SmbScanScreen> createState() => _SmbScanScreenState();
}

class _SmbScanScreenState extends State<SmbScanScreen> {
  bool _scanning = false;
  bool _cancel = false;
  int _scanned = 0;
  int _total = 0;
  List<SmbLanHost> _hosts = [];

  @override
  void dispose() {
    _cancel = true;
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _cancel = false;
      _scanned = 0;
      _total = 0;
      _hosts = [];
    });
    try {
      final found = await SmbLanScanner.scan(
        shouldCancel: () => _cancel,
        onProgress: (s, t) {
          if (!mounted) return;
          setState(() {
            _scanned = s;
            _total = t;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _hosts = found;
        _scanning = false;
      });
      if (found.isEmpty) {
        SmartDialog.showToast(Intl.smb_scanNoHosts.tr);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      SmartDialog.showToast('${Intl.smb_scanFailed.tr}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? 0.0 : _scanned / _total;
    final scheme = Theme.of(context).colorScheme;

    return AlistScaffold(
      appbarTitle: Text(Intl.smb_scanTitle.tr),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(0.45),
                borderRadius: BorderRadius.circular(AppUi.radius),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      Intl.smb_scanHint.tr,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_scanning)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: progress == 0 ? null : progress,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_scanned / $_total',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppUi.muted(context),
                        ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _scanning ? null : _startScan,
                    icon: const Icon(Icons.radar_rounded),
                    label: Text(Intl.smb_startScan.tr),
                  ),
                ),
                if (_scanning) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => _cancel = true,
                    child: Text(Intl.smb_cancel.tr),
                  ),
                ],
              ],
            ),
          ),
          const AppInsetDivider(),
          Expanded(
            child: _hosts.isEmpty
                ? AppEmptyState(
                    icon: _scanning
                        ? Icons.wifi_find_rounded
                        : Icons.lan_outlined,
                    title: _scanning
                        ? Intl.smb_scanning.tr
                        : Intl.smb_scanEmpty.tr,
                    body: _scanning ? null : Intl.smb_scanHint.tr,
                  )
                : ListView.separated(
                    padding: EdgeInsets.only(
                      top: 4,
                      bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    itemCount: _hosts.length,
                    separatorBuilder: (_, __) => const AppInsetDivider(),
                    itemBuilder: (context, index) {
                      final host = _hosts[index];
                      return AppListTile(
                        leadingIcon: Icons.computer_rounded,
                        title: host.ip,
                        subtitle: 'SMB · :${host.port}',
                        trailing: FilledButton.tonal(
                          onPressed: () => _addHost(host),
                          child: Text(Intl.smb_add.tr),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addHost(SmbLanHost host) async {
    final smb = Get.find<SmbService>();
    final nameCtrl = TextEditingController(text: host.ip);
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final shareCtrl = TextEditingController();
    final domainCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(Intl.smb_addConnection.tr),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${Intl.smb_label_host.tr}: ${host.ip}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppUi.muted(context),
                            ),
                      ),
                    ),
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

    final config = SmbService.newConfig(
      name: nameCtrl.text.trim().isEmpty ? host.ip : nameCtrl.text.trim(),
      host: host.ip,
      port: host.port,
      domain: domainCtrl.text.trim(),
      username: userCtrl.text.trim(),
      password: passCtrl.text,
      share: shareCtrl.text.trim().replaceAll('\\', '/'),
    );
    await smb.upsertConnection(config);
    SmartDialog.showToast(Intl.smb_saved.tr);
    if (mounted) Get.back();
  }
}
