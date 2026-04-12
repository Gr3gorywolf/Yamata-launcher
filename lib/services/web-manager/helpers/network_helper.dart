import 'dart:io';

Future<String> getLocalIpAddress() async {
  for (final interface in await NetworkInterface.list()) {
    for (final address in interface.addresses) {
      if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
        return address.address;
      }
    }
  }

  return 'localhost';
}
