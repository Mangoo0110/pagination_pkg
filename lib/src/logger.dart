
import 'package:flutter/foundation.dart';

class Logger {
  const Logger({this.log = false, this.loggerColor = LoggerColor.white});
  final bool log;
  final LoggerColor loggerColor;

  void showLog(String message) {
    if (log) {
      debugPrint('\x1B[${loggerColor.value}m$message\x1B[0m');
    }
  }
}

enum LoggerColor {
  red(31),
  green(32),
  yellow(33),
  blue(34),
  magenta(35),
  cyan(36),
  white(37);

  final int value;
  const LoggerColor(this.value);
}