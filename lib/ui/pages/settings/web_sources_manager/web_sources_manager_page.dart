import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/web-manager/web_manager_server.dart';

class WebManagerPage extends StatefulWidget {
  @override
  State<WebManagerPage> createState() => _WebManagerPageState();
}

class _WebManagerPageState extends State<WebManagerPage> {
  final server = WebManagerServer();
  String? url;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() async {
    try {
      final u = await server.start();
      setState(() {
        url = u;
      });
    } catch (e) {
      AlertsService.showErrorSnackbar(
        'Failed to start web server. Make sure port ${server.port} is not being used by another application and try again. error: $e',
      );
      return;
    }
  }

  @override
  void dispose() {
    server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Manager')),
      body: Center(
        child: SingleChildScrollView(
          child: url == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Scan this QR code with your external device to manage sources, cookies and integrations',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    QrImageView(
                      data: url!,
                      foregroundColor:
                          Theme.of(context).colorScheme.onBackground,
                      size: 220,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Or ',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SelectableText(
                          url!,
                          style: const TextStyle(fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: url!));
                            AlertsService.showSnackbar(
                                'URL copied to clipboard');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Open this URL from your external device (must be on the same network)',
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      'Dont close this page while managing sources, cookies or integrations or the connection will be lost',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
