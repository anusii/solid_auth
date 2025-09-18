/// Platform information
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the MIT License (the "License").
///
/// License: https://choosealicense.com/licenses/mit/.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
///
/// Authors: Anushka Vidanage

// Dart imports:
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

// Class to return platform information
class PlatformInfo {
  bool isDesktopOS() {
    return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  }

  bool isAppOS() {
    return Platform.isIOS || Platform.isAndroid;
  }

  bool isWeb() {
    return kIsWeb;
  }

  PlatformType getCurrentPlatformType() {
    if (kIsWeb) {
      return PlatformType.Web;
    }
    if (Platform.isMacOS) {
      return PlatformType.MacOS;
    }
    if (Platform.isFuchsia) {
      return PlatformType.Fuchsia;
    }
    if (Platform.isLinux) {
      return PlatformType.Linux;
    }
    if (Platform.isWindows) {
      return PlatformType.Windows;
    }
    if (Platform.isIOS) {
      return PlatformType.iOS;
    }
    if (Platform.isAndroid) {
      return PlatformType.Android;
    }
    return PlatformType.Unknown;
  }
}

enum PlatformType { Web, iOS, Android, MacOS, Fuchsia, Linux, Windows, Unknown }
