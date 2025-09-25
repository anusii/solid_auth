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

// Package imports:
import 'package:solid_auth/solid_auth.dart';

// Project imports:
import 'package:solid_auth_example/models/Constants.dart';
import 'package:solid_auth_example/models/Responsive.dart';
import 'package:solid_auth_example/screens/LoginScreen.dart';

// Widget for the top horizontal bar
// ignore: must_be_immutable
class Header extends StatelessWidget {
  var mainDrawer;
  String logoutUrl;
  Header({
    Key? key,
    required this.mainDrawer,
    required this.logoutUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: lightGold,
      child: Padding(
        padding: const EdgeInsets.all(kDefaultPadding / 1.5),
        child: Row(
          children: [
            if (Responsive.isMobile(context) & (logoutUrl != 'none'))
              IconButton(onPressed: () {}, icon: Icon(Icons.menu)),
            if (!Responsive.isDesktop(context)) SizedBox(width: 5),
            Spacer(),
            if (!Responsive.isDesktop(context)) SizedBox(width: 5),
            SizedBox(width: kDefaultPadding / 4),
            if (logoutUrl != 'none') SizedBox(width: kDefaultPadding / 4),
            (logoutUrl != 'none')
                ? TextButton.icon(
                    icon: Icon(
                      Icons.logout,
                      color: Colors.black,
                      size: 24.0,
                    ),
                    label: Text(
                      'LOGOUT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    onPressed: () {
                      logout(logoutUrl);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                  )
                : IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      size: 24.0,
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                  ),
            SizedBox(width: kDefaultPadding / 4),
          ],
        ),
      ),
    );
  }
}
