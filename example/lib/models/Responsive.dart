/// SolidPod library to support privacy first data store on Solid Servers
///
// Time-stamp: <Wednesday 2025-09-17 09:19:35 +1000 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute ANU
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
/// Authors: AUTHORS

// Add the library directive as we have doc entries above. We publish the above
// meta doc lines in the docs.

library;

// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'package:solid_auth_example/models/Constants.dart';

// Widget to setup respostive designs
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  const Responsive({
    Key? key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  }) : super(key: key);

  static bool isMobile(BuildContext context) => screenWidth(context) < 650;

  static bool isTablet(BuildContext context) =>
      screenWidth(context) < 1100 && screenWidth(context) >= 650;

  static bool isDesktop(BuildContext context) => screenWidth(context) >= 1100;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        //If width is more than 1100 consider it as desktop
        if (constraints.maxWidth >= 1100) {
          return desktop;
        }
        //If width is in between 1100 and 650 consider it as tablet
        else if (constraints.maxWidth >= 650) {
          return tablet;
        }
        //If width is less than 650 consider it as mobile
        else {
          return mobile;
        }
      },
    );
  }
}
