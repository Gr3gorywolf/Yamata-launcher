import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppSelectionDialog extends StatefulWidget {
  final List<String> filteredApps;
  AppSelectionDialog({super.key, this.filteredApps = const []});

  static Future<ApplicationWithIcon?> show(BuildContext context,
      {List<String> filteredApps = const []}) {
    return showDialog<ApplicationWithIcon>(
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
    var apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: false,
      onlyAppsWithLaunchIntent: true,
    );
    setState(() {
      installedApps = apps;
      isLoading = false;
    });
  }

  List<ApplicationWithIcon> get filteredApps {
    var apps = showAllApps
        ? installedApps
        : installedApps.where((app) {
            return widget.filteredApps
                .contains((app as ApplicationWithIcon).packageName);
          }).toList();
    return apps
        .where((app) {
          final appName = (app as ApplicationWithIcon).appName;
          return appName.toLowerCase().contains(query.toLowerCase());
        })
        .cast<ApplicationWithIcon>()
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
                          final app = filteredApps[i];

                          return ListTile(
                            leading:
                                Image.memory(app.icon, width: 32, height: 32),
                            title: Text(app.appName),
                            subtitle: Text(app.packageName),
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
