

library;

import 'package:flutter/foundation.dart';

const kSystemRobotoFamily = 'Roboto';

const kBundledRobotoFamily = 'RobotoStatic';

String get appFontFamily => defaultTargetPlatform == TargetPlatform.iOS
    ? kBundledRobotoFamily
    : kSystemRobotoFamily;
