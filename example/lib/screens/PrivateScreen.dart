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

import 'package:solid_auth_example/models/Constants.dart';
// Project imports:
import 'package:solid_auth_example/models/Responsive.dart';
import 'package:solid_auth_example/screens/PrivateProfile.dart';

// ignore: must_be_immutable
class PrivateScreen extends StatelessWidget {
  Map authData; // Authentication data
  String webId; // User WebId
  PrivateScreen({Key? key, required this.authData, required this.webId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Assign loading screen
    var loadingScreen = PrivateProfile(authData: authData, webId: webId);

    // Setup Scaffold to be responsive
    return Scaffold(
        body: Responsive(
      mobile: loadingScreen,
      tablet: Row(
        children: [
          Expanded(
            flex: 10,
            child: loadingScreen,
          ),
        ],
      ),
      desktop: Row(
        children: [
          Expanded(
            flex: screenWidth(context) < 1300 ? 10 : 8,
            child: loadingScreen,
          ),
        ],
      ),
    ));
  }
}
