// example/lib/main.dart
//
// Demonstrates the restructured solid_auth API using package:oidc.
// Mirrors the usage example from the old solid_auth README.

import 'package:flutter/material.dart';
import 'package:solid_auth/solid_auth.dart';
import 'package:logging/logging.dart';

void main() {
  // Optional: configure logging for debugging.
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen(
      (r) => debugPrint('[${r.loggerName}] ${r.level.name}: ${r.message}'));

  runApp(const SolidAuthExampleApp());
}

class SolidAuthExampleApp extends StatelessWidget {
  const SolidAuthExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solid Auth Example',
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ── 1. Create the manager once ─────────────────────────────────────────────
  //
  // SolidAuthManager wraps OidcUserManager. You typically hold this at the
  // app or provider level (Riverpod, BLoC, etc.).
  final _auth = SolidAuthManager(
    config: SolidOidcConfig(
      // clientId: 'my_solid_client',

      // // On mobile: a custom-scheme URI registered with the OS.
      // // On web:    the path to your redirect.html (see package:oidc docs).
      // redirectUri: Uri.parse('com.example.solidapp://callback'),

      // postLogoutRedirectUri: Uri.parse('com.example.solidapp://callback'),

      clientId:
          'https://anushkavidanage.github.io/solid_auth/example_app/client-profile.jsonld',

      // On mobile: a custom-scheme URI registered with the OS.
      // On web:    the path to your redirect.html (see package:oidc docs).
      redirectUri: Uri.parse('com.example.solid.auth.example://redirect'),

      postLogoutRedirectUri: Uri.parse(
          'com.example.solid.auth.example://logout'), //Uri.parse('${appUrlScheme}://logout'),

      // Solid-OIDC scopes — webid is always added automatically.
      scopes: SolidScopes.defaultScopes,
    ),
  );

  SolidAuthData? _authData;
  String? _error;
  bool _loading = false;

  // ── 2. Authenticate from a WebID ───────────────────────────────────────────

  Future<void> _login() async {
    const webId = 'https://pods.solidcommunity.au/';

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // getIssuer() + OidcUserManager.init() + loginAuthorizationCodeFlow()
      // are all handled internally.
      final authData = await _auth.loginFromWebId(webId);
      print('here');
      print(authData);

      setState(() => _authData = authData);
    } on SolidAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── 3. Generate a DPoP token for a resource request ───────────────────────

  Future<void> _fetchPrivateResource() async {
    if (_authData == null) return;

    const resourceUrl = 'https://charlieb.solidcommunity.net/private/data.ttl';

    final dpopToken = await DpopTokenGenerator.generateForRequest(
      endpointUrl: resourceUrl,
      httpMethod: 'GET',
      accessToken: _authData!.accessToken,
    );

    // Use the token in the HTTP request:
    // headers: {
    //   'Authorization': 'DPoP ${_authData!.accessToken}',
    //   'DPoP': dpopToken,
    // }
    debugPrint('DPoP token: $dpopToken');
  }

  // ── 4. Fetch public profile ────────────────────────────────────────────────

  Future<void> _fetchProfile() async {
    final profile = await const ProfileFetcher().fetchProfile(_authData!.webId);
    debugPrint('Name: ${profile.name}');
    debugPrint('Storage: ${profile.storage}');
    debugPrint('Issuer: ${profile.oidcIssuer}');
  }

  // ── 5. Logout ─────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    await _auth.logout();
    setState(() => _authData = null);
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solid Auth Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            if (_authData != null) ...[
              Text('WebID: ${_authData!.webId}'),
              Text('Issuer: ${_authData!.issuer}'),
              Text('Expired: ${_authData!.isExpired}'),
              const SizedBox(height: 8),
              ElevatedButton(
                  onPressed: _fetchPrivateResource,
                  child: const Text('Generate DPoP Token')),
              ElevatedButton(
                  onPressed: _fetchProfile, child: const Text('Fetch Profile')),
              ElevatedButton(onPressed: _logout, child: const Text('Logout')),
            ] else
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Login with Solid'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Issuer-only flow (matching old authenticate() API) ─────────────────────
//
// If you already have the issuer URI (e.g. from your own discovery logic),
// you can bypass WebID resolution:
//
// final authData = await _auth.login(
//   issuerUri: 'https://solidcommunity.net',
// );
