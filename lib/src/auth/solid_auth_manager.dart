/// Support for flutter apps authenticating to a Solid server.
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
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
library;

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';

import 'package:solid_auth/src/auth/solid_oidc_manager_factory.dart';
import 'package:solid_auth/src/dpop/dpop_key_manager.dart';
import 'package:solid_auth/src/models/solid_auth_data.dart';
import 'package:solid_auth/src/models/solid_provider_metadata.dart';
import 'package:solid_auth/src/utils/solid_scopes.dart';
import 'package:solid_auth/src/utils/webid_utils.dart';

final _log = Logger('solid_auth.SolidAuthManager');

/// High-level facade for Solid-OIDC authentication.
///
/// Wraps [OidcUserManager] from `package:oidc` and adds Solid-specific
/// concerns: WebID-based issuer discovery, mandatory `webid` scope, and
/// DPoP key management.
///
/// ## DPoP flow
///
/// 1. [SolidOidcManagerFactory.create] pre-generates an RSA key pair via
///    [DpopKeyManager] and registers an [OidcHook] that automatically injects
///    a DPoP proof header on every token-endpoint request.
/// 2. The Solid OP binds the returned access token to the key pair by
///    embedding `cnf: { jkt: "<thumbprint>" }` in it.
/// 3. When you access a protected resource, call
///    [DpopTokenGenerator.generateForRequest] with the stored [keyManager]
///    to produce a matching proof.
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
/// final data = await auth.loginFromWebId(
///   'https://alice.solidcommunity.net/profile/card#me',
/// );
///
/// // Accessing a protected resource:
/// final dpopProof = await DpopTokenGenerator.generateForRequest(
///   endpointUrl: 'https://alice.solidcommunity.net/private/notes.ttl',
///   httpMethod: 'PATCH',
///   accessToken: data.accessToken,
///   keyManager: auth.keyManager, // same key pair used at auth time
/// );
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
///
class SolidAuthManager {
  SolidAuthManager({
    required this.config,
    this.httpClient,
  });

  final SolidOidcConfig config;
  final http.Client? httpClient;

  /// The [SolidAuthData] instance for the auth manager
  /// Stores authentication data such as access token and web id
  /// after a successful authentication
  SolidAuthData? authData;

  OidcUserManager? _oidcManager;

  /// The [DpopKeyManager] created during [initForIssuer].
  ///
  /// **Always pass this to [DpopTokenGenerator.generateForRequest]** when
  /// accessing protected resources, so the resource-level DPoP proof is signed
  /// by the same key whose thumbprint (`jkt`) is embedded in the access token.
  DpopKeyManager? _keyManager;

  /// Exposes the active [DpopKeyManager] for resource-request proof generation.
  ///
  /// Throws if called before [initForIssuer] / [login] / [loginFromWebId].
  DpopKeyManager get keyManager {
    if (_keyManager == null) {
      throw StateError(
        'SolidAuthManager has not been initialised. '
        'Call loginFromWebId() or initForIssuer() first.',
      );
    }
    return _keyManager!;
  }

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

  /// ### Issuer-aware login

  /// Resolves the OIDC issuer from [webIdOrIssuerUri], if the given value is a
  /// Web ID or returns the issuer value as is, initialises the underlying
  /// [OidcUserManager] with DPoP key binding, then triggers the
  /// Authorization Code + PKCE flow.
  ///
  /// Returns a [SolidAuthData] with the tokens and extracted WebID on success.
  Future<SolidAuthData?> authenticate(
    String webIdOrIssuerUri, {
    List<String>? scopeOverride,
  }) async {
    _log.info('Starting Solid-OIDC login for: $webIdOrIssuerUri');

    final issuerUri =
        await WebIdUtils.getIssuer(webIdOrIssuerUri, httpClient: httpClient);
    authData = await login(issuerUri: issuerUri, scopeOverride: scopeOverride);

    return authData;
  }

  /// Initialises for [issuerUri] and triggers the Authorization Code flow.
  ///
  /// Use this when you already know the issuer URI and don't have a WebID.
  Future<SolidAuthData> login({
    required String issuerUri,
    List<String>? scopeOverride,
  }) async {
    await initForIssuer(
      issuerUri,
      scopeOverride: scopeOverride,
    );

    // final effectiveConfig =
    //     scopeOverride != null ? _configWithScopes(scopeOverride) : config;

    // // Re-create the manager if scopes differ.
    // if (scopeOverride != null) {
    //   _oidcManager = SolidOidcManagerFactory.create(
    //     issuerUri: issuerUri,
    //     config: effectiveConfig,
    //   );
    //   await _oidcManager!.init();
    // }

    _log.fine('Launching Authorization Code + PKCE flow');
    final user = await _oidcManager!.loginAuthorizationCodeFlow();

    if (user == null) {
      throw const SolidAuthTokenException('Login cancelled or failed.');
    }

    return _mapUserToAuthData(user, issuerUri);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialises the [OidcUserManager] (and the [DpopKeyManager]) for
  /// [issuerUri] without triggering login.
  ///
  /// Useful for restoring a persisted session on app start:
  ///
  /// ```dart
  /// await auth.initForIssuer('https://solidcommunity.net');
  /// if (auth.currentAuthData != null) {
  ///   // Session restored — user is already logged in.
  /// }
  /// ```
  Future<void> initForIssuer(
    String issuerUri, {
    List<String>? scopeOverride,
    SolidProviderMetadata? metadata,
  }) async {
    final currentIssuer = _oidcManager?.discoveryDocument.issuer.toString();

    if (_oidcManager != null &&
        currentIssuer == issuerUri &&
        scopeOverride == null) {
      return; // already initialised for this issuer with default scopes
    }

    _log.fine('Initialising OidcUserManager for issuer: $issuerUri');

    final effectiveConfig =
        scopeOverride != null ? _configWithScopes(scopeOverride) : config;

    // SolidOidcManagerFactory.create returns a named record:
    //   (manager: OidcUserManager, keyManager: DpopKeyManager)
    //
    // The factory:
    //   1. Calls DpopKeyManager.getInstance() to obtain/generate the key pair.
    //   2. Registers an OidcHook(modifyRequest: ...) that injects a fresh
    //      DPoP proof on every token-endpoint POST.
    final (:manager, :keyManager) = await SolidOidcManagerFactory.create(
      issuerUri: issuerUri,
      config: effectiveConfig,
      metadata: metadata,
    );

    _oidcManager = manager;
    _keyManager = keyManager;

    await _oidcManager!.init();
    _log.fine('OidcUserManager ready!');
  }

  /// Logs out the user from the identity provider and clears local tokens.
  Future<void> logout() async {
    _log.info('Logging out');
    await _oidcManager?.logout();
    DpopKeyManager.clear(); // rotate key on logout for forward secrecy
    _keyManager = null;
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
    _keyManager = null;
  }

  // ── Token access ──────────────────────────────────────────────────────────

  /// Returns the current authenticated user as [SolidAuthData], or null
  /// if no session is active.
  SolidAuthData? get currentAuthData {
    final user = _oidcManager?.currentUser;
    if (user == null) return null;
    return _mapUserToAuthData(
      user,
      _oidcManager?.discoveryDocument.issuer.toString() ?? '',
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
                  oidcManager.discoveryDocument.issuer.toString(),
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
      _oidcManager?.discoveryDocument.issuer.toString() ?? '',
    );
  }

  /// Checks if a user is currently authenticated.
  ///
  /// This is a synchronous check of the current authentication state.
  /// For reactive UI updates, prefer using [isAuthenticatedNotifier].
  ///
  /// ## Return Value
  ///
  /// Returns `true` if a user is authenticated and has valid tokens,
  /// `false` otherwise.
  ///
  /// ## Example
  /// ```dart
  /// if (solidAuth.isAuthenticated) {
  ///   print('User is logged in as: ${solidAuth.currentWebId}');
  /// } else {
  ///   print('Please log in');
  /// }
  /// ```
  ///
  /// ## Note
  ///
  /// This method only checks if authentication data exists, not whether
  /// the tokens are still valid or if the server is reachable. Token
  /// validation happens automatically during API calls.
  bool get isAuthenticated {
    return _oidcManager != null && _oidcManager!.currentUser != null;
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  SolidAuthData _mapUserToAuthData(OidcUser user, String issuerUri) {
    final token = user.token;
    final claims = user.aggregatedClaims;

    final accessToken = token.accessToken;
    final idToken = token.idToken ?? '';
    final refreshToken = token.refreshToken;
    final webId = _extractWebId(claims) ?? user.uid ?? '';

    // Derive expiry: prefer explicit expiresAt, fall back to now + expires_in.
    final expiresAt = DateTime.now().add(token.expiresIn!);

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
