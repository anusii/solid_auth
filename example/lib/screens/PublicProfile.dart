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

//import 'package:solid_auth_example/models/RestAPI.dart';
import 'package:solid_auth/solid_auth.dart';

import 'package:solid_auth_example/components/Header.dart';
// Project imports:
import 'package:solid_auth_example/models/Constants.dart';
import 'package:solid_auth_example/models/GetRdfData.dart';
import 'package:solid_auth_example/screens/ProfileInfo.dart';

class PublicProfile extends StatefulWidget {
  final String webId;

  const PublicProfile({Key? key, required this.webId}) : super(key: key);

  @override
  State<PublicProfile> createState() => _PublicProfileState();
}

class _PublicProfileState extends State<PublicProfile> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Loading widget
  Widget _loadingScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        new Container(
          alignment: AlignmentDirectional.center,
          decoration: new BoxDecoration(
            color: backgroundWhite,
          ),
          child: new Container(
            decoration: new BoxDecoration(
                color: lightGold,
                borderRadius: new BorderRadius.circular(25.0)),
            width: 300.0,
            height: 200.0,
            alignment: AlignmentDirectional.center,
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Center(
                  child: new SizedBox(
                    height: 50.0,
                    width: 50.0,
                    child: new CircularProgressIndicator(
                      value: null,
                      color: backgroundWhite,
                      strokeWidth: 7.0,
                    ),
                  ),
                ),
                new Container(
                  margin: const EdgeInsets.only(top: 25.0),
                  child: new Center(
                    child: new Text(
                      "Loading.. Please wait!",
                      style: new TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Loaded screen
  Widget _loadedScreen(Object profInfo, String webId) {
    // Get profile information from the .ttl file
    PodProfile podProfile = PodProfile(profInfo.toString());
    String profPic = podProfile.getProfPicture();
    String profName = podProfile.getProfName();
    String profDob = podProfile.getPersonalInfo('bday');
    String profOcc = podProfile.getPersonalInfo('role');
    String profOrg = podProfile.getPersonalInfo('organization-name');
    String profCoun = podProfile.getPersonalInfo('country-name');

    // Set profile picture url (if any)
    String picUrl = webId;
    if (profPic.contains('http')) {
      picUrl = profPic;
    } else {
      if (profPic != '') {
        picUrl = picUrl.replaceAll('card#me', profPic);
      } else {
        // Dafault picture
        picUrl =
            'https://t4.ftcdn.net/jpg/00/64/67/63/360_F_64676383_LdbmhiNM6Ypzb3FM4PPuFP9rHe7ri8Ju.jpg';
      }
    }

    // Store profile info
    Map profData = {
      'name': profName,
      'picUrl': picUrl,
      'dob': profDob,
      'occ': profOcc,
      'org': profOrg,
      'loc': profCoun,
    };

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Header(mainDrawer: _scaffoldKey, logoutUrl: 'none'),
          Divider(thickness: 1),
          Expanded(
            child: SingleChildScrollView(
                padding: EdgeInsets.all(kDefaultPadding * 1.5),
                child: ProfileInfo(profData: profData, profType: 'public')),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String webId = widget.webId;

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: FutureBuilder(
            future: fetchProfileData(
                webId), // Get profile data (.ttl file) from the webId
            builder: (context, snapshot) {
              Widget returnVal;
              if (snapshot.connectionState == ConnectionState.done) {
                returnVal = _loadedScreen(snapshot.data!, webId);
              } else {
                returnVal = _loadingScreen();
              }
              return returnVal;
            }),
      ),
    );
  }
}
