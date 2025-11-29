import 'package:flutter/foundation.dart';

void avoidPrint(String s) {
  if (kDebugMode) {
    print(s);
  }
}