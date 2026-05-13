import 'package:http/http.dart' as http;
import 'package:oidc/oidc.dart';
import 'package:logging/logging.dart';

import '../models/solid_auth_data.dart';
import '../models/solid_provider_metadata.dart';
import '../utils/solid_scopes.dart';
import '../utils/webid_utils.dart';
import 'solid_oidc_manager_factory.dart';

final _log = Logger('solid_auth.SolidAuthManager');

/// High-level facade for Solid-OIDC authentication.
///
/// This is the primary class consumers interact with. It replaces the old
/// free-standing `authenticate()` function with a stateful, lifecycle-aware
/// manager that correctly handles token refresh, logout, and user-change
/// streams.
///
/// ## Quick start
///
/// ```dart
/// final auth = SolidAuthManager(
///   config: SolidOidcConfig(
///     clientId: 'my_client_id',
///     redirectUri: Uri.parse('com.example.app://callback'),
///   ),
/// );
///
/// // Resolve the issuer from a WebID, then authenticate.
/// final data = await auth.loginFromWebId(
///   'https://charlieb.solidcommunity.net/profile/card#me',
/// );
/// print(data.webId); // https://charlieb.solidcommunity.net/profile/card#me
/// ```
///
/// ## Migration from solid_auth 0.1.x
///
/// | Old API                              | New API                                    |
/// |--------------------------------------|--------------------------------------------|
/// | `getIssuer(webId)`                   | `WebIdUtils.getIssuer(webId)`              |
/// | `authenticate(issuerUri, scopes)`    | `SolidAuthManager.loginFromWebId(webId)`   |
/// | `authData['accessToken']`            | `SolidAuthData.accessToken`                |
/// | `authData['idToken']`                | `SolidAuthData.idToken`                    |
/// | `genDpopToken(...)`                  | `DpopTokenGenerator.generate(...)`         |
class SolidAuthManager {
  SolidAuthManager({
    required this.config,
    this.httpClient,
  });

  final SolidOidcConfig config;
  final http.Client? httpClient;

  OidcUserManager? _oidcManager;

  /// The underlying [OidcUserManager] once initialised.
  /// Exposed for callers that need fine-grained access to oidc internals.
  OidcUserManager get oidcManager {
    if (_oidcManager == null) {
      throw StateError(
        'SolidAuthManager has not been initialised for an issuer yet. '
        'Call loginFromWebId() or initForIssuer() first.',
      );
    }
    return _oidcManager!;
  }

  // ── Issuer-aware login ────────────────────────────────────────────────────

  /// Resolves the OIDC issuer from [webId], initialises the underlying
  /// [OidcUserManager], then triggers the Authorization Code + PKCE flow.
  ///
  /// Returns a [SolidAuthData] with the tokens and extracted WebID on success.
  Future<SolidAuthData> loginFromWebId(
    String webId, {
    List<String>? scopeOverride,
  }) async {
    _log.info('Starting Solid-OIDC login for WebID: $webId');

    final issuerUri = await WebIdUtils.getIssuer(webId, httpClient: httpClient);
    return login(issuerUri: issuerUri, scopeOverride: scopeOverride);
  }

  /// Initialises for [issuerUri] and triggers the Authorization Code flow.
  ///
  /// Use this when you already know the issuer URI and don't have a WebID.
  Future<SolidAuthData> login({
    required String issuerUri,
    List<String>? scopeOverride,
  }) async {
    await initForIssuer(issuerUri);

    final effectiveConfig =
        scopeOverride != null ? _configWithScopes(scopeOverride) : config;

    // Re-create the manager if scopes differ.
    if (scopeOverride != null) {
      _oidcManager = SolidOidcManagerFactory.create(
        issuerUri: issuerUri,
        config: effectiveConfig,
      );
      await _oidcManager!.init();
    }

    _log.fine('Launching Authorization Code + PKCE flow');
    print('now1');
    final user = await _oidcManager!.loginAuthorizationCodeFlow();

    if (user == null) {
      throw const SolidAuthTokenException('Login cancelled or failed.');
    }

    print('there is a user ');
    print(user);

    return _mapUserToAuthData(user, issuerUri);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialises the [OidcUserManager] for [issuerUri] without triggering
  /// login. Useful for restoring a persisted session on app start:
  ///
  /// ```dart
  /// await auth.initForIssuer('https://solidcommunity.net');
  /// if (auth.currentAuthData != null) {
  ///   // Session restored from store — user is already logged in.
  /// }
  /// ```
  Future<void> initForIssuer(String issuerUri) async {
    if (_oidcManager == null ||
        _oidcManager!.discoveryDocument?.issuer.toString() != issuerUri) {
      _log.fine('Initialising OidcUserManager for issuer: $issuerUri');
      _oidcManager = SolidOidcManagerFactory.create(
        issuerUri: issuerUri,
        config: config,
      );
      await _oidcManager!.init();
      _log.fine('OidcUserManager ready');
    }
  }

  /// Logs out the user from the identity provider and clears local tokens.
  Future<void> logout() async {
    _log.info('Logging out');
    await _oidcManager?.logout();
  }

  /// Clears local token state without contacting the identity provider.
  Future<void> forgetUser() async {
    await _oidcManager?.forgetUser();
  }

  /// Disposes the underlying [OidcUserManager]. Call this when the auth
  /// object is no longer needed (e.g. in a widget's `dispose()`).
  Future<void> dispose() async {
    await _oidcManager?.dispose();
    _oidcManager = null;
  }

  // ── Token access ──────────────────────────────────────────────────────────

  /// Returns the current authenticated user as [SolidAuthData], or null
  /// if no session is active.
  SolidAuthData? get currentAuthData {
    final user = _oidcManager?.currentUser;
    if (user == null) return null;
    return _mapUserToAuthData(
      user,
      _oidcManager?.discoveryDocument?.issuer.toString() ?? '',
    );
  }

  /// Stream of user-session changes, mirroring [OidcUserManager.userChanges].
  ///
  /// Emits `null` on logout and a [SolidAuthData] on login / token refresh.
  Stream<SolidAuthData?> get authChanges {
    return oidcManager.userChanges().map(
          (user) => user == null
              ? null
              : _mapUserToAuthData(
                  user,
                  oidcManager.discoveryDocument?.issuer.toString() ?? '',
                ),
        );
  }

  /// Manually triggers a token refresh. Returns the refreshed [SolidAuthData]
  /// or null if no refresh token is available.
  Future<SolidAuthData?> refreshToken() async {
    final user = await _oidcManager?.refreshToken();
    if (user == null) return null;
    return _mapUserToAuthData(
      user,
      _oidcManager?.discoveryDocument?.issuer.toString() ?? '',
    );
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  SolidAuthData _mapUserToAuthData(OidcUser user, String issuerUri) {
    print('mapping user to auth data');
    final token = user.token;
    final claims = user.aggregatedClaims ?? {};

    print('here1');

    final accessToken = token.accessToken;
    final idToken = token.idToken ?? '';
    final refreshToken = token.refreshToken;
    final webId = _extractWebId(claims) ?? user.uid ?? '';

    print('here2');
    print(token.expiresIn);

    // Derive expiry: prefer explicit expiresAt, fall back to now + expires_in.
    final expiresAt = DateTime.now().add(token.expiresIn!);

    print('here3');

    return SolidAuthData(
      accessToken: accessToken ?? '',
      idToken: idToken,
      refreshToken: refreshToken,
      webId: webId,
      issuer: issuerUri,
      expiresAt: expiresAt,
      rawClaims: claims,
    );
  }

  /// Solid-OIDC stores the WebID in the `webid` claim of the ID token.
  String? _extractWebId(Map<String, dynamic> claims) {
    final webid = claims['webid'];
    if (webid is String && webid.isNotEmpty) return webid;
    // Fallback: some providers use `sub` as a WebID URI.
    final sub = claims['sub'];
    if (sub is String && sub.startsWith('http')) return sub;
    return null;
  }

  SolidOidcConfig _configWithScopes(List<String> scopes) {
    final effectiveScopes = scopes.contains(SolidScopes.webid)
        ? scopes
        : [...scopes, SolidScopes.webid];
    return SolidOidcConfig(
      clientId: config.clientId,
      redirectUri: config.redirectUri,
      postLogoutRedirectUri: config.postLogoutRedirectUri,
      scopes: effectiveScopes,
      clientSecret: config.clientSecret,
      httpClient: config.httpClient,
      extraTokenParameters: config.extraTokenParameters,
      extraAuthParameters: config.extraAuthParameters,
    );
  }
}
