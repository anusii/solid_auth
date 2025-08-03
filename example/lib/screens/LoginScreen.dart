// Flutter imports:
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
//import 'package:solid_auth_example/models/RestAPI.dart';
//import 'package:solid_auth/solid_auth.dart';
import 'package:solid_auth/solid_auth.dart';
// Project imports:
import 'package:solid_auth_example/models/Constants.dart';
import 'package:solid_auth_example/screens/PublicScreen.dart';
// Package imports:
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('LoginScreen');
const String defaultIssuer = 'https://pods.solidcommunity.au/';
const String defaultIssuerRegister =
    'https://pods.solidcommunity.au/.account/login/password/register/';

class LoginScreen extends StatefulWidget {
  final SolidAuth solidAuth;

  LoginScreen({Key? key, required this.solidAuth}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Sample web ID to check the functionality
  late TextEditingController webIdController;
  bool isValidWebId = false;

  @override
  void initState() {
    super.initState();
    webIdController = TextEditingController(text: defaultIssuer);
    webIdController.addListener(_validateWebId);
    _validateWebId(); // Initial validation
  }

  @override
  void dispose() {
    webIdController.removeListener(_validateWebId);
    webIdController.dispose();
    super.dispose();
  }

  /// Validates if the current text is a valid WebID
  /// WebID should end with '/profile/card#me'
  void _validateWebId() {
    setState(() {
      isValidWebId = webIdController.text.trim().endsWith('/profile/card#me');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: screenWidth(context) < 1175
              ? BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/background.jpg'),
                    fit: BoxFit.cover,
                  ),
                )
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
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
              Expanded(
                flex: 5,
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: screenWidth(context) < 1175
                        ? screenWidth(context) < 750
                              ? screenWidth(context) * 0.05
                              : screenWidth(context) * 0.25
                        : screenWidth(context) * 0.05,
                  ),
                  child: SingleChildScrollView(
                    child: Card(
                      elevation: 5,
                      color: bgOffWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        height: 910,
                        padding: EdgeInsets.all(30),
                        child: Column(
                          children: [
                            Image.asset(
                              "assets/images/authentication-logo.png",
                              width: 400,
                            ),
                            SizedBox(height: 0.0),
                            Divider(height: 15, thickness: 2),
                            SizedBox(height: 60.0),
                            Text(
                              'FLUTTER SOLID AUTHENTICATION',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 20.0),
                            TextFormField(
                              controller: webIdController,
                              decoration: InputDecoration(
                                border: UnderlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 8.0),
                            Text(
                              'Enter an Issuer URL or WebID to log in',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            SizedBox(height: 20.0),
                            createSolidLoginRow(context, webIdController),
                            SizedBox(height: 20.0),
                            Text(
                              'OR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 20.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Tooltip(
                                    message: isValidWebId
                                        ? 'Read public profile information'
                                        : 'Enter a WebID (ending with /profile/card#me) to read public profiles',
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.all(20),
                                        backgroundColor: isValidWebId
                                            ? lightGold
                                            : Colors.grey,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: isValidWebId
                                          ? () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      PublicScreen(
                                                        solidAuth:
                                                            widget.solidAuth,
                                                        webId: webIdController
                                                            .text,
                                                      ),
                                                ),
                                              );
                                            }
                                          : null,
                                      child: Text(
                                        'READ PUBLIC INFO',
                                        style: TextStyle(
                                          color: isValidWebId
                                              ? Colors.white
                                              : Colors.grey[600],
                                          letterSpacing: 2.0,
                                          fontSize: 15.0,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // POD issuer registration page launch
  launchIssuerReg(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  // Create login row for SOLID POD issuer
  Row createSolidLoginRow(
    BuildContext context,
    TextEditingController _webIdTextController,
  ) {
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
            // FIXME: I simplified this to always use solidcommunity.au - I hope this is fine?
            onPressed: () async => launchIssuerReg(defaultIssuerRegister),
            child: Text(
              'GET A POD',
              style: TextStyle(
                color: titleAsh,
                letterSpacing: 2.0,
                fontSize: 15.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 15.0),
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
              // Authentication process for the POD issuer
              try {
                await widget.solidAuth.authenticate(
                  _webIdTextController.text,
                  scopes: ['profile'],
                );
                // Authentication successful - the ValueListenableBuilder will automatically
                // detect the state change and show PrivateScreen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Login Successful!'),
                    duration: const Duration(milliseconds: 2000),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e, stackTrace) {
                // Log the actual error for debugging
                _log.severe('Authentication error: $e', e, stackTrace);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Login Failed: ${e.toString()}'),
                    duration: const Duration(milliseconds: 5000),
                    backgroundColor: Colors.red,
                  ),
                );
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
