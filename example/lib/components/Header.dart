// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:solid_auth/solid_auth.dart';

// Project imports:
import 'package:solid_auth_example/models/Constants.dart';
import 'package:solid_auth_example/models/Responsive.dart';

// Widget for the top horizontal bar
// ignore: must_be_immutable
class Header extends StatelessWidget {
  var mainDrawer;
  final SolidAuth solidAuth;
  Header({
    Key? key,
    required this.mainDrawer,
    required this.solidAuth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: solidAuth.isAuthenticatedNotifier,
      builder: (context, isAuthenticated, child) {
        return Container(
          color: lightGold,
          child: Padding(
            padding: const EdgeInsets.all(kDefaultPadding / 1.5),
            child: Row(
              children: [
                if (Responsive.isMobile(context) & (isAuthenticated))
                  IconButton(onPressed: () {}, icon: Icon(Icons.menu)),
                if (!Responsive.isDesktop(context)) SizedBox(width: 5),
                Spacer(),
                if (!Responsive.isDesktop(context)) SizedBox(width: 5),
                SizedBox(width: kDefaultPadding / 4),
                if (isAuthenticated) SizedBox(width: kDefaultPadding / 4),
                (isAuthenticated)
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
                          // Logout and let reactive main app handle screen transition
                          solidAuth.logout();
                        },
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          size: 24.0,
                        ),
                        onPressed: () {
                          // Navigate back in the stack (e.g., from profile to main screen)
                          Navigator.of(context).pop();
                        },
                      ),
                SizedBox(width: kDefaultPadding / 4),
              ],
            ),
          ),
        );
      },
    );
  }
}
