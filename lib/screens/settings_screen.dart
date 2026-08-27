import 'package:flutter/material.dart';

import '../services/game_connection_service.dart';

/// Settings screen — currently just hosts the game-PC host/IP input that
/// used to live on the home screen, plus connect/disconnect controls.
/// Reads and drives the same [GameConnectionService] instance the home
/// screen uses, so connecting here immediately switches the home screen
/// from the idle screen to the companion screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.connection});

  final GameConnectionService connection;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _hostController;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.connection.host ?? '');
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  void _connect() {
    final host = _hostController.text.trim();
    if (host.isNotEmpty) {
      widget.connection.connect(host);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.connection,
          builder: (context, _) {
            final connection = widget.connection;
            final status = connection.status;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Settings Screen'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Game PC host or IP',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _connect(),
                  ),
                  const SizedBox(height: 12),
                  Text('Status: ${status.name}'),
                  if (connection.lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      connection.lastError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _connect,
                          child: const Text('Connect'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: status == ConnectionStatus.disconnected
                              ? null
                              : connection.disconnect,
                          child: const Text('Disconnect'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
