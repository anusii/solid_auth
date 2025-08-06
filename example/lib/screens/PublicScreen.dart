// Flutter imports:
import 'package:flutter/material.dart';
import 'package:solid_auth/solid_auth.dart';

// Project imports:
import 'package:solid_auth_example/models/Responsive.dart';
import 'package:solid_auth_example/screens/PublicProfile.dart';

class PublicScreen extends StatelessWidget {
  final SolidAuth solidAuth;
  final String webId; // Web ID for public profile

  PublicScreen({Key? key, required this.solidAuth, required this.webId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Navigate to public profile with a loading screen
    var loadingScreen = PublicProfile(
      solidAuth: solidAuth,
      webId: webId,
    );
    return Scaffold(
        body: Responsive(
      mobile: loadingScreen,
      tablet: loadingScreen,
      desktop: loadingScreen,
    ));
  }
}
