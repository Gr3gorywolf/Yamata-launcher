import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/web_sources_manager_service.dart';

class WebSourcesManagerPage extends StatefulWidget {
  @override
  State<WebSourcesManagerPage> createState() => _WebSourcesManagerPageState();
}

class _WebSourcesManagerPageState extends State<WebSourcesManagerPage> {
  final server = WebSourcesManagerService();
  String? url;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() async {
    final u = await server.start();
    setState(() {
      url = u;
    });
  }

  @override
  void dispose() {
    server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Manage sources from an external device')),
      body: Center(
        child: url == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Scan this QR code with your external device to manage sources',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  QrImageView(
                    data: url!,
                    foregroundColor: Theme.of(context).colorScheme.onBackground,
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
                          AlertsService.showSnackbar('URL copied to clipboard');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Open this URL from your external device (must be on the same network)',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
