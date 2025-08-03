import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:solid_auth/src/oidc/solid_oidc_user_manager.dart';
export 'package:solid_auth/src/oidc/solid_oidc_user_manager.dart'
    show DPoP, UserAndWebId;

final _log = Logger("solid_authentication_oidc");

class SolidAuthSettings {
  ///
  const SolidAuthSettings({
    this.uiLocales,
    this.extraTokenHeaders,
    this.prompt = const [],
    this.display,
    this.acrValues,
    this.maxAge,
    this.extraAuthenticationParameters,
    this.expiryTolerance = const Duration(minutes: 1),
    this.extraTokenParameters,
    this.options,
    this.userInfoSettings = const OidcUserInfoSettings(),
    this.refreshBefore = defaultRefreshBefore,
    this.strictJwtVerification = false,
    this.getExpiresIn,
    this.sessionManagementSettings = const OidcSessionManagementSettings(),
    this.getIdToken,
    this.supportOfflineAuth = false,
    this.hooks,
    this.extraRevocationParameters,
    this.extraRevocationHeaders,
    this.getIssuers,
  });

  /// Settings to control using the user_info endpoint.
  final OidcUserInfoSettings userInfoSettings;

  /// whether JWTs are strictly verified.
  ///
  /// If set to true, the library will throw an exception if a JWT is invalid.
  final bool strictJwtVerification;

  /// Whether to support offline authentication or not.
  ///
  /// When this option is enabled, expired tokens will NOT be removed if the
  /// server can't be contacted
  ///
  /// This parameter is disabled by default due to security concerns.
  final bool supportOfflineAuth;

  /// see [OidcAuthorizeRequest.prompt].
  final List<String> prompt;

  /// see [OidcAuthorizeRequest.display].
  final String? display;

  /// see [OidcAuthorizeRequest.uiLocales].
  final List<String>? uiLocales;

  /// see [OidcAuthorizeRequest.acrValues].
  final List<String>? acrValues;

  /// see [OidcAuthorizeRequest.maxAge]
  final Duration? maxAge;

  /// see [OidcAuthorizeRequest.extra]
  final Map<String, dynamic>? extraAuthenticationParameters;

  /// see [OidcTokenRequest.extra]
  final Map<String, String>? extraTokenHeaders;

  /// see [OidcTokenRequest.extra]
  final Map<String, dynamic>? extraTokenParameters;

  /// see [OidcRevocationRequest.extra]
  final Map<String, dynamic>? extraRevocationParameters;

  /// Extra headers to send with the revocation request.
  final Map<String, String>? extraRevocationHeaders;

  /// see [OidcIdTokenVerificationOptions.expiryTolerance].
  final Duration expiryTolerance;

  /// Settings related to the session management spec.
  final OidcSessionManagementSettings sessionManagementSettings;

  /// How early the token gets refreshed.
  ///
  /// for example:
  ///
  /// - if `Duration.zero` is returned, the token gets refreshed once it's expired.
  /// - (default) if `Duration(minutes: 1)` is returned, it will refresh the token 1 minute before it expires.
  /// - if `null` is returned, automatic refresh is disabled.
  final OidcRefreshBeforeCallback? refreshBefore;

  /// overrides a token's expires_in value.
  final Duration? Function(OidcTokenResponse tokenResponse)? getExpiresIn;

  /// pass this function to control how a webIdOrIssuer is resoled to the issuer URI.
  final GetIssuers? getIssuers;

  /// pass this function to control how an `id_token` is fetched from a
  /// token response.
  ///
  /// This can be used to trick the user manager into using a JWT `access_token`
  /// as an `id_token` for example.
  final Future<String?> Function(OidcToken token)? getIdToken;

  /// platform-specific options.
  final OidcPlatformSpecificOptions? options;

  /// Customized hooks to modify the user manager behavior.
  final OidcUserManagerHooks? hooks;

  /// Creates a copy of this [SolidOidcUserManagerSettings] with the given fields replaced with new values.
  SolidAuthSettings copyWith({
    List<String>? uiLocales,
    Map<String, String>? extraTokenHeaders,
    List<String>? prompt,
    String? display,
    List<String>? acrValues,
    Duration? maxAge,
    Map<String, dynamic>? extraAuthenticationParameters,
    Duration? expiryTolerance,
    Map<String, dynamic>? extraTokenParameters,
    OidcPlatformSpecificOptions? options,
    OidcUserInfoSettings? userInfoSettings,
    OidcRefreshBeforeCallback? refreshBefore,
    bool? strictJwtVerification,
    Duration? Function(OidcTokenResponse tokenResponse)? getExpiresIn,
    OidcSessionManagementSettings? sessionManagementSettings,
    Future<String?> Function(OidcToken token)? getIdToken,
    bool? supportOfflineAuth,
    OidcUserManagerHooks? hooks,
    Map<String, dynamic>? extraRevocationParameters,
    Map<String, String>? extraRevocationHeaders,
    GetIssuers? getIssuers,
  }) {
    return SolidAuthSettings(
      uiLocales: uiLocales ?? this.uiLocales,
      extraTokenHeaders: extraTokenHeaders ?? this.extraTokenHeaders,
      prompt: prompt ?? this.prompt,
      display: display ?? this.display,
      acrValues: acrValues ?? this.acrValues,
      maxAge: maxAge ?? this.maxAge,
      extraAuthenticationParameters:
          extraAuthenticationParameters ?? this.extraAuthenticationParameters,
      expiryTolerance: expiryTolerance ?? this.expiryTolerance,
      extraTokenParameters: extraTokenParameters ?? this.extraTokenParameters,
      options: options ?? this.options,
      userInfoSettings: userInfoSettings ?? this.userInfoSettings,
      refreshBefore: refreshBefore ?? this.refreshBefore,
      strictJwtVerification:
          strictJwtVerification ?? this.strictJwtVerification,
      getExpiresIn: getExpiresIn ?? this.getExpiresIn,
      sessionManagementSettings:
          sessionManagementSettings ?? this.sessionManagementSettings,
      getIdToken: getIdToken ?? this.getIdToken,
      supportOfflineAuth: supportOfflineAuth ?? this.supportOfflineAuth,
      hooks: hooks ?? this.hooks,
      extraRevocationParameters:
          extraRevocationParameters ?? this.extraRevocationParameters,
      extraRevocationHeaders:
          extraRevocationHeaders ?? this.extraRevocationHeaders,
      getIssuers: getIssuers ?? this.getIssuers,
    );
  }
}

class SolidAuthUriSettings {
  final Uri redirectUri;
  final Uri postLogoutRedirectUri;
  final Uri frontChannelLogoutUri;
  final OidcFrontChannelRequestListeningOptions
      frontChannelRequestListeningOptions;
  SolidAuthUriSettings({
    required this.redirectUri,
    required this.postLogoutRedirectUri,
    required this.frontChannelLogoutUri,
    this.frontChannelRequestListeningOptions =
        const OidcFrontChannelRequestListeningOptions(),
  });
}

class SolidAuth {
  SolidOidcUserManager? _manager;
  final ValueNotifier<bool> _isAuthenticatedNotifier =
      ValueNotifier<bool>(false);

  final OidcStore _store;
  final String _oidcClientId;
  final SolidAuthSettings _settings;
  final SolidAuthUriSettings _uriSettings;
  // Storage keys for persisting authentication parameters
  static const String _webIdOrIssuerKey = 'solid_auth_webid_or_issuer';
  static const String _scopesKey = 'solid_auth_scopes';

  SolidAuth({
    required String oidcClientId,
    required String appUrlScheme,
    required Uri frontendRedirectUrl,
    SolidAuthSettings? settings,
    OidcStore? store,
  })  : _oidcClientId = oidcClientId,
        _settings = settings ?? const SolidAuthSettings(),
        _uriSettings = SolidAuth.createUriSettings(
          appUrlScheme: appUrlScheme,
          frontendRedirectUrl: frontendRedirectUrl,
        ),
        _store = store ?? OidcDefaultStore();

  SolidAuth.forRedirects({
    required String oidcClientId,
    required SolidAuthUriSettings uriSettings,
    SolidAuthSettings? settings,
    OidcStore? store,
  })  : _oidcClientId = oidcClientId,
        _settings = settings ?? const SolidAuthSettings(),
        _store = store ?? OidcDefaultStore(),
        _uriSettings = uriSettings;

  String? get currentWebId => _manager?.currentWebId;

  /// ValueListenable that notifies when authentication state changes
  ValueListenable<bool> get isAuthenticatedNotifier => _isAuthenticatedNotifier;

  /// Updates the authentication state and notifies listeners
  void _updateAuthenticationState() {
    final newState = _manager != null && _manager!.currentUser != null;
    if (_isAuthenticatedNotifier.value != newState) {
      _log.fine(
          'Authentication state changed: ${_isAuthenticatedNotifier.value} => $newState');
      _isAuthenticatedNotifier.value = newState;
    }
  }

  Future<bool> init() async {
    await _store.init();

    // Try to restore authentication parameters from storage
    final webIdOrIssuer = await _store.get(
      OidcStoreNamespace.secureTokens,
      key: _webIdOrIssuerKey,
    );

    final scopesJson = await _store.get(
      OidcStoreNamespace.secureTokens,
      key: _scopesKey,
    );

    if (webIdOrIssuer != null && scopesJson != null) {
      try {
        final scopes = List<String>.from(jsonDecode(scopesJson));
        _manager =
            await _createAndInitializeManager(webIdOrIssuer, scopes: scopes);

        // Verify the manager actually has a valid session
        if (_manager?.currentUser != null) {
          _log.info(
            'Successfully restored session for webIdOrIssuer: $webIdOrIssuer',
          );
          _updateAuthenticationState();
          return isAuthenticated;
        } else {
          _log.info('Stored parameters found but no valid session exists');
          await _clearStoredParameters();
        }
      } catch (e) {
        _log.warning('Failed to restore session with stored parameters: $e');
        await _clearStoredParameters();
      }
    }

    _log.info('No valid session found during initialization');
    _updateAuthenticationState();
    return false;
  }

  /// Clears stored authentication parameters
  Future<void> _clearStoredParameters() async {
    await _store.remove(
      OidcStoreNamespace.secureTokens,
      key: _webIdOrIssuerKey,
    );
    await _store.remove(OidcStoreNamespace.secureTokens, key: _scopesKey);
  }

  /// Persists authentication parameters for session restoration
  Future<void> _persistAuthParameters(
    String webIdOrIssuer,
    List<String> scopes,
  ) async {
    await _store.set(
      OidcStoreNamespace.secureTokens,
      key: _webIdOrIssuerKey,
      value: webIdOrIssuer,
    );
    await _store.set(
      OidcStoreNamespace.secureTokens,
      key: _scopesKey,
      value: jsonEncode(scopes),
    );
  }

  Future<UserAndWebId> authenticate(String webIdOrIssuerUri,
      {List<String> scopes = const []}) async {
    // Clean up any existing manager
    if (_manager != null) {
      await logout();
    }

    // Create and initialize manager with new parameters
    _manager =
        await _createAndInitializeManager(webIdOrIssuerUri, scopes: scopes);

    // Check if there's already a valid session (from cached tokens)
    if (_manager!.currentUser != null && _manager!.currentWebId != null) {
      final webId = _manager!.currentWebId!;
      // Persist the parameters for future restoration
      await _persistAuthParameters(webIdOrIssuerUri, scopes);

      _log.info('Using restored session for WebID: $webId');
      _updateAuthenticationState();
      return UserAndWebId(user: _manager!.currentUser!, webId: webId);
    }

    _log.info(
        "Beginning full authentication flow for WebID: $webIdOrIssuerUri");
    // No existing session, perform full authentication flow
    final authResult = await _manager!.loginAuthorizationCodeFlow();
    if (authResult == null) {
      throw Exception('OIDC authentication failed: no user returned');
    }

    final oidcUser = authResult.user;
    final webId = authResult.webId;

    // Persist authentication parameters for session restoration
    await _persistAuthParameters(webIdOrIssuerUri, scopes);

    _log.info(
      'OIDC User authenticated: ${oidcUser.uid ?? 'unknown'} for webId: $webId',
    );

    _updateAuthenticationState();
    return authResult;
  }

  static SolidAuthUriSettings createUriSettings({
    required String appUrlScheme,
    required Uri frontendRedirectUrl,
  }) {
    if (kIsWeb) {
      // Web platform uses HTML redirect page
      final htmlPageLink = frontendRedirectUrl;

      return SolidAuthUriSettings(
          redirectUri: htmlPageLink,
          postLogoutRedirectUri: htmlPageLink,
          frontChannelLogoutUri: htmlPageLink.replace(
            queryParameters: {
              ...htmlPageLink.queryParameters,
              'requestType': 'front-channel-logout',
            },
          ));
    } else {
      return SolidAuthUriSettings(
        redirectUri: Uri.parse('${appUrlScheme}://redirect'),
        postLogoutRedirectUri: Uri.parse('${appUrlScheme}://logout'),
        frontChannelLogoutUri: Uri.parse('${appUrlScheme}://logout'),
      );
    }
  }

  Future<SolidOidcUserManager> _createAndInitializeManager(
      String webIdOrIssuerUri,
      {List<String> scopes = const []}) async {
    var manager = SolidOidcUserManager(
        clientId: _oidcClientId,
        webIdOrIssuer: webIdOrIssuerUri,
        store: _store,
        settings: SolidOidcUserManagerSettings(
          redirectUri: _uriSettings.redirectUri,
          postLogoutRedirectUri: _uriSettings.postLogoutRedirectUri,
          frontChannelLogoutUri: _uriSettings.frontChannelLogoutUri,
          frontChannelRequestListeningOptions:
              _uriSettings.frontChannelRequestListeningOptions,
          acrValues: _settings.acrValues,
          display: _settings.display,
          expiryTolerance: _settings.expiryTolerance,
          extraAuthenticationParameters:
              _settings.extraAuthenticationParameters,
          extraRevocationHeaders: _settings.extraRevocationHeaders,
          extraRevocationParameters: _settings.extraRevocationParameters,
          extraScopes: scopes,
          extraTokenHeaders: _settings.extraTokenHeaders,
          extraTokenParameters: _settings.extraTokenParameters,
          getExpiresIn: _settings.getExpiresIn,
          getIdToken: _settings.getIdToken,
          getIssuers: _settings.getIssuers,
          hooks: _settings.hooks,
          maxAge: _settings.maxAge,
          options: _settings.options,
          prompt: _settings.prompt,
          refreshBefore: _settings.refreshBefore,
          sessionManagementSettings: _settings.sessionManagementSettings,
          strictJwtVerification: _settings.strictJwtVerification,
          supportOfflineAuth: _settings.supportOfflineAuth,
          userInfoSettings: _settings.userInfoSettings,
          uiLocales: _settings.uiLocales,
        ));

    await manager.init();
    return manager;
  }

  DPoP genDpopToken(String url, String method) {
    return _manager!.genDpopToken(url, method);
  }

  bool get isAuthenticated {
    return _manager != null && _manager!.currentUser != null;
  }

  Future<void> logout() async {
    await _manager?.logout();
    await _manager?.dispose();
    _manager = null;

    // Clear stored authentication parameters
    await _clearStoredParameters();

    _updateAuthenticationState();
  }

  /// Dispose of resources when SolidAuth is no longer needed.
  ///
  /// This method cleans up internal resources (ValueNotifier) but does NOT
  /// clear stored authentication data or logout the user.
  ///
  /// Use cases:
  /// - App shutdown or widget disposal
  /// - Switching to a different authentication provider
  ///
  /// If you want to log out the user and clear stored data, call logout() first.
  /// This method is safe to call multiple times.
  Future<void> dispose() async {
    _isAuthenticatedNotifier.dispose();
    await _manager?.dispose();
    _manager = null;
  }
}
