import 'package:flutter/material.dart';
import 'package:list_linker/screen/smb/smb_browser_screen.dart';
import 'package:list_linker/screen/smb/smb_list_screen.dart';
import 'package:list_linker/util/smb/smb_connection_config.dart';

/// Keeps SMB navigation inside the main desktop content pane.
class SmbWorkspaceScreen extends StatefulWidget {
  const SmbWorkspaceScreen({super.key});

  @override
  State<SmbWorkspaceScreen> createState() => _SmbWorkspaceScreenState();
}

class _SmbWorkspaceScreenState extends State<SmbWorkspaceScreen> {
  SmbConnectionConfig? _connection;
  String _startPath = '';

  @override
  Widget build(BuildContext context) {
    final connection = _connection;
    if (connection == null) {
      return SmbListScreen(
        onOpenConnection: (config, startPath) {
          setState(() {
            _connection = config;
            _startPath = startPath;
          });
        },
      );
    }

    return SmbBrowserScreen(
      key: ValueKey(connection.id),
      embedded: true,
      initialPath: _startPath,
      connectionTitle: connection.name,
      onClose: () => setState(() => _connection = null),
    );
  }
}
