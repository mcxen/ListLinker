import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/util/smb/smb_lan_scanner.dart';
import 'package:list_linker/util/smb/smb_service.dart';
import 'package:list_linker/util/widget_utils.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
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
    return AlistScaffold(
      appbarTitle: Text(Intl.smb_scanTitle.tr),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              Intl.smb_scanHint.tr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (_scanning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  LinearProgressIndicator(value: progress == 0 ? null : progress),
                  const SizedBox(height: 8),
                  Text('$_scanned / $_total'),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _scanning ? null : _startScan,
                    icon: const Icon(Icons.radar),
                    label: Text(Intl.smb_startScan.tr),
                  ),
                ),
                if (_scanning) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => _cancel = true,
                    child: Text(Intl.smb_cancel.tr),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _hosts.isEmpty
                ? Center(
                    child: Text(
                      _scanning
                          ? Intl.smb_scanning.tr
                          : Intl.smb_scanEmpty.tr,
                    ),
                  )
                : ListView.separated(
                    padding: WidgetUtils.listViewPadding(context),
                    itemCount: _hosts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final host = _hosts[index];
                      return ListTile(
                        leading: const Icon(Icons.computer_outlined),
                        title: Text(host.ip),
                        subtitle: Text('SMB :${host.port}'),
                        trailing: TextButton(
                          onPressed: () => _addHost(host),
                          child: Text(Intl.smb_addConnection.tr),
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
          title: Text(Intl.smb_addConnection.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      InputDecoration(labelText: Intl.smb_label_name.tr),
                ),
                Text('${Intl.smb_label_host.tr}: ${host.ip}'),
                TextField(
                  controller: shareCtrl,
                  decoration:
                      InputDecoration(labelText: Intl.smb_label_share.tr),
                ),
                TextField(
                  controller: domainCtrl,
                  decoration:
                      InputDecoration(labelText: Intl.smb_label_domain.tr),
                ),
                TextField(
                  controller: userCtrl,
                  decoration:
                      InputDecoration(labelText: Intl.smb_label_username.tr),
                ),
                TextField(
                  controller: passCtrl,
                  decoration:
                      InputDecoration(labelText: Intl.smb_label_password.tr),
                  obscureText: true,
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
