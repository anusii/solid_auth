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
import 'package:solid_auth_example/screens/EditProfile.dart';

class ProfileInfo extends StatelessWidget {
  final Map profData; // Profile data
  final Map? authData; // Authentication related data
  final String profType; // Public or private
  final String? webId; // WebId of the user

  const ProfileInfo(
      {Key? key,
      required this.profData,
      required this.profType,
      this.authData,
      this.webId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                        border: Border.all(
                          width: 4,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        boxShadow: [
                          BoxShadow(
                              spreadRadius: 2,
                              blurRadius: 10,
                              color: Colors.black.withValues(alpha: 0.1),
                              offset: Offset(0, 10))
                        ],
                        shape: BoxShape.circle,
                        image: DecorationImage(
                            fit: BoxFit.cover,
                            image: NetworkImage(profData['picUrl']))),
                  ),
                  if (profType == 'private')
                    Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          height: 45,
                          width: 45,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: 3,
                              color: Theme.of(context).scaffoldBackgroundColor,
                            ),
                            color: darkCopper,
                          ),
                          child: IconButton(
                            icon: new Icon(Icons.edit),
                            color: Colors.white,
                            onPressed: () {
                              // Navigate to the profile edit function
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => EditProfile(
                                          authData: authData!,
                                          webId: webId!,
                                          profData: profData,
                                        )),
                              );
                            },
                          ),
                        )),
                ],
              ),
              // Display profile data
              SizedBox(
                height: 50,
              ),
              profileMenuItem("BASIC INFORMATION"),
              SizedBox(
                height: 20,
              ),
              buildLabelRow('Name', profData['name']),
              buildLabelRow('Birthday', profData['dob']),
              buildLabelRow('Country', profData['loc']),
              //
              profileMenuItem("WORK"),
              SizedBox(
                height: 20,
              ),
              buildLabelRow('Occupation', profData['occ']),
              buildLabelRow('Organisation', profData['org']),
              //
            ],
          ),
        ),
      ],
    );
  }

  // A menu item
  Row profileMenuItem(String title) {
    return Row(children: <Widget>[
      Text(
        title,
        style: TextStyle(
          color: lightGray,
          letterSpacing: 2.0,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      Expanded(
        child: new Container(
            margin: const EdgeInsets.only(left: 10.0, right: 0.0),
            child: Divider(
              color: lightGray,
              height: 36,
            )),
      ),
    ]);
  }

  // A profile info row
  Column buildLabelRow(String labelName, String profName) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '$labelName:',
              style: TextStyle(
                color: titleAsh,
                letterSpacing: 2.0,
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              profName,
              style: TextStyle(
                color: Colors.grey[800],
                letterSpacing: 2.0,
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 30,
        )
      ],
    );
  }
}
