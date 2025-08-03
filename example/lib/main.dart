// Flutter imports:
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:solid_auth/solid_auth.dart';

// Project imports:
import 'package:solid_auth_example/screens/LoginScreen.dart';
import 'package:solid_auth_example/screens/PrivateScreen.dart';

void main() {
  // Ensure Flutter bindings are initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  _setupConsoleLogging();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final SolidAuth solidAuth;
  late final Future<bool> _initFuture;

  @override
  void initState() {
    super.initState();

    // Initialize SolidAuth with OIDC client configuration
    //
    // Security Model:
    // - For web: Relies on DNS security and browser Same-Origin Policy for redirect validation
    // - For mobile/desktop: Uses platform-specific URL schemes with security enforced by app stores
    //   and platform policies to ensure scheme uniqueness and prevent hijacking
    // - The client-profile.jsonld must be hosted on a trusted domain and contain matching redirect URIs
    //
    // CRITICAL WARNING: As of this writing, the OIDC library uses localhost loopback with random ports
    // for Windows and Linux desktop applications. This approach is NOT well supported with
    // client-profile.jsonld static configuration. Windows and Linux desktop apps are NOT ADVISED
    // until further research determines how to support this securely with pre-defined redirect URIs.
    solidAuth = SolidAuth(
      // OIDC Client ID: URL pointing to the client profile document (client-profile.jsonld)
      // In Solid OIDC, this URL itself serves as the client_id and must be used in two places:
      // 1. Here as the oidcClientId parameter
      // 2. As the "client_id" field value inside the client-profile.jsonld document
      //
      // CRITICAL: The URL provided here MUST exactly match the "client_id" field in the JSON document.
      //
      // The client-profile.jsonld document contains the OAuth2/OIDC client metadata including:
      // - client_id: Must be identical to this URL (REQUIRED)
      // - redirect_uris: List of allowed redirect URIs after authentication
      // - client_name: Human-readable name of the application
      // - grant_types: Supported OAuth2 grant types (typically "authorization_code")
      // - scope: Requested scopes (typically "openid profile webid")
      //
      // Security: The hosting domain must be trusted as this document defines the security
      // boundaries of the OAuth2 client. Tampering with this document could compromise security.
      //
      // This example app hosts the client-profile.jsonld on GitHub Pages, which provides:
      // - HTTPS encryption for secure document delivery
      // - Reliable availability through GitHub's CDN infrastructure
      // - Version-controlled configuration management
      // Production apps should similarly host this document on a trusted, reliable platform.
      // FIXME: update when merging to upstream!
      oidcClientId:
          'https://kkalass.github.io/solid_auth/example/client-profile.jsonld',

      // App URL Scheme: Custom URI scheme for mobile/desktop platforms (ios/android/macos)
      // SolidAuth will automatically construct redirect and logout URIs using this scheme:
      // - '${appUrlScheme}://redirect' for authentication redirects
      // - '${appUrlScheme}://logout' for logout redirects
      // These constructed URIs must match entries in the client-profile.jsonld redirect_uris array
      //
      // Security: Platform-specific URL schemes provide security through:
      // - iOS: App Store review process ensures scheme uniqueness
      // - Android: Package name-based scheme prevents hijacking by other apps
      // - macOS: Bundle identifier-based validation
      //
      // Note: For web-only applications, this parameter is not strictly required
      // but should be set if you plan to support mobile/desktop platforms
      // FIXME: update when merging to upstream!
      appUrlScheme: 'de.kalass.solidauth.example',

      // Frontend Redirect URL: Web-specific redirect URI for browser-based authentication
      // This URL is used for both authentication redirects and logout redirects on web platforms
      // This URL must be:
      // 1. Listed in the redirect_uris array of the client-profile.jsonld
      // 2. Served over HTTPS
      // 3. Hosted on the same domain as your web application for security
      //
      // Security: Browser Same-Origin Policy prevents malicious sites from intercepting
      // the authorization code. DNS security ensures the redirect goes to the intended domain.
      // FIXME: update when merging to upstream!
      frontendRedirectUrl: Uri.parse(
        'https://kkalass.github.io/solid_auth/example/redirect.html',
      ),
    );

    // Initialize SolidAuth and prepare for reactive authentication state changes
    _initFuture = solidAuth.init();
  }

  @override
  void dispose() {
    // Properly dispose of SolidAuth resources when the app shuts down
    solidAuth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Solid Authentication',
      theme: ThemeData(),
      home: FutureBuilder<bool>(
        // Wait for SolidAuth initialization to complete
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // After initialization, use reactive authentication state
          return ValueListenableBuilder<bool>(
            valueListenable: solidAuth.isAuthenticatedNotifier,
            builder: (context, isAuthenticated, child) {
              return isAuthenticated
                  ? PrivateScreen(solidAuth: solidAuth)
                  : LoginScreen(solidAuth: solidAuth);
            },
          );
        },
      ),
    );
  }
}

void _setupConsoleLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      // ignore: avoid_print
      print('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print('Stack trace:\n${record.stackTrace}');
    }
  });
}
