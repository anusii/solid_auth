/// SolidPod library to support privacy first data store on Solid Servers
///
/// Copyright (C) 2026, Software Innovation Institute ANU
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

// Add the library directive as we have doc entries above. We publish the above
// meta doc lines in the docs.

library;

// Flutter imports:
import 'package:flutter/material.dart';

//import 'package:solid_auth_example/models/RestAPI.dart';
//import 'package:solid_auth/solid_auth.dart';
import 'package:solid_auth/solid_auth.dart';
// Package imports:
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import 'package:solid_auth_example/models/Constants.dart';
import 'package:solid_auth_example/screens/PrivateScreen.dart';
import 'package:solid_auth_example/screens/PublicScreen.dart';

// ignore: must_be_immutable
class LoginScreen extends StatelessWidget {
  // Sample web ID to check the functionality
  var webIdController = TextEditingController()
    ..text = 'https://pods.solidcommunity.au/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Container(
      decoration: screenWidth(context) < 1175
          ? BoxDecoration(
              image: DecorationImage(
                  image: AssetImage('assets/images/background.jpg'),
                  fit: BoxFit.cover))
          : null,
      child: Row(
        children: [
          screenWidth(context) < 1175
              ? Container()
              : Expanded(
                  flex: 7,
                  child: Container(
                    decoration: BoxDecoration(
                        image: DecorationImage(
                            image: AssetImage('assets/images/background.jpg'),
                            fit: BoxFit.cover)),
                  )),
          Expanded(
              flex: 5,
              child: Container(
                margin: EdgeInsets.symmetric(
                    horizontal: screenWidth(context) < 1175
                        ? screenWidth(context) < 750
                            ? screenWidth(context) * 0.05
                            : screenWidth(context) * 0.25
                        : screenWidth(context) * 0.05),
                child: SingleChildScrollView(
                  child: Card(
                    elevation: 5,
                    color: bgOffWhite,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Container(
                      height: 910,
                      padding: EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Image.asset(
                            "assets/images/authentication-logo.png",
                            width: 400,
                          ),
                          SizedBox(
                            height: 0.0,
                          ),
                          Divider(height: 15, thickness: 2),
                          SizedBox(
                            height: 60.0,
                          ),
                          Text('FLUTTER SOID AUTHENTICATION',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.black,
                              )),
                          SizedBox(
                            height: 20.0,
                          ),
                          TextFormField(
                            controller: webIdController,
                            decoration: InputDecoration(
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          SizedBox(
                            height: 20.0,
                          ),
                          createSolidLoginRow(context, webIdController),
                          SizedBox(
                            height: 20.0,
                          ),
                          Text('OR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black,
                              )),
                          SizedBox(
                            height: 20.0,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Expanded(
                                  child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.all(20),
                                  backgroundColor: lightGold,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => PublicScreen(
                                              webId: webIdController.text,
                                            )),
                                  );
                                },
                                child: Text(
                                  'READ PUBLIC INFO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    letterSpacing: 2.0,
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    )));
  }

  // POD issuer registration page launch
  launchIssuerReg(String _issuerUri) async {
    var url = '$_issuerUri/register';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  // Create login row for SOLID POD issuer
  Row createSolidLoginRow(
      BuildContext context, TextEditingController _webIdTextController) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
            child: TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.all(20),
            backgroundColor: exLightBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () async => launchIssuerReg(
              (await WebIdUtils.getIssuer(_webIdTextController.text))
                  .toString()),
          child: Text(
            'GET A POD',
            style: TextStyle(
              color: titleAsh,
              letterSpacing: 2.0,
              fontSize: 15.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        )),
        SizedBox(
          width: 15.0,
        ),
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.all(20),
              backgroundColor: lightGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              // Define Solid Auth Manager
              final authManager = SolidAuthManager(
                config: SolidOidcConfig(
                  /// Custom URI schemes defined depending on the platform
                  /// [clientId] parameter should point to a `jsonld` document
                  /// containing the required authentication details.
                  /// For example see: https://anushkavidanage.github.io/solid_auth/example_app/client-profile.jsonld
                  ///
                  /// redirectUris for each platform defined below should match
                  /// the redirect uris defined on the clientId document above
                  ///
                  /// Client ID document hosted on web. Having a separate document for a client app
                  /// will prevent the app from requiring to do dynamic client registration everytime
                  /// app logs in
                  clientId:
                      'https://anushkavidanage.github.io/solid_auth/example_app/client-profile.jsonld',

                  /// Use the following schemes for defining redirect uris
                  /// Also refer to the oidc documentation
                  /// at: https://bdaya-dev.github.io/oidc/oidc-getting-started/
                  ///   On mobile: a custom-scheme URI registered with the OS (eg: com.example.solid.auth.example://redirect)
                  ///   On web: the path to your redirect.html (eg: https://anushkavidanage.github.io/solid_auth/example_app/redirect.html)
                  ///   On desktop: localhost as per oidc documentation (eg: http://localhost:0/redirect)
                  redirectUri: Uri.parse('http://localhost:0/redirect'),

                  /// Use the same redirect uris used above for corresponding plaform
                  postLogoutRedirectUri: Uri.parse(
                      'http://localhost:0/redirect'), //Uri.parse('${appUrlScheme}://logout'),

                  /// Solid-OIDC scopes. Webid is always added automatically
                  scopes: SolidScopes.defaultScopes,
                ),
              );

              // Authentication process for the POD issuer
              try {
                // getIssuer() + OidcUserManager.init() + loginAuthorizationCodeFlow()
                // are all handled internally.
                await authManager.authenticate(webIdController.text);

                if (authManager.authData != null) {
                  // Navigate to the profile through main screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PrivateScreen(
                              authManager: authManager,
                            )),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Login failed! \n Try again in few seconds'),
                    duration: const Duration(milliseconds: 3000),
                  ));
                }
              } on SolidAuthException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Login failed! \n ${e.message})'),
                  duration: const Duration(milliseconds: 3000),
                ));
              }
            },
            child: Text(
              'LOGIN',
              style: TextStyle(
                color: Colors.white,
                letterSpacing: 2.0,
                fontSize: 15.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
