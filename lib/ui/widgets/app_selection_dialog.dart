import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppSelectionDialog extends StatefulWidget {
  final List<String> filteredApps;
  AppSelectionDialog({super.key, this.filteredApps = const []});

  static Future<AppInfo?> show(BuildContext context,
      {List<String> filteredApps = const []}) {
    return showDialog<AppInfo>(
        context: context,
        builder: (_) {
          return AppSelectionDialog(filteredApps: filteredApps);
        });
  }

  @override
  State<AppSelectionDialog> createState() => _AppSelectionDialogState();
}

class _AppSelectionDialogState extends State<AppSelectionDialog> {
  var installedApps = [];
  var isLoading = false;
  var showAllApps = true;
  var controller = TextEditingController();
  var query = '';

  fetchInstalledApps() async {
    setState(() {
      isLoading = true;
    });
    var apps = await FlutterDeviceApps.listApps(
      includeIcons: true,
      onlyLaunchable: true,
      includeSystem: false,
    );
    setState(() {
      installedApps = apps;
      isLoading = false;
    });
  }

  List<AppInfo> get filteredApps {
    var apps = showAllApps
        ? installedApps
        : installedApps.where((app) {
            return widget.filteredApps.contains((app as AppInfo).packageName);
          }).toList();
    return apps
        .where((app) {
          final appName = (app as AppInfo).appName;
          return appName?.toLowerCase().contains(query.toLowerCase()) ?? false;
        })
        .cast<AppInfo>()
        .toList();
  }

  @override
  void initState() {
    showAllApps = widget.filteredApps.isEmpty;
    fetchInstalledApps();
    super.initState();
  }

  buildLoadContent() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text('App Selection'),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        contentPadding: const EdgeInsets.all(10.0),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: isLoading
              ? buildLoadContent()
              : Column(
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Search Apps',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          query = value;
                        });
                      },
                    ),
                    CheckboxListTile(
                        value: showAllApps,
                        onChanged: (value) {
                          setState(() {
                            showAllApps = value ?? false;
                          });
                        },
                        title: Text("Show All Apps")),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredApps.length,
                        itemBuilder: (context, i) {
                          final app = filteredApps[i] as AppInfo;

                          return ListTile(
                            leading: app.iconBytes != null
                                ? Image.memory(app.iconBytes!,
                                    width: 32, height: 32)
                                : null,
                            title: Text(app.appName ?? ""),
                            subtitle: Text(app.packageName ?? ""),
                            onTap: () => Navigator.pop(context, app),
                          );
                        },
                      ),
                    )
                  ],
                ),
        ));
  }
}
