// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'package:solid_auth_example/models/Constants.dart';
import 'package:solid_auth_example/components/Header.dart';
import 'package:solid_auth_example/screens/ProfileInfo.dart';
import 'package:solid_auth/solid_auth.dart';
import 'package:solid_auth_example/models/GetRdfData.dart';
import 'package:http/http.dart' as http;

class PublicProfile extends StatefulWidget {
  final SolidAuth solidAuth; // SolidAuth instance
  final String webId; // Web ID for public profile

  const PublicProfile({Key? key, required this.solidAuth, required this.webId})
      : super(key: key);

  @override
  State<PublicProfile> createState() => _PublicProfileState();
}

/// Get public profile information from webId
Future<String> _fetchProfileData(String profUrl) async {
  final response = await http.get(
    Uri.parse(profUrl),
    headers: <String, String>{
      'Content-Type': 'text/turtle',
    },
  );

  if (response.statusCode == 200) {
    /// If the server did return a 200 OK response,
    /// then parse the JSON.
    return response.body;
  } else {
    /// If the server did not return a 200 OK response,
    /// then throw an exception.
    throw Exception('Failed to load data! Try again in a while.');
  }
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
          Header(
            mainDrawer: _scaffoldKey,
            solidAuth: widget.solidAuth,
          ),
          Divider(thickness: 1),
          Expanded(
            child: SingleChildScrollView(
                padding: EdgeInsets.all(kDefaultPadding * 1.5),
                child: ProfileInfo(
                  profData: profData,
                  profType: 'public',
                  solidAuth: widget.solidAuth,
                )),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String webId = widget.webId; // Get the webId from the widget

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: FutureBuilder(
            // Get profile data (.ttl file) from the webId
            future: _fetchProfileData(webId),
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
