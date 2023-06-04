import 'dart:io';

import 'package:wakelock/wakelock.dart';

class WakelockService {
  static void keepAlive() {
    if (!Platform.isLinux) {
      Wakelock.enable();
    }
  }
}