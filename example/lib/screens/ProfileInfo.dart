// Flutter imports:
import 'package:flutter/material.dart';
import 'package:solid_auth/solid_auth.dart';
// Project imports:
import 'package:solid_auth_example/models/Constants.dart';
import 'package:solid_auth_example/screens/EditProfile.dart';

class ProfileInfo extends StatelessWidget {
  final Map profData; // Profile data
  final String profType; // Public or private
  final SolidAuth solidAuth; // SolidAuth instance
  const ProfileInfo({
    Key? key,
    required this.profData,
    required this.profType,
    required this.solidAuth,
  }) : super(key: key);

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
                              color: Colors.black.withOpacity(0.1),
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => EditProfile(
                                          profData: profData,
                                          solidAuth: solidAuth,
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
