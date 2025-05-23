// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:solid_auth/solid_auth.dart';

// Project imports:
import 'package:solid_auth_example/models/Constants.dart';
import 'package:solid_auth_example/models/Responsive.dart';
import 'package:solid_auth_example/screens/LoginScreen.dart';

// Widget for the top horizontal bar
// ignore: must_be_immutable
class Header extends StatelessWidget {
  var mainDrawer;
  String logoutUrl;
  Header({
    Key? key,
    required this.mainDrawer,
    required this.logoutUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: lightGold,
      child: Padding(
        padding: const EdgeInsets.all(kDefaultPadding / 1.5),
        child: Row(
          children: [
            if (Responsive.isMobile(context) & (logoutUrl != 'none'))
              IconButton(onPressed: () {}, icon: Icon(Icons.menu)),
            if (!Responsive.isDesktop(context)) SizedBox(width: 5),
            Spacer(),
            if (!Responsive.isDesktop(context)) SizedBox(width: 5),
            SizedBox(width: kDefaultPadding / 4),
            if (logoutUrl != 'none') SizedBox(width: kDefaultPadding / 4),
            (logoutUrl != 'none')
                ? TextButton.icon(
                    icon: Icon(
                      Icons.logout,
                      color: Colors.black,
                      size: 24.0,
                    ),
                    label: Text(
                      'LOGOUT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    onPressed: () {
                      logout(logoutUrl);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                  )
                : IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      size: 24.0,
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                  ),
            SizedBox(width: kDefaultPadding / 4),
          ],
        ),
      ),
    );
  }
}
