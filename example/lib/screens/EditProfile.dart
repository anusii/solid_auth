// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
//import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:solid_auth/solid_auth.dart';

// Project imports:
import 'package:solid_auth_example/models/Constants.dart';
import 'package:solid_auth_example/components/Header.dart';
import 'package:solid_auth_example/models/SolidApi.dart';
import 'package:solid_auth_example/screens/PrivateScreen.dart';

class EditProfile extends StatefulWidget {
  final Map authData;
  final String webId;
  final Map profData;
  const EditProfile({
    Key? key,
    required this.authData,
    required this.webId,
    required this.profData,
  }) : super(key: key);

  @override
  _EditProfileState createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Text editing controllers
  late TextEditingController nameController;
  late TextEditingController dobController;
  late TextEditingController occController;
  late TextEditingController orgController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.profData['name']);
    dobController = TextEditingController(text: widget.profData['dob']);
    occController = TextEditingController(text: widget.profData['occ']);
    orgController = TextEditingController(text: widget.profData['org']);
  }

  @override
  Widget build(BuildContext context) {
    String logoutUrl = widget.authData['logoutUrl'];

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: Column(
          children: [
            Header(mainDrawer: _scaffoldKey, logoutUrl: logoutUrl),
            Divider(thickness: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(kDefaultPadding * 1.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.menu_book_rounded,
                                      color: brickRed),
                                  SizedBox(width: 10.0),
                                  Text("Edit Profile Info",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 50,
                          ),
                          createInputField(
                              "NAME", nameController, widget.profData['name']),
                          createInputDateField("DATE OF BIRTH", dobController,
                              widget.profData['dob']),
                          createInputField("OCCUPATION", occController,
                              widget.profData['occ']),
                          createInputField("ORGANISATION", orgController,
                              widget.profData['org']),
                          SizedBox(
                            height: 20,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => PrivateScreen(
                                                authData: widget.authData,
                                                webId: widget.webId,
                                              )),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 40),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20))),
                                  child: Text(
                                    "CANCEL",
                                    style: TextStyle(
                                      color: darkGold,
                                      letterSpacing: 2.0,
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                    ),
                                  )),
                              SizedBox(
                                width: 10,
                              ),
                              ElevatedButton(
                                  onPressed: () async {
                                    var rsaInfo = widget.authData['rsaInfo'];

                                    // Get access token
                                    String accessToken =
                                        widget.authData['accessToken'];
                                    // Map<String, dynamic> decodedToken =
                                    //     JwtDecoder.decode(accessToken);

                                    // Get RSA public/private key pair
                                    var rsaKeyPair = rsaInfo['rsa'];
                                    var publicKeyJwk = rsaInfo['pubKeyJwk'];

                                    // Get profile URI
                                    String profCardUrl =
                                        widget.webId.replaceAll('#me', '');

                                    // Generate DPoP token
                                    String dPopToken = genDpopToken(profCardUrl,
                                        rsaKeyPair, publicKeyJwk, 'PATCH');

                                    List attrList = [
                                      'name',
                                      'dob',
                                      'occ',
                                      'org'
                                    ]; // Attribute list
                                    Map predicateMap = {
                                      'name': 'fn',
                                      'dob': 'bday',
                                      'occ': 'role',
                                      'org': 'organization-name'
                                    }; // predicate name list
                                    int numOfUpdates = 0;

                                    // Loop through attribute list and check for changes
                                    // if there are any update those
                                    for (var i = 0; i < attrList.length; i++) {
                                      String attr = attrList[i];
                                      String prevVal = '';
                                      String newVal = '';

                                      switch (attr) {
                                        case 'name':
                                          {
                                            prevVal = widget.profData['name'];
                                            newVal = nameController.text;
                                          }
                                          break;
                                        case 'dob':
                                          {
                                            prevVal = widget.profData['dob'];
                                            newVal = dobController.text;
                                          }
                                          break;
                                        case 'occ':
                                          {
                                            prevVal = widget.profData['occ'];
                                            newVal = occController.text;
                                          }
                                          break;
                                        case 'org':
                                          {
                                            prevVal = widget.profData['org'];
                                            newVal = orgController.text;
                                          }
                                          break;
                                        default:
                                          {
                                            print('Invalid attribute name');
                                          }
                                      }

                                      // If the value in an attribute is changed
                                      if ((prevVal != '' && newVal != '') &&
                                          (prevVal != newVal)) {
                                        String updateQuery = '';

                                        // Generate update query
                                        if (attr == 'dob') {
                                          updateQuery = genSparqlQuery(
                                              'UPDATE_DATE',
                                              widget.webId,
                                              'http://www.w3.org/2006/vcard/ns#' +
                                                  predicateMap[attr],
                                              newVal,
                                              prevObject: prevVal,
                                              format:
                                                  'http://www.w3.org/2001/XMLSchema#date');
                                        } else {
                                          updateQuery = genSparqlQuery(
                                              'UPDATE',
                                              widget.webId,
                                              'http://www.w3.org/2006/vcard/ns#' +
                                                  predicateMap[attr],
                                              newVal,
                                              prevObject: prevVal);
                                        }

                                        // Update profile using the generated query
                                        String updateResponse =
                                            await updateProfile(
                                                profCardUrl,
                                                accessToken,
                                                dPopToken,
                                                updateQuery);
                                        numOfUpdates += 1;
                                        assert(updateResponse == 'success');
                                      }
                                    }

                                    print(
                                        'Number of updates conducted: $numOfUpdates'); // Print number of updates conducted

                                    // Going back to profile page
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => PrivateScreen(
                                                authData: widget.authData,
                                                webId: widget.webId,
                                              )),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                      foregroundColor: darkGold,
                                      backgroundColor: lightGold, // foreground
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 50),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20))),
                                  child: Text(
                                    "UPDATE",
                                    style: TextStyle(
                                      color: Colors.white,
                                      letterSpacing: 2.0,
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Create input field for texual values
  TextField createInputField(
      String labelText, TextEditingController controller, String initValue,
      {double rowHeight = 25.0}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
          //contentPadding: EdgeInsets.only(top: 5),
          //contentPadding: EdgeInsets.all(0.0),
          isDense: true,
          contentPadding: EdgeInsets.fromLTRB(0.0, rowHeight, 0.0, 5.0),
          labelText: "$labelText",
          labelStyle: TextStyle(
            color: titleAsh,
            letterSpacing: 2.0,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          )),
    );
  }

  // Create input field for date values
  TextField createInputDateField(
      String labelText, TextEditingController controller, String initValue) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.fromLTRB(0.0, 25.0, 0.0, 5.0),
          labelText: "$labelText",
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          )),
      onTap: () async {
        var date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: lightGold, // header background color
                  onPrimary: Colors.white, // header text color
                  onSurface: darkCopper, // body text color
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red, // button text color
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        controller.text = date.toString().substring(0, 10);
      },
    );
  }
}
