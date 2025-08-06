import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:solid_auth/src/oidc/solid_oidc_user_manager.dart';
export 'package:solid_auth/src/oidc/solid_oidc_user_manager.dart'
    show DPoP, UserAndWebId;

/// The default refresh behavior: refresh tokens 1 minute before they expire.
///
/// This matches the default behavior from the underlying OIDC library.
Duration? defaultRefreshBefore(OidcToken token) {
  return const Duration(minutes: 1);
}

final _log = Logger("solid_authentication_oidc");

/// Configuration settings for Solid authentication.
///
/// This class wraps and extends [OidcUserManagerSettings] with Solid-specific
/// functionality. Most fields correspond directly to properties in the underlying
/// OIDC library - see the [OIDC package documentation](https://bdaya-dev.github.io/oidc/oidc-usage/)
/// for detailed descriptions of these settings.
///
/// Most applications can use the default constructor without parameters,
/// which provides sensible defaults for typical Solid authentication scenarios.
///
/// ## Example
/// ```dart
/// // Use default settings
/// final settings = SolidAuthSettings();
///
/// // Customize specific settings
/// final customSettings = SolidAuthSettings(
///   strictJwtVerification: true,
///   expiryTolerance: Duration(minutes: 2),
///   prompt: ['consent'],
/// );
/// ```
class SolidAuthSettings {
  /// Creates authentication settings with the specified options.
  ///
  /// All parameters are optional and have sensible defaults for most use cases.
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

  /// Settings for requesting user information from the OIDC provider.
  ///
  /// See [OidcUserInfoSettings] in the OIDC package documentation.
  final OidcUserInfoSettings userInfoSettings;

  /// Whether JSON Web Tokens (JWTs) should be strictly verified.
  ///
  /// See [OidcUserManagerSettings.strictJwtVerification] in the OIDC package documentation.
  final bool strictJwtVerification;

  /// Whether to support offline authentication when the network is unavailable.
  ///
  /// See [OidcUserManagerSettings.supportOfflineAuth] in the OIDC package documentation.
  final bool supportOfflineAuth;

  /// Controls what prompts the user sees during authentication.
  ///
  /// See [OidcUserManagerSettings.prompt] in the OIDC package documentation.
  final List<String> prompt;

  /// How the authentication user interface should be displayed.
  ///
  /// See [OidcUserManagerSettings.display] in the OIDC package documentation.
  final String? display;

  /// Preferred languages for the authentication user interface.
  ///
  /// See [OidcUserManagerSettings.uiLocales] in the OIDC package documentation.
  final List<String>? uiLocales;

  /// Authentication Context Class Reference values that the client is requesting.
  ///
  /// See [OidcUserManagerSettings.acrValues] in the OIDC package documentation.
  final List<String>? acrValues;

  /// Maximum authentication age allowed.
  ///
  /// See [OidcUserManagerSettings.maxAge] in the OIDC package documentation.
  final Duration? maxAge;

  /// Additional parameters to include in authentication requests.
  ///
  /// See [OidcUserManagerSettings.extraAuthenticationParameters] in the OIDC package documentation.
  final Map<String, dynamic>? extraAuthenticationParameters;

  /// Additional HTTP headers to include in token requests.
  ///
  /// See [OidcUserManagerSettings.extraTokenHeaders] in the OIDC package documentation.
  final Map<String, String>? extraTokenHeaders;

  /// Additional parameters to include in token requests.
  ///
  /// See [OidcUserManagerSettings.extraTokenParameters] in the OIDC package documentation.
  final Map<String, dynamic>? extraTokenParameters;

  /// Additional parameters to include in token revocation requests.
  ///
  /// See [OidcUserManagerSettings.extraRevocationParameters] in the OIDC package documentation.
  final Map<String, dynamic>? extraRevocationParameters;

  /// Additional HTTP headers to include in token revocation requests.
  ///
  /// See [OidcUserManagerSettings.extraRevocationHeaders] in the OIDC package documentation.
  final Map<String, String>? extraRevocationHeaders;

  /// Time buffer for token expiry validation.
  ///
  /// See [OidcUserManagerSettings.expiryTolerance] in the OIDC package documentation.
  final Duration expiryTolerance;

  /// Configuration for OIDC session management features.
  ///
  /// See [OidcUserManagerSettings.sessionManagementSettings] in the OIDC package documentation.
  final OidcSessionManagementSettings sessionManagementSettings;

  /// Controls when access tokens are automatically refreshed.
  ///
  /// See [OidcUserManagerSettings.refreshBefore] in the OIDC package documentation.
  final OidcRefreshBeforeCallback? refreshBefore;

  /// Custom function to override token expiration times.
  ///
  /// See [OidcUserManagerSettings.getExpiresIn] in the OIDC package documentation.
  final Duration? Function(OidcTokenResponse tokenResponse)? getExpiresIn;

  /// Custom function to resolve WebID or issuer strings to issuer URIs.
  ///
  /// This function overrides the default WebID-to-issuer discovery process.
  /// See [GetIssuers] typedef for detailed documentation and examples.
  ///
  /// When `null`, the library uses the standard Solid WebID discovery process.
  final GetIssuers? getIssuers;

  /// Custom function to extract ID tokens from token responses.
  ///
  /// See [OidcUserManagerSettings.getIdToken] in the OIDC package documentation.
  final Future<String?> Function(OidcToken token)? getIdToken;

  /// Platform-specific configuration options.
  ///
  /// See [OidcUserManagerSettings.options] in the OIDC package documentation.
  final OidcPlatformSpecificOptions? options;

  /// Custom hooks to modify authentication behavior.
  ///
  /// See [OidcUserManagerSettings.hooks] in the OIDC package documentation.
  final OidcUserManagerHooks? hooks;

  /// Creates a copy of this settings object with the given fields replaced.
  ///
  /// This is useful for creating variations of settings without modifying
  /// the original object.
  ///
  /// ## Example
  /// ```dart
  /// final baseSettings = SolidAuthSettings();
  /// final strictSettings = baseSettings.copyWith(
  ///   strictJwtVerification: true,
  ///   expiryTolerance: Duration(seconds: 30),
  /// );
  /// ```
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

/// URI configuration for Solid authentication redirects.
///
/// This class configures the various redirect URIs used during the OIDC
/// authentication flow. Different URIs are used for different purposes:
///
/// - **redirectUri**: Where users are sent after successful authentication
/// - **postLogoutRedirectUri**: Where users are sent after logging out
/// - **frontChannelLogoutUri**: Used for single sign-out notifications
///
/// For most applications, you should use [SolidAuth.createUriSettings] to
/// generate appropriate settings automatically based on your platform.
class SolidAuthUriSettings {
  /// The URI where users will be redirected after successful authentication.
  ///
  /// This URI must be registered with your OIDC client configuration
  /// (e.g., in your client-profile.jsonld file for Solid).
  final Uri redirectUri;

  /// The URI where users will be redirected after logging out.
  ///
  /// This should typically be your app's main page or login screen.
  final Uri postLogoutRedirectUri;

  /// The URI used for front-channel logout notifications.
  ///
  /// When single sign-out is triggered from another application, the identity
  /// provider will make a request to this URI to notify your application
  /// that the user has been logged out.
  final Uri frontChannelLogoutUri;

  /// Configuration for listening to front-channel logout requests.
  ///
  /// Controls how the library listens for and handles front-channel logout
  /// notifications from the identity provider.
  final OidcFrontChannelRequestListeningOptions
      frontChannelRequestListeningOptions;

  /// Creates URI settings with the specified redirect URIs.
  ///
  /// All URIs must be properly registered with your OIDC client configuration.
  ///
  /// ## Example
  /// ```dart
  /// final uriSettings = SolidAuthUriSettings(
  ///   redirectUri: Uri.parse('https://myapp.com/auth/callback'),
  ///   postLogoutRedirectUri: Uri.parse('https://myapp.com/'),
  ///   frontChannelLogoutUri: Uri.parse('https://myapp.com/auth/logout'),
  /// );
  /// ```
  SolidAuthUriSettings({
    required this.redirectUri,
    required this.postLogoutRedirectUri,
    required this.frontChannelLogoutUri,
    this.frontChannelRequestListeningOptions =
        const OidcFrontChannelRequestListeningOptions(),
  });
}

/// Main class for authenticating with Solid pods using OpenID Connect.
///
/// [SolidAuth] provides a simplified, reactive interface for Solid authentication
/// that handles the complexity of OIDC flows, token management, and WebID discovery.
///
/// ## Key Features
///
/// - **Reactive Authentication State**: Use [isAuthenticatedNotifier] to reactively
///   update your UI based on authentication status
/// - **Automatic Session Restoration**: Persists authentication state across app restarts
/// - **DPoP Token Support**: Handles Demonstration of Proof-of-Possession tokens
///   required by Solid servers
/// - **Cross-Platform**: Works on web, mobile, and desktop with appropriate redirect handling
///
/// ## Basic Usage
///
/// ```dart
/// // Initialize SolidAuth
/// final solidAuth = SolidAuth(
///   oidcClientId: 'https://myapp.com/client-profile.jsonld',
///   appUrlScheme: 'myapp',
///   frontendRedirectUrl: Uri.parse('https://myapp.com/redirect.html'),
/// );
///
/// // Initialize and check for existing session
/// await solidAuth.init();
///
/// // Listen to authentication state changes
/// ValueListenableBuilder<bool>(
///   valueListenable: solidAuth.isAuthenticatedNotifier,
///   builder: (context, isAuthenticated, child) {
///     return isAuthenticated ? AuthenticatedView() : LoginView();
///   },
/// );
///
/// // Authenticate with a WebID or issuer
/// try {
///   final result = await solidAuth.authenticate('https://alice.solidcommunity.net/profile/card#me');
///   print('Authenticated as: ${result.webId}');
/// } catch (e) {
///   print('Authentication failed: $e');
/// }
/// ```
///
/// ## Authentication Parameters
///
/// The [oidcClientId] should point to a publicly accessible JSON-LD document
/// that describes your application according to the Solid OIDC specification.
/// This document must include:
///
/// - `client_id`: The same URL as the document location
/// - `redirect_uris`: List of allowed redirect URIs
/// - `grant_types`: Typically `["authorization_code", "refresh_token"]`
/// - `scope`: Required scopes like `"openid profile webid"`
///
/// ## Platform-Specific Behavior
///
/// - **Web**: Uses HTML redirect pages for authentication callbacks
/// - **Mobile/Desktop**: Uses custom URL schemes for deep linking
///
/// ## Security Considerations
///
/// - All redirect URIs must be registered in your client configuration
/// - The client configuration document must be served over HTTPS
/// - DPoP tokens are automatically generated to prevent token replay attacks
/// - Session data is stored securely using platform-appropriate mechanisms
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

  /// Creates a new SolidAuth instance with automatic redirect URI configuration.
  ///
  /// This is the recommended constructor for most applications as it automatically
  /// configures appropriate redirect URIs based on your platform and parameters.
  ///
  /// ## Parameters
  ///
  /// - [oidcClientId]: URL pointing to your public client identifier document
  ///   (client-profile.jsonld). This document must be accessible via HTTPS and
  ///   contain your OIDC client configuration including allowed redirect URIs.
  ///
  /// - [appUrlScheme]: Custom URL scheme for your application, used on mobile
  ///   and desktop platforms for deep linking. Should be unique to your app
  ///   (e.g., 'com.mycompany.myapp'). Not used on web platforms.
  ///
  /// - [frontendRedirectUrl]: The redirect URL for web browsers. This should
  ///   point to an HTML page that handles the OIDC callback. Must be registered
  ///   in your client configuration.
  ///
  /// - [settings]: Optional advanced configuration settings. Most apps can
  ///   use the defaults.
  ///
  /// - [store]: Optional custom storage implementation for tokens and session data.
  ///   Defaults to platform-appropriate secure storage.
  ///
  /// ## Redirect URI Registration
  ///
  /// The following URIs must be registered in your client-profile.jsonld:
  ///
  /// **For `redirect_uris`:**
  /// - Web: The exact [frontendRedirectUrl] you provide
  /// - Mobile/Desktop: `{appUrlScheme}://redirect`
  ///
  /// **For `post_logout_redirect_uris`:**
  /// - Web: The exact [frontendRedirectUrl] you provide
  /// - Mobile/Desktop: `{appUrlScheme}://logout`
  ///
  /// ## Example
  /// ```dart
  /// final solidAuth = SolidAuth(
  ///   oidcClientId: 'https://myapp.example.com/client-profile.jsonld',
  ///   appUrlScheme: 'com.mycompany.myapp',
  ///   frontendRedirectUrl: Uri.parse('https://myapp.example.com/auth/callback.html'),
  /// );
  /// ```
  ///
  /// ## Client Configuration Example
  /// Your client-profile.jsonld should look like:
  /// ```json
  /// {
  ///   "@context": "https://www.w3.org/ns/solid/oidc-context.jsonld",
  ///   "client_id": "https://myapp.example.com/client-profile.jsonld",
  ///   "client_name": "My Solid App",
  ///   "redirect_uris": [
  ///     "https://myapp.example.com/auth/callback.html",
  ///     "com.mycompany.myapp://redirect"
  ///   ],
  ///   "post_logout_redirect_uris": [
  ///     "https://myapp.example.com/auth/callback.html",
  ///     "com.mycompany.myapp://logout"
  ///   ],
  ///   "grant_types": ["authorization_code", "refresh_token"],
  ///   "scope": "openid webid offline_access profile"
  /// }
  /// ```
  ///
  /// ## Required Scopes
  ///
  /// The `scope` field in your client-profile.jsonld **must** include these required scopes:
  /// - `openid`: Required for OpenID Connect authentication
  /// - `webid`: Required for Solid WebID functionality
  /// - `offline_access`: Required for token refresh capability
  ///
  /// Additional scopes (like `profile`, `email`, etc.) can be included in the client
  /// profile and requested during authentication via the `scopes` parameter in [authenticate].
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

  /// Creates a SolidAuth instance with explicit redirect URI configuration.
  ///
  /// Use this constructor when you need full control over redirect URI configuration
  /// or when the automatic configuration from the main constructor doesn't meet
  /// your needs.
  ///
  /// ## Parameters
  ///
  /// - [oidcClientId]: URL pointing to your public client identifier document
  /// - [uriSettings]: Explicit configuration of all redirect URIs
  /// - [settings]: Optional advanced configuration settings
  /// - [store]: Optional custom storage implementation
  ///
  /// ## Example
  /// ```dart
  /// final uriSettings = SolidAuthUriSettings(
  ///   redirectUri: Uri.parse('https://myapp.com/auth/callback'),
  ///   postLogoutRedirectUri: Uri.parse('https://myapp.com/'),
  ///   frontChannelLogoutUri: Uri.parse('https://myapp.com/auth/logout'),
  /// );
  ///
  /// final solidAuth = SolidAuth.forRedirects(
  ///   oidcClientId: 'https://myapp.com/client-profile.jsonld',
  ///   uriSettings: uriSettings,
  /// );
  /// ```
  SolidAuth.forRedirects({
    required String oidcClientId,
    required SolidAuthUriSettings uriSettings,
    SolidAuthSettings? settings,
    OidcStore? store,
  })  : _oidcClientId = oidcClientId,
        _settings = settings ?? const SolidAuthSettings(),
        _store = store ?? OidcDefaultStore(),
        _uriSettings = uriSettings;

  /// The WebID of the currently authenticated user, if any.
  ///
  /// A WebID is a unique identifier for a person or agent in the Solid ecosystem.
  /// It's typically an HTTPS URL that points to the user's profile document.
  ///
  /// Returns `null` if no user is currently authenticated.
  ///
  /// ## Example
  /// ```dart
  /// print('Current user: ${solidAuth.currentWebId ?? 'Not authenticated'}');
  /// ```
  String? get currentWebId => _manager?.currentWebId;

  /// A [ValueListenable] that notifies when authentication state changes.
  ///
  /// This is the recommended way to reactively update your UI based on
  /// authentication status. The value is `true` when a user is authenticated
  /// and `false` otherwise.
  ///
  /// ## Example
  /// ```dart
  /// ValueListenableBuilder<bool>(
  ///   valueListenable: solidAuth.isAuthenticatedNotifier,
  ///   builder: (context, isAuthenticated, child) {
  ///     if (isAuthenticated) {
  ///       return Text('Welcome, ${solidAuth.currentWebId}!');
  ///     } else {
  ///       return LoginButton();
  ///     }
  ///   },
  /// );
  /// ```
  ///
  /// The notifier automatically updates when:
  /// - [authenticate] completes successfully
  /// - [logout] is called
  /// - [init] restores an existing session
  /// - Token refresh fails and the session becomes invalid
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

  /// Initializes the SolidAuth instance and attempts to restore any existing session.
  ///
  /// This method must be called before using any other authentication methods.
  /// It performs the following operations:
  ///
  /// 1. Initializes the secure storage system
  /// 2. Attempts to restore authentication parameters from previous sessions
  /// 3. Validates any existing tokens and session data
  /// 4. Updates the authentication state accordingly
  ///
  /// ## Return Value
  ///
  /// Returns `true` if an existing valid session was restored, `false` if no
  /// valid session exists and the user needs to authenticate.
  ///
  /// ## Example
  /// ```dart
  /// final solidAuth = SolidAuth(/* ... */);
  ///
  /// // Initialize and check for existing session
  /// final hasExistingSession = await solidAuth.init();
  ///
  /// if (hasExistingSession) {
  ///   print('User already authenticated: ${solidAuth.currentWebId}');
  /// } else {
  ///   print('User needs to log in');
  /// }
  /// ```
  ///
  /// ## Error Handling
  ///
  /// This method handles errors gracefully. If stored session data is corrupted
  /// or invalid, it will be cleared and the method will return `false` rather
  /// than throwing an exception.
  ///
  /// ## Thread Safety
  ///
  /// This method is safe to call multiple times, though subsequent calls after
  /// the first will have no effect.
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

  /// Authenticates a user with their WebID or identity provider.
  ///
  /// This method handles the complete OIDC authentication flow, including:
  /// - WebID discovery (if a WebID is provided)
  /// - Identity provider discovery and configuration
  /// - Browser-based authorization flow
  /// - Token exchange and validation
  /// - Session persistence for future use
  ///
  /// ## Parameters
  ///
  /// - [webIdOrIssuerUri]: Either a WebID (e.g., 'https://alice.solidcommunity.net/profile/card#me')
  ///   or an identity provider URI (e.g., 'https://solidcommunity.net').
  ///   If a WebID is provided, the library will automatically discover the
  ///   associated identity provider.
  ///
  /// - [scopes]: Additional OAuth2 scopes to request beyond the default Solid
  ///   scopes ('openid', 'webid', 'offline_access'). These additional scopes must
  ///   also be declared in your client-profile.jsonld. Common additional scopes
  ///   include 'profile' for extended profile information.
  ///
  /// ## Return Value
  ///
  /// Returns a [UserAndWebId] object containing:
  /// - `user`: The OIDC user information including tokens and claims
  /// - `webId`: The validated WebID of the authenticated user
  ///
  /// ## Examples
  ///
  /// ```dart
  /// // Authenticate with a WebID
  /// try {
  ///   final result = await solidAuth.authenticate(
  ///     'https://alice.solidcommunity.net/profile/card#me'
  ///   );
  ///   print('Authenticated as: ${result.webId}');
  ///   print('Access token expires: ${result.user.token.expiresAt}');
  /// } catch (e) {
  ///   print('Authentication failed: $e');
  /// }
  ///
  /// // Authenticate with additional scopes
  /// final result = await solidAuth.authenticate(
  ///   'https://solidcommunity.net',
  ///   scopes: ['profile', 'email'],
  /// );
  /// ```
  ///
  /// ## Error Handling
  ///
  /// This method may throw various exceptions:
  /// - Network errors if the identity provider is unreachable
  /// - Authentication errors if the user cancels or credentials are invalid
  /// - Configuration errors if redirect URIs are not properly registered
  /// - Security errors if token validation fails
  ///
  /// ## Session Management
  ///
  /// Upon successful authentication, the session is automatically persisted
  /// and will be restored on subsequent app launches via [init].
  ///
  /// If a user is already authenticated, calling this method will first log
  /// out the current user before beginning the new authentication flow.
  ///
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
      return UserAndWebId(oidcUser: _manager!.currentUser!, webId: webId);
    }

    _log.info(
        "Beginning full authentication flow for WebID: $webIdOrIssuerUri");
    // No existing session, perform full authentication flow
    final authResult = await _manager!.loginAuthorizationCodeFlow();
    if (authResult == null) {
      throw Exception('OIDC authentication failed: no user returned');
    }

    final oidcUser = authResult.oidcUser;
    final webId = authResult.webId;

    // Persist authentication parameters for session restoration
    await _persistAuthParameters(webIdOrIssuerUri, scopes);

    _log.info(
      'OIDC User authenticated: ${oidcUser.uid ?? 'unknown'} for webId: $webId',
    );

    _updateAuthenticationState();
    return authResult;
  }

  /// Creates appropriate URI settings for the current platform.
  ///
  /// This static method automatically configures redirect URIs based on the
  /// platform your app is running on:
  ///
  /// - **Web Platform**: Uses the provided [frontendRedirectUrl] for all redirects
  /// - **Mobile/Desktop**: Creates custom URL scheme redirects using [appUrlScheme]
  ///
  /// ## Parameters
  ///
  /// - [appUrlScheme]: The custom URL scheme for your app (e.g., 'com.mycompany.myapp').
  ///   Used only on mobile and desktop platforms. Should be unique and registered
  ///   with your app's platform configuration.
  ///
  /// - [frontendRedirectUrl]: The web URL for authentication callbacks. Used only
  ///   on web platforms. Should point to an HTML page that handles OIDC redirects.
  ///
  /// ## Generated URIs
  ///
  /// For **web platforms**:
  /// - `redirectUri`: Same as frontendRedirectUrl
  /// - `postLogoutRedirectUri`: Same as frontendRedirectUrl
  /// - `frontChannelLogoutUri`: frontendRedirectUrl with '?requestType=front-channel-logout'
  ///
  /// For **mobile/desktop platforms**:
  /// - `redirectUri`: `{appUrlScheme}://redirect`
  /// - `postLogoutRedirectUri`: `{appUrlScheme}://logout`
  /// - `frontChannelLogoutUri`: `{appUrlScheme}://logout`
  ///
  /// ## Client Registration
  ///
  /// All generated URIs must be registered in your OIDC client configuration:
  ///
  /// ```json
  /// {
  ///   "redirect_uris": [
  ///     "https://myapp.com/auth/callback.html",
  ///     "com.mycompany.myapp://redirect"
  ///   ],
  ///   "post_logout_redirect_uris": [
  ///     "https://myapp.com/auth/callback.html",
  ///     "com.mycompany.myapp://logout"
  ///   ]
  /// }
  /// ```
  ///
  /// ## Return Value
  ///
  /// Returns a [SolidAuthUriSettings] object with platform-appropriate redirect URIs.
  ///
  /// ## Example
  /// ```dart
  /// final uriSettings = SolidAuth.createUriSettings(
  ///   appUrlScheme: 'com.mycompany.myapp',
  ///   frontendRedirectUrl: Uri.parse('https://myapp.com/auth/callback.html'),
  /// );
  ///
  /// // Use with explicit constructor
  /// final solidAuth = SolidAuth.forRedirects(
  ///   oidcClientId: 'https://myapp.com/client-profile.jsonld',
  ///   uriSettings: uriSettings,
  /// );
  /// ```
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

  /// Generates a DPoP (Demonstration of Proof-of-Possession) token for API requests.
  ///
  /// DPoP tokens are required by Solid servers to prove that the client making
  /// an API request is the same client that was issued the access token. This
  /// prevents token theft and replay attacks.
  ///
  /// ## Parameters
  ///
  /// - [url]: The complete URL of the API endpoint you're about to call
  /// - [method]: The HTTP method ('GET', 'POST', 'PUT', 'DELETE', etc.)
  ///
  /// ## Return Value
  ///
  /// Returns a [DPoP] object containing:
  /// - `dpopToken`: The DPoP JWT token
  /// - `accessToken`: The OAuth2 access token
  /// - `httpHeaders()`: Convenience method to get properly formatted HTTP headers
  ///
  /// ## Example
  /// ```dart
  /// // Generate DPoP token for a GET request
  /// final dpop = solidAuth.genDpopToken(
  ///   'https://alice.solidcommunity.net/profile/card',
  ///   'GET'
  /// );
  ///
  /// // Use with HTTP client
  /// final response = await http.get(
  ///   Uri.parse('https://alice.solidcommunity.net/profile/card'),
  ///   headers: {
  ///     ...dpop.httpHeaders(),
  ///     'Content-Type': 'text/turtle',
  ///   },
  /// );
  ///
  /// // Or set headers manually
  /// final response = await http.get(
  ///   Uri.parse('https://alice.solidcommunity.net/profile/card'),
  ///   headers: {
  ///     'Authorization': 'DPoP ${dpop.accessToken}',
  ///     'DPoP': dpop.dpopToken,
  ///     'Content-Type': 'text/turtle',
  ///   },
  /// );
  /// ```
  ///
  /// ## Requirements
  ///
  /// - User must be authenticated (call [authenticate] first)
  /// - The URL must be the exact URL you're going to call
  /// - The method must match the actual HTTP method used
  /// - Each DPoP token can only be used once for the specific URL/method combination
  ///
  /// ## Security Notes
  ///
  /// - DPoP tokens are tied to the specific URL and HTTP method
  /// - Each token includes a unique nonce and timestamp
  /// - Tokens should be generated immediately before making the API call
  /// - Never reuse DPoP tokens across different requests
  ///
  /// ## Throws
  ///
  /// Throws an exception if no user is currently authenticated.
  DPoP genDpopToken(String url, String method) {
    return _manager!.genDpopToken(url, method);
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
    return _manager != null && _manager!.currentUser != null;
  }

  /// Logs out the current user and clears all authentication data.
  ///
  /// This method performs a complete logout process:
  /// 1. Notifying the identity provider of the logout (if supported and reachable)
  /// 2. Clearing all stored authentication data locally
  /// 3. Updating the authentication state
  ///
  /// **Note**: Token revocation depends on the underlying OIDC library implementation
  /// and identity provider support. The library will attempt to notify the provider
  /// but cannot guarantee that tokens are revoked on the server side.
  ///
  /// ## Example
  /// ```dart
  /// await solidAuth.logout();
  /// print('User logged out successfully');
  /// ```
  ///
  /// ## Behavior
  ///
  /// - If no user is currently authenticated, this method completes successfully
  ///   without error
  /// - Network errors during logout (e.g., unable to reach identity provider)
  ///   are logged but don't prevent local cleanup
  /// - The [isAuthenticatedNotifier] will be updated to reflect the logout
  /// - All stored session data is permanently removed locally
  ///
  /// ## Post-Logout State
  ///
  /// After calling logout:
  /// - [isAuthenticated] returns `false`
  /// - [currentWebId] returns `null`
  /// - [genDpopToken] will throw an exception
  /// - [authenticate] can be called to log in a new user
  ///
  /// ## Platform Behavior
  ///
  /// On some platforms, logout may open a browser window to complete the
  /// logout process with the identity provider. This ensures single sign-out
  /// works correctly if the user has multiple applications authenticated
  /// with the same provider.
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
  /// - Switching to a different authentication provider (after logout)
  ///
  /// If you want to log out the user and clear stored data, call logout() first.
  /// This method is safe to call multiple times.
  Future<void> dispose() async {
    _isAuthenticatedNotifier.dispose();
    await _manager?.dispose();
    _manager = null;
  }
}
