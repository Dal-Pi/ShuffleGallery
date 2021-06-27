import 'dart:io';
import 'dart:math';

import 'package:permission_handler/permission_handler.dart';

Future<bool> promptPermissionSetting() async {
  if (Platform.isIOS &&
      await Permission.storage.request().isGranted &&
      await Permission.photos.request().isGranted ||
      Platform.isAndroid && await Permission.storage.request().isGranted) {
    return true;
  }
  return false;
}

List<T> shuffle<T>(List<T> items) {
  var random = new Random();

  // Go through all elements.
  for (var i = items.length - 1; i > 0; i--) {
    // Pick a pseudorandom number according to the list length
    var n = random.nextInt(i + 1);

    var temp = items[i];
    items[i] = items[n];
    items[n] = temp;
  }

  return items;
}