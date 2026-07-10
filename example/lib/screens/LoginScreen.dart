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
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

//import 'package:solidautheg/models/RestAPI.dart';
//import 'package:solid_auth/solid_auth.dart';
import 'package:solid_auth/solid_auth.dart';
// Package imports:
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import 'package:solidautheg/models/Constants.dart';
import 'package:solidautheg/screens/PrivateScreen.dart';
import 'package:solidautheg/screens/PublicScreen.dart';

/// The Solid-OIDC redirect URI for the current platform.
String _platformRedirectUri({String nativePath = 'redirect'}) {
  if (kIsWeb) {
    return '${Uri.base.origin}/redirect.html';
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return 'com.example.solidautheg://$nativePath';
    default:
      return 'http://localhost:4400/redirect.html';
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Sample web ID to check the functionality
  final _webIdController = TextEditingController()
    ..text = 'https://pods.solidcommunity.au/';

  /// Whether the app is currently checking for a previously saved session.
  bool _isRestoringSession = true;

  /// The [SolidAuthManager] is created once and reused for both the
  /// automatic session-restore check and the manual login button tap.
  late final SolidAuthManager _authManager = SolidAuthManager(
    config: SolidOidcConfig(
      /// Client ID document hosted on web. Having a separate document for
      /// a client app will prevent the app from requiring dynamic client
      /// registration on every login.
      /// See: https://anushkavidanage.github.io/solid_auth/example_app/client-profile.jsonld
      clientId:
          'https://anushkavidanage.github.io/solid_auth/example_app/client-profile.jsonld',

      /// Redirect URI for the current platform, derived at runtime (see
      /// [_platformRedirectUri]): the served app's origin on web, a custom
      /// scheme on Android/iOS/macOS, a localhost loopback on Windows/Linux.
      redirectUri: Uri.parse(_platformRedirectUri()),

      /// Post-logout URI for the current platform. On native platforms this
      /// uses the `logout` path so it matches the client identifier document's
      /// `post_logout_redirect_uris` entry.
      postLogoutRedirectUri: Uri.parse(_platformRedirectUri(nativePath: 'logout')),

      /// Solid-OIDC scopes. The `webid` scope is always added automatically.
      scopes: SolidScopes.defaultScopes,
    ),
  );

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  /// Checks for a previously saved session on startup.
  ///
  /// If valid tokens are found in secure storage, navigates directly to
  /// [PrivateScreen] without requiring the user to log in again.
  Future<void> _tryRestoreSession() async {
    final data = await _authManager.tryRestoreSession();
    if (!mounted) return;
    if (data != null) {
      // Session restored — go straight to the authenticated screen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PrivateScreen(authManager: _authManager),
        ),
      );
    } else {
      // No valid session — show the login UI.
      setState(() => _isRestoringSession = false);
    }
  }

  @override
  void dispose() {
    _webIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while checking for a persisted session.
    if (_isRestoringSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                            controller: _webIdController,
                            decoration: InputDecoration(
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          SizedBox(
                            height: 20.0,
                          ),
                          _buildLoginRow(context),
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
                                              webId: _webIdController.text,
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
  Future<void> _launchIssuerReg(String issuerUri) async {
    final url = '$issuerUri/register';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  // Create login row for SOLID POD issuer
  Row _buildLoginRow(BuildContext context) {
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
          onPressed: () async => _launchIssuerReg(
              (await WebIdUtils.getIssuer(_webIdController.text)).toString()),
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
              // Authentication process for the POD issuer.
              // getIssuer() + OidcUserManager.init() + loginAuthorizationCodeFlow()
              // are all handled internally by authManager.authenticate().
              try {
                await _authManager.authenticate(_webIdController.text);

                if (!mounted) return;

                if (_authManager.authData != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PrivateScreen(
                              authManager: _authManager,
                            )),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Login failed! \n Try again in few seconds'),
                    duration: const Duration(milliseconds: 3000),
                  ));
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Login failed! \n $e'),
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
