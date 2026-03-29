import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:yamata_launcher/models/emulator.dart';

class EmulatorListItem extends StatefulWidget {
  Emulator emulator;
  EmulatorListItem(this.emulator);

  @override
  _EmulatorListItemState createState() => _EmulatorListItemState();
}

class _EmulatorListItemState extends State<EmulatorListItem> {
  bool isFetchingAvailability = false;
  bool isEmulatorAvailable = false;
  late Timer _timer;
  @override
  void initState() {
    super.initState();
    checkAvailability();
    _timer = Timer.periodic(Duration(seconds: 5), (timer) async {
      checkAvailability();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  checkAvailability() async {
    var result =
        await FlutterDeviceApps.getApp(widget.emulator.packageName!) != null;
    setState(() {
      isEmulatorAvailable = result;
    });
  }

  String get emulatorTag {
    var compatibility =
        widget.emulator.isCompatible! ? "Compatible" : "Incompatible";
    var availability = isEmulatorAvailable ? "Installed" : "Not installed";
    return "$compatibility - $availability";
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {},
      contentPadding: EdgeInsets.all(5),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.network(
          widget.emulator.image!,
          height: 50,
          width: 50,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(
        widget.emulator.name!,
        style: TextStyle(color: Colors.white),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 2,
          ),
          Text(
            isFetchingAvailability ? "Checking availability..." : emulatorTag,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
