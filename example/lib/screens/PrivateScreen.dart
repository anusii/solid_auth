// Flutter imports:
import 'package:flutter/material.dart';
import 'package:solid_auth/solid_auth.dart';

// Project imports:
import 'package:solid_auth_example/models/Responsive.dart';
import 'package:solid_auth_example/screens/PrivateProfile.dart';
import 'package:solid_auth_example/models/Constants.dart';

// ignore: must_be_immutable
class PrivateScreen extends StatelessWidget {
  SolidAuth solidAuth; // Authentication data

  PrivateScreen({Key? key, required this.solidAuth}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Assign loading screen
    var loadingScreen = PrivateProfile(
      solidAuth: solidAuth,
    );

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
