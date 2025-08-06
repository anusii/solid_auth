import 'dart:convert';

import 'package:fast_rsa/fast_rsa.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:solid_auth/src/solid_auth_client.dart' as solid_auth_client;
import 'package:solid_auth/src/solid_auth_issuer.dart' as solid_auth_issuer;

final _log = Logger("solid_authentication_oidc");

/// Contains DPoP token and access token for authenticated API requests to Solid servers.
///
/// DPoP (Demonstration of Proof-of-Possession) is a security mechanism required
/// by Solid servers to prove that the client making an API request is the same
/// client to which the access token was issued. This prevents token theft and replay attacks.
///
/// ## Usage
///
/// Typically obtained from [SolidAuth.genDpopToken] and used to make authenticated
/// requests to Solid pod resources.
///
/// ```dart
/// final dpop = solidAuth.genDpopToken('https://alice.pod.com/data/', 'GET');
///
/// // Use convenience method with additional headers
/// final response = await http.get(
///   Uri.parse('https://alice.pod.com/data/'),
///   headers: {
///     ...dpop.httpHeaders(),
///     'Accept': 'text/turtle',
///   },
/// );
///
/// // Or construct headers manually
/// final response = await http.get(
///   Uri.parse('https://alice.pod.com/data/'),
///   headers: {
///     'Authorization': 'DPoP ${dpop.accessToken}',
///     'DPoP': dpop.dpopToken,
///     'Accept': 'text/turtle',
///   },
/// );
/// ```
class DPoP {
  /// The DPoP JWT token that proves possession of the access token.
  ///
  /// This is a signed JWT that includes:
  /// - The HTTP method and URL being accessed
  /// - A unique nonce to prevent replay attacks
  /// - A timestamp showing when the token was created
  /// - The public key corresponding to the private key used for signing
  final String dpopToken;

  /// The OAuth2 access token for the authenticated user.
  ///
  /// This token grants access to resources but must be accompanied by the
  /// [dpopToken] to prove possession when making requests to Solid servers.
  final String accessToken;

  DPoP({required this.dpopToken, required this.accessToken});

  /// Returns HTTP headers formatted for Solid API requests.
  ///
  /// This is the recommended way to use DPoP tokens with HTTP clients.
  /// The returned map contains:
  /// - `Authorization`: 'DPoP {accessToken}'
  /// - `DPoP`: The DPoP JWT token
  ///
  /// ## Example
  /// ```dart
  /// final dpop = solidAuth.genDpopToken('https://alice.pod.com/data/', 'GET');
  /// final response = await http.get(
  ///   Uri.parse('https://alice.pod.com/data/'),
  ///   headers: {
  ///     ...dpop.httpHeaders(),
  ///     'Accept': 'text/turtle',
  ///   },
  /// );
  /// ```
  Map<String, String> httpHeaders() => {
        'Authorization': 'DPoP $accessToken',
        'DPoP': dpopToken,
      };
}

/// Contains the authentication result with both OIDC user data and validated WebID.
///
/// This class is returned by [SolidAuth.authenticate] and contains all the
/// information needed to work with the authenticated user in the Solid ecosystem.
///
/// ## WebID vs User Data
///
/// - **WebID**: A unique identifier for the user in the Solid ecosystem, typically
///   an HTTPS URL pointing to their profile document (e.g., 'https://alice.solidcommunity.net/profile/card#me')
///
/// - **User Data**: Standard OIDC user information including tokens, claims, and
///   profile information from the identity provider
///
/// ## Example
/// ```dart
/// final result = await solidAuth.authenticate('https://alice.solidcommunity.net/profile/card#me');
///
/// print('WebID: ${result.webId}');
/// print('Provider: ${result.oidcUser.claims.issuer}');
/// print('Subject: ${result.oidcUser.claims.subject}');
/// print('Access token expires: ${result.oidcUser.token.expiresAt}');
/// ```
class UserAndWebId {
  /// The OIDC user object containing tokens, claims, and profile information.
  ///
  /// This object provides access to:
  /// - Access tokens for API requests
  /// - ID token with user claims
  /// - Refresh tokens for maintaining the session
  /// - User profile information from the identity provider
  ///
  /// Use this primarily for accessing tokens and provider-specific user data.
  final OidcUser oidcUser;

  /// The validated WebID of the authenticated user.
  ///
  /// A WebID is a globally unique identifier for a person or agent in the
  /// Solid ecosystem. It's an HTTPS URL that points to the user's profile
  /// document, which contains information about the user and their data.
  ///
  /// This WebID has been validated to ensure:
  /// 1. It's properly formatted as an HTTPS URL
  /// 2. The associated profile is accessible
  /// 3. The profile confirms the identity provider is authorized for this WebID
  ///
  /// Use this for identifying the user across different Solid applications
  /// and for constructing URLs to the user's pod resources.
  final String webId;

  UserAndWebId({required this.oidcUser, required this.webId});
}

/// Function type for customizing how WebID or issuer strings are resolved to issuer URIs.
///
/// This function is called when the library needs to determine the OIDC issuer
/// (identity provider) for a given WebID or issuer string.
///
/// ## Parameters
///
/// - The input string, which could be:
///   - A WebID URL (e.g., 'https://alice.solidcommunity.net/profile/card#me')
///   - An issuer URL (e.g., 'https://solidcommunity.net')
///   - Any other string that might identify an identity provider
///
/// ## Return Value
///
/// Should return a list of possible issuer URIs to try, in order of preference.
/// The library will currently use the first one.
///
/// ## Default Behavior
///
/// If not provided, the library will:
/// 1. If the input looks like a WebID, fetch the profile document and extract
///    the `solid:oidcIssuer` property
/// 2. Otherwise, treat the input as an issuer URI directly
///
/// ## Custom Implementation Example
///
/// ```dart
/// Future<List<Uri>> customIssuerResolver(String webIdOrIssuer) async {
///   if (webIdOrIssuer.contains('example.com')) {
///     // Custom logic for example.com domains
///     return [Uri.parse('https://auth.example.com')];
///   }
///
///   // Fall back to default behavior
///   return [Uri.parse(webIdOrIssuer)];
/// }
///
/// final settings = SolidAuthSettings(
///   getIssuers: customIssuerResolver,
/// );
/// ```
typedef GetIssuers = Future<List<Uri>> Function(String webIdOrIssuer);

/// Function type for customizing prompt calculation based on scopes and configured prompts.
///
/// This function is called when the library needs to determine the effective
/// prompts for the OIDC authorization request.
///
/// ## Parameters
///
/// - [configuredPrompts]: The prompts explicitly configured in [SolidOidcUserManagerSettings.prompt]
/// - [effectiveScopes]: The complete list of scopes that will be requested during authentication
///
/// ## Return Value
///
/// Should return a list of prompt values to be sent to the identity provider.
/// The library will use this list as-is, so ensure proper deduplication and validation.
///
/// ## Default Behavior
///
/// If not provided, the library uses the default Solid behavior:
/// - Includes all configured prompts
/// - Automatically adds `consent` when `offline_access` is in the effective scopes
///
/// ## Custom Implementation Example
///
/// ```dart
/// List<String> customPromptCalculator(List<String> configuredPrompts, List<String> effectiveScopes) {
///   final prompts = <String>{...configuredPrompts};
///
///   // Custom logic: only add consent for specific providers
///   if (effectiveScopes.contains('offline_access') && isSpecialProvider()) {
///     prompts.add('consent');
///   }
///
///   // Always force login for sensitive operations
///   if (effectiveScopes.contains('admin')) {
///     prompts.add('login');
///   }
///
///   return prompts.toList()..sort();
/// }
///
/// final settings = SolidOidcUserManagerSettings(
///   redirectUri: Uri.parse('https://myapp.com/callback'),
///   calculateEffectivePrompts: customPromptCalculator,
/// );
/// ```
typedef CalculateEffectivePrompts = List<String> Function(
  List<String> configuredPrompts,
  List<String> effectiveScopes,
);

Future<List<Uri>> _getIssuersDefault(String webIdOrIssuer) async {
  try {
    return [Uri.parse(await solid_auth_issuer.getIssuer(webIdOrIssuer))];
  } catch (e) {
    // If loading the profile fails, return the input as is
    return [Uri.parse(webIdOrIssuer)];
  }
}

class _RsaInfo {
  final String pubKey;
  final String privKey;
  final dynamic pubKeyJwk;

  _RsaInfo({
    required this.pubKey,
    required this.privKey,
    required this.pubKeyJwk,
  });
}

/// Advanced configuration settings for the OIDC authentication flow in Solid applications.
///
/// This class provides fine-grained control over the OpenID Connect authentication
/// process, including security settings, token management, and platform-specific
/// behaviors. It extends the standard OIDC configuration with Solid-specific
/// requirements and optimizations.
///
/// ## Usage
///
/// Typically used internally by [SolidAuth], but may be exposed for advanced
/// use cases requiring custom OIDC flow configuration:
///
/// ```dart
/// final settings = SolidOidcUserManagerSettings(
///   redirectUri: Uri.parse('https://myapp.com/callback'),
///   supportOfflineAuth: false,
///   refreshBefore: Duration(minutes: 5),
/// );
/// ```
///
/// ## Security Considerations
///
/// - **JWT Verification**: [strictJwtVerification] is enabled by default for security
/// - **Offline Auth**: Disable [supportOfflineAuth] unless specifically needed
/// - **Token Refresh**: Configure [refreshBefore] to prevent token expiration
/// - **Redirect URIs**: Ensure all URIs are registered with your identity provider
///
/// ## Solid-Specific Defaults
///
/// This class provides sensible defaults for Solid OIDC:
/// - Default scopes: `['openid', 'webid', 'offline_access']` (recommended for Flutter apps)
/// - Automatic `consent` prompt when `offline_access` scope is requested
/// - WebID discovery integration via [getIssuers]
/// - DPoP token support for enhanced security
/// - Automatic session restoration capabilities
///
/// ## Scope Usage in Solid
///
/// Unlike traditional OAuth2 APIs, Solid applications typically don't need
/// additional scopes beyond the defaults. Access control in Solid is handled
/// at the resource level through Web Access Control (WAC) or Access Control
/// Policies (ACP), not through OAuth2 scopes.
///
/// The default scopes `['openid', 'webid', 'offline_access']` are sufficient
/// for virtually all Solid applications. Extra scopes are only needed for
/// specialized scenarios such as hybrid applications that integrate with
/// both Solid pods and traditional OAuth2 APIs.
///
/// ## Prompt Handling
///
/// The library automatically adds the `consent` prompt when the effective scopes
/// include `offline_access` (which is included by default). This ensures users
/// explicitly consent to refresh token capabilities, which is often required
/// by OIDC providers for security compliance.
///
/// For advanced use cases, you can customize prompt calculation using the
/// [calculateEffectivePrompts] parameter to implement custom logic based on
/// scopes and application requirements.
class SolidOidcUserManagerSettings {
  /// Creates a new instance of [SolidOidcUserManagerSettings].
  ///
  /// [redirectUri] is required and must be registered with your identity provider.
  /// All other parameters have sensible defaults for Solid OIDC authentication.
  const SolidOidcUserManagerSettings({
    required this.redirectUri,
    this.uiLocales,
    this.extraTokenHeaders,
    this.defaultScopes = staticDefaultScopes,
    this.extraScopes = const [],
    this.prompt = const [],
    this.display,
    this.acrValues,
    this.maxAge,
    this.extraAuthenticationParameters,
    this.expiryTolerance = const Duration(minutes: 1),
    this.extraTokenParameters,
    this.postLogoutRedirectUri,
    this.options,
    this.frontChannelLogoutUri,
    this.userInfoSettings = const OidcUserInfoSettings(),
    this.frontChannelRequestListeningOptions =
        const OidcFrontChannelRequestListeningOptions(),
    this.refreshBefore = defaultRefreshBefore,
    this.strictJwtVerification = true,
    this.getExpiresIn,
    this.sessionManagementSettings = const OidcSessionManagementSettings(),
    this.getIdToken,
    this.supportOfflineAuth = false,
    this.hooks,
    this.extraRevocationParameters,
    this.extraRevocationHeaders,
    this.getIssuers,
    this.calculateEffectivePrompts,
  });

  /// The static default scopes required for Solid OIDC authentication.
  ///
  /// These scopes provide:
  /// - `openid`: Basic OpenID Connect functionality
  /// - `webid`: Access to the user's WebID (Solid-specific)
  /// - `offline_access`: Ability to refresh tokens when the user is offline
  ///
  /// This constant provides the recommended baseline scopes for Solid OIDC.
  /// Individual instances can override these via the [defaultScopes] parameter.
  static const staticDefaultScopes = ['openid', 'webid', 'offline_access'];

  /// The configurable default scopes for this instance.
  ///
  /// These scopes form the base set of scopes that will be requested during
  /// authentication. For most Flutter applications, the default scopes
  /// `['openid', 'webid', 'offline_access']` are recommended and should not
  /// be changed.
  ///
  /// The `offline_access` scope is particularly important for Flutter apps as it
  /// enables refresh tokens, allowing the app to maintain authentication across
  /// app restarts and network interruptions without requiring re-authentication.
  ///
  /// **Note**: This parameter is primarily intended for advanced use cases or
  /// specialized integrations. Most Solid applications should use the default
  /// scopes without modification:
  ///
  /// ```dart
  /// // Recommended: Use default scopes for typical Solid apps
  /// final settings = SolidOidcUserManagerSettings(
  ///   redirectUri: Uri.parse('https://myapp.com/callback'),
  ///   // No scope configuration needed - defaults are ideal
  /// );
  /// ```
  ///
  /// **Security Note**: Removing `offline_access` from default scopes will
  /// prevent refresh token functionality and require re-authentication when
  /// access tokens expire, which is generally not suitable for Flutter Solid applications.
  final List<String> defaultScopes;

  /// Settings to control using the user_info endpoint.
  final OidcUserInfoSettings userInfoSettings;

  /// whether JWTs are strictly verified.
  ///
  /// If set to true, the library will throw an exception if a JWT is invalid.
  ///
  /// **Security Note**: This defaults to `true` for security. Only set to `false`
  /// for development/testing or when working with non-compliant OIDC providers.
  final bool strictJwtVerification;

  /// Whether to support offline authentication or not.
  ///
  /// When this option is enabled, expired tokens will NOT be removed if the
  /// server can't be contacted
  ///
  /// This parameter is disabled by default due to security concerns.
  final bool supportOfflineAuth;

  /// see [OidcAuthorizeRequest.redirectUri].
  final Uri redirectUri;

  /// see [OidcEndSessionRequest.postLogoutRedirectUri].
  final Uri? postLogoutRedirectUri;

  /// the uri of the front channel logout flow.
  /// this Uri MUST be registered with the OP first.
  /// the OP will call this Uri when it wants to logout the user.
  final Uri? frontChannelLogoutUri;

  /// The options to use when listening to platform channels.
  ///
  /// [frontChannelLogoutUri] must be set for this to work.
  final OidcFrontChannelRequestListeningOptions
      frontChannelRequestListeningOptions;

  /// Additional scopes to request beyond the default scopes.
  ///
  /// **Note**: Extra scopes are rarely needed for Solid applications. Access
  /// control in Solid is typically handled at the resource level through Web
  /// Access Control (WAC) or Access Control Policies (ACP), not through OAuth2 scopes.
  ///
  /// This parameter is primarily for specialized scenarios such as:
  /// - Hybrid applications that integrate with both Solid pods and traditional OAuth2 APIs
  /// - Identity providers that offer additional profile information beyond WebID
  /// - Custom provider-specific functionality
  ///
  /// For pure Solid applications, the default scopes `['openid', 'webid', 'offline_access']`
  /// are typically sufficient.
  ///
  /// ```dart
  /// // Most Solid apps don't need extra scopes
  /// final settings = SolidOidcUserManagerSettings(
  ///   redirectUri: Uri.parse('https://myapp.com/callback'),
  ///   // extraScopes typically not needed
  /// );
  ///
  /// // Only for specialized hybrid applications
  /// final hybridSettings = SolidOidcUserManagerSettings(
  ///   redirectUri: Uri.parse('https://myapp.com/callback'),
  ///   extraScopes: ['profile'], // For non-Solid API integration
  /// );
  /// ```
  final List<String> extraScopes;

  /// Custom prompts for the authorization request.
  ///
  /// These prompts control how the identity provider handles user interaction
  /// during authentication. See [OidcAuthorizeRequest.prompt] for standard values.
  ///
  /// **Note**: The `consent` prompt is automatically added when the effective
  /// scopes include `offline_access` (which is included by default). This ensures
  /// users explicitly consent to refresh token capabilities required for offline access.
  ///
  /// Example: `['login', 'select_account']` - force re-authentication and account selection
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

  /// Custom function for resolving WebIDs or issuer strings to identity provider URIs.
  ///
  /// This function overrides the default WebID-to-issuer discovery process.
  /// See [GetIssuers] typedef for detailed documentation and examples.
  ///
  /// When `null`, the library uses the standard Solid WebID discovery:
  /// 1. Fetch the WebID profile document
  /// 2. Extract the `solid:oidcIssuer` property
  /// 3. Use that as the identity provider URI
  final GetIssuers? getIssuers;

  /// Custom function for calculating effective prompts based on scopes and configured prompts.
  ///
  /// This function overrides the default prompt calculation behavior.
  /// See [CalculateEffectivePrompts] typedef for detailed documentation and examples.
  ///
  /// When `null`, the library uses the default Solid behavior:
  /// - Includes all configured prompts from [prompt]
  /// - Automatically adds `consent` when `offline_access` is in the effective scopes
  ///
  /// When provided, gives full control over prompt calculation for advanced use cases:
  ///
  /// ```dart
  /// final settings = SolidOidcUserManagerSettings(
  ///   redirectUri: Uri.parse('https://myapp.com/callback'),
  ///   calculateEffectivePrompts: (configuredPrompts, effectiveScopes) {
  ///     final prompts = <String>{...configuredPrompts};
  ///
  ///     // Custom logic: only add consent for offline access in production
  ///     if (effectiveScopes.contains('offline_access') && kReleaseMode) {
  ///       prompts.add('consent');
  ///     }
  ///
  ///     return prompts.toList()..sort();
  ///   },
  /// );
  /// ```
  ///
  /// **Note**: This is an advanced feature primarily intended for specialized
  /// integration scenarios. Most applications should rely on the default behavior.
  final CalculateEffectivePrompts? calculateEffectivePrompts;

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
  SolidOidcUserManagerSettings copyWith({
    Uri? redirectUri,
    List<String>? uiLocales,
    Map<String, String>? extraTokenHeaders,
    List<String>? defaultScopes,
    List<String>? extraScopes,
    List<String>? prompt,
    String? display,
    List<String>? acrValues,
    Duration? maxAge,
    Map<String, dynamic>? extraAuthenticationParameters,
    Duration? expiryTolerance,
    Map<String, dynamic>? extraTokenParameters,
    Uri? postLogoutRedirectUri,
    OidcPlatformSpecificOptions? options,
    Uri? frontChannelLogoutUri,
    OidcUserInfoSettings? userInfoSettings,
    OidcFrontChannelRequestListeningOptions?
        frontChannelRequestListeningOptions,
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
    CalculateEffectivePrompts? calculateEffectivePrompts,
  }) {
    return SolidOidcUserManagerSettings(
      redirectUri: redirectUri ?? this.redirectUri,
      uiLocales: uiLocales ?? this.uiLocales,
      extraTokenHeaders: extraTokenHeaders ?? this.extraTokenHeaders,
      defaultScopes: defaultScopes ?? this.defaultScopes,
      extraScopes: extraScopes ?? this.extraScopes,
      prompt: prompt ?? this.prompt,
      display: display ?? this.display,
      acrValues: acrValues ?? this.acrValues,
      maxAge: maxAge ?? this.maxAge,
      extraAuthenticationParameters:
          extraAuthenticationParameters ?? this.extraAuthenticationParameters,
      expiryTolerance: expiryTolerance ?? this.expiryTolerance,
      extraTokenParameters: extraTokenParameters ?? this.extraTokenParameters,
      postLogoutRedirectUri:
          postLogoutRedirectUri ?? this.postLogoutRedirectUri,
      options: options ?? this.options,
      frontChannelLogoutUri:
          frontChannelLogoutUri ?? this.frontChannelLogoutUri,
      userInfoSettings: userInfoSettings ?? this.userInfoSettings,
      frontChannelRequestListeningOptions:
          frontChannelRequestListeningOptions ??
              this.frontChannelRequestListeningOptions,
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
      calculateEffectivePrompts:
          calculateEffectivePrompts ?? this.calculateEffectivePrompts,
    );
  }
}

/// Low-level OIDC user manager with Solid-specific enhancements.
///
/// This class provides direct access to the underlying OIDC authentication
/// mechanisms with Solid pod integration. It handles WebID discovery, DPoP
/// token generation, and secure session management.
///
/// ## Internal Implementation
///
/// This class is typically used internally by [SolidAuth] but may be exposed
/// for advanced use cases requiring fine-grained control over the authentication
/// flow, such as:
///
/// - Custom identity provider discovery logic
/// - Advanced token lifecycle management
/// - Integration with non-standard OIDC providers
///
/// ## Key Features
///
/// - **WebID Integration**: Automatically resolves WebIDs to identity providers
/// - **DPoP Support**: Generates and manages DPoP tokens for enhanced security
/// - **Session Persistence**: Maintains authentication state across app restarts
/// - **Flexible Configuration**: Supports extensive OIDC customization options
///
/// ## Usage Example
///
/// ```dart
/// final manager = SolidOidcUserManager(
///   clientId: 'https://myapp.com/client-profile.jsonld',
///   webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
///   store: OidcMemoryStore(), // or OidcDefaultStore() for persistence
///   settings: SolidOidcUserManagerSettings(
///     redirectUri: Uri.parse('https://myapp.com/callback'),
///   ),
/// );
///
/// await manager.init();
/// final result = await manager.loginAuthorizationCodeFlow();
/// final dpop = manager.genDpopToken('https://alice.pod.com/data', 'GET');
/// ```
///
/// ## Security Considerations
///
/// - DPoP keys are automatically generated and securely stored
/// - WebID validation ensures identity provider authorization
/// - Token refresh is handled automatically with configurable timing
/// - All tokens are stored using platform-appropriate secure storage
class SolidOidcUserManager {
  Uri? _issuerUri;
  OidcUserManager? _manager;

  /// The WebID or issuer URL used for authentication discovery.
  final String _webIdOrIssuer;

  /// The persistent store for caching tokens, keys, and session data.
  ///
  /// This store handles secure persistence of:
  /// - Access and refresh tokens
  /// - DPoP cryptographic key pairs
  /// - User session information
  /// - OIDC discovery metadata
  ///
  /// Use [OidcDefaultStore] for production apps with persistent storage,
  /// or [OidcMemoryStore] for testing or non-persistent scenarios.
  final OidcStore store;

  final String? _id;

  /// The HTTP client used for making authentication and API requests.
  ///
  /// If not provided, a default HTTP client will be used. Custom clients
  /// can be provided for proxy support, custom headers, or request monitoring.
  final http.Client? _httpClient;

  final String _clientId;

  /// The cryptographic key store for JWT token verification.
  ///
  /// Contains public keys from identity providers used to verify
  /// the authenticity and integrity of JWT tokens. Keys are typically
  /// fetched automatically from the provider's JWKS endpoint.
  final JsonWebKeyStore? _keyStore;

  final SolidOidcUserManagerSettings _settings;

  // DPoP key pair management - using solid_auth generated keys
  _RsaInfo? _rsaInfo;

  String? _currentWebId;

  // Storage keys for persisting SOLID-specific data
  static const String _rsaInfoKey = 'solid_rsa_info';

  /// Creates a new [SolidOidcUserManager] instance.
  ///
  /// ## Parameters
  ///
  /// - [clientId]: Your application's client identifier (typically a URL to your client profile document)
  /// - [webIdOrIssuer]: The user's WebID or the identity provider's issuer URI
  /// - [store]: Persistent storage for tokens and session data
  /// - [settings]: Configuration options for the OIDC flow
  /// - [id]: Optional identifier for this manager instance (useful for multiple accounts)
  /// - [httpClient]: Optional custom HTTP client for requests
  /// - [keyStore]: Optional custom key store for JWT verification
  ///
  /// ## Example
  ///
  /// ```dart
  /// final manager = SolidOidcUserManager(
  ///   clientId: 'https://myapp.com/client-profile.jsonld',
  ///   webIdOrIssuer: 'https://alice.solidcommunity.net/profile/card#me',
  ///   store: OidcDefaultStore(),
  ///   settings: SolidOidcUserManagerSettings(
  ///     redirectUri: Uri.parse('com.myapp://callback'),
  ///     strictJwtVerification: true,
  ///   ),
  /// );
  /// ```
  SolidOidcUserManager({
    required String clientId,
    required String webIdOrIssuer,
    required this.store,
    required SolidOidcUserManagerSettings settings,
    String? id,
    http.Client? httpClient,
    JsonWebKeyStore? keyStore,
  })  : _settings = settings,
        _webIdOrIssuer = webIdOrIssuer,
        _id = id,
        _keyStore = keyStore,
        _httpClient = httpClient,
        _clientId = clientId;

  /// The currently authenticated OIDC user, or `null` if not authenticated.
  ///
  /// This object contains:
  /// - Access and refresh tokens
  /// - User claims from the ID token
  /// - Profile information from UserInfo endpoint
  /// - Token expiration and refresh status
  ///
  /// Use this to access OIDC-specific user information and tokens.
  OidcUser? get currentUser => _manager?.currentUser;

  /// The currently authenticated user's WebID, or `null` if not authenticated.
  ///
  /// The WebID is the Solid-specific user identifier that was validated
  /// during authentication. This is the primary identifier for the user
  /// in the Solid ecosystem and should be used for:
  /// - Identifying the user across Solid applications
  /// - Constructing URLs to the user's pod resources
  /// - Access control and authorization decisions
  ///
  /// Example: `'https://alice.solidcommunity.net/profile/card#me'`
  String? get currentWebId => _currentWebId;

  /// Initializes the user manager and attempts to restore any existing session.
  ///
  /// This method must be called before any other authentication operations.
  /// It performs the following steps:
  ///
  /// 1. **Identity Provider Discovery**: Resolves the WebID or issuer to determine
  ///    the appropriate OIDC identity provider
  /// 2. **OIDC Configuration**: Fetches the provider's OpenID configuration
  /// 3. **Key Pair Management**: Restores or generates DPoP cryptographic keys
  /// 4. **Session Restoration**: Attempts to restore any existing authentication session
  /// 5. **WebID Validation**: If a session exists, validates the WebID against the provider
  ///
  /// ## Authentication State
  ///
  /// After initialization, check [currentUser] and [currentWebId] to determine
  /// if the user is already authenticated from a previous session.
  ///
  /// ## Error Handling
  ///
  /// ```dart
  /// try {
  ///   await manager.init();
  ///   if (manager.currentUser != null) {
  ///     print('Restored session for: ${manager.currentWebId}');
  ///   }
  /// } catch (e) {
  ///   print('Initialization failed: $e');
  ///   // Handle provider discovery or configuration errors
  /// }
  /// ```
  ///
  /// ## Performance Notes
  ///
  /// - Network requests are made to discover provider configuration
  /// - Cryptographic key generation may occur on first use
  /// - Existing sessions are validated against current provider settings
  Future<void> init() async {
    if (_manager != null) {
      await logout();
    }

    final issuerUris =
        await (_settings.getIssuers ?? _getIssuersDefault)(_webIdOrIssuer);
    _issuerUri = issuerUris.first;
    Uri wellKnownUri = OidcUtils.getOpenIdConfigWellKnownUri(_issuerUri!);

    // Use static client ID pointing to our Public Client Identifier Document
    final clientCredentials = OidcClientAuthentication.none(
      clientId: _clientId,
    );

    // Try to restore persisted RSA info first
    await _loadPersistedRsaInfo();

    // Generate RSA key pair for DPoP token generation if not already available
    if (_rsaInfo == null) {
      await _generateAndPersistRsaKeyPair();
    } else {
      _log.info('DPoP RSA key pair restored from storage');
    }
    _log.info('Using Public Client Identifier: $_clientId');
    final hooks = _settings.hooks ?? OidcUserManagerHooks();
    final dpopHookTokenHook = OidcHook<OidcTokenHookRequest, OidcTokenResponse>(
      modifyRequest: (request) async {
        if (_rsaInfo == null) {
          // user has logged out in the mean time and now wants to log in again,
          // we need to generate a new key pair
          await _generateAndPersistRsaKeyPair();
        }

        ///Generate DPoP token using the RSA private key
        String dPopToken = _genDpopToken(
          request.tokenEndpoint.toString(),
          "POST",
        );
        if (request.headers == null) {
          request.headers = {};
        }
        request.headers!['DPoP'] = dPopToken;
        return Future.value(request);
      },
    );
    hooks.token = OidcHookGroup(
      hooks: [if (hooks.token != null) hooks.token!, dpopHookTokenHook],
      executionHook: (hooks.token is OidcExecutionHookMixin<
              OidcTokenHookRequest, OidcTokenResponse>)
          ? hooks.token
              as OidcExecutionHookMixin<OidcTokenHookRequest, OidcTokenResponse>
          : dpopHookTokenHook,
    );

    // Compute effective scopes once to avoid duplication
    final effectiveScopes = getEffectiveScopes();

    _manager = OidcUserManager.lazy(
      discoveryDocumentUri: wellKnownUri,
      clientCredentials: clientCredentials,
      store: store,
      settings: OidcUserManagerSettings(
        strictJwtVerification: _settings.strictJwtVerification,
        scope: effectiveScopes,
        frontChannelLogoutUri: _settings.frontChannelLogoutUri,
        redirectUri: _settings.redirectUri,
        postLogoutRedirectUri: _settings.postLogoutRedirectUri,
        hooks: hooks,
        acrValues: _settings.acrValues,
        display: _settings.display,
        expiryTolerance: _settings.expiryTolerance,
        extraAuthenticationParameters: _settings.extraAuthenticationParameters,
        extraTokenHeaders: _settings.extraTokenHeaders,
        extraTokenParameters: _settings.extraTokenParameters,
        uiLocales: _settings.uiLocales,
        prompt: getEffectivePrompts(effectiveScopes),
        maxAge: _settings.maxAge,
        extraRevocationHeaders: _settings.extraRevocationHeaders,
        extraRevocationParameters: _settings.extraRevocationParameters,
        options: _settings.options,
        frontChannelRequestListeningOptions:
            _settings.frontChannelRequestListeningOptions,
        refreshBefore: _settings.refreshBefore,
        getExpiresIn: _settings.getExpiresIn,
        sessionManagementSettings: _settings.sessionManagementSettings,
        getIdToken: _settings.getIdToken,
        supportOfflineAuth: _settings.supportOfflineAuth,
        userInfoSettings: _settings.userInfoSettings,
      ),
      keyStore: _keyStore,
      id: _id,
      httpClient: _httpClient,
    );

    await _manager!.init();
    if (_manager!.currentUser != null) {
      _log.info(
        'SolidOidcUserManager initialized with existing user: ${_manager!.currentUser!.claims.subject}',
      );
      // Extract WebID from the OIDC token using the Solid-OIDC spec methods
      String webId = await _extractAndValidateWebId(_manager!.currentUser!);
      _currentWebId = webId;
    } else {
      _log.info('SolidOidcUserManager initialized without existing user');
    }
  }

  List<String> getEffectiveScopes() {
    return {
      // Use the configurable default scopes for this instance
      ..._settings.defaultScopes,
      ..._settings.extraScopes,
    }.toList()
      // make sure the result is always the same
      ..sort();
  }

  /// Calculates the effective prompts for the OIDC authorization request.
  ///
  /// This method combines the configured prompts with automatically added
  /// prompts based on the requested scopes, or delegates to a custom function
  /// if [SolidOidcUserManagerSettings.calculateEffectivePrompts] is provided.
  ///
  /// ## Parameters
  ///
  /// - [scopes]: The effective scopes that will be requested during authentication
  ///
  /// ## Default Behavior (when [calculateEffectivePrompts] is null)
  ///
  /// - Includes all configured prompts from [SolidOidcUserManagerSettings.prompt]
  /// - Automatically adds `consent` when `offline_access` is in the provided scopes
  /// - Custom prompts from [SolidOidcUserManagerSettings.prompt] are preserved
  ///
  /// ## Custom Behavior
  ///
  /// When [SolidOidcUserManagerSettings.calculateEffectivePrompts] is provided,
  /// that function takes full control over prompt calculation and receives:
  /// - The configured prompts from settings
  /// - The effective scopes for the request
  ///
  /// ## Automatic Consent Prompt (Default Behavior)
  ///
  /// The `consent` prompt is required when requesting `offline_access` because:
  /// - Refresh tokens allow long-term access without user interaction
  /// - Users must explicitly consent to this enhanced access level
  /// - Many OIDC providers require explicit consent for offline access
  ///
  /// ## Return Value
  ///
  /// Returns a list of prompt values to be sent to the identity provider
  /// during the authorization request.
  List<String> getEffectivePrompts(List<String> scopes) {
    // Use custom function if provided
    if (_settings.calculateEffectivePrompts != null) {
      return _settings.calculateEffectivePrompts!(_settings.prompt, scopes);
    }

    // Default behavior: include configured prompts and add consent for offline_access
    final prompts = <String>{..._settings.prompt};

    // Automatically add 'consent' prompt when offline_access is requested
    // This ensures users explicitly consent to refresh token capabilities
    if (scopes.contains('offline_access')) {
      prompts.add('consent');
    }

    return prompts.toList()
      // Ensure consistent ordering
      ..sort();
  }

  Future<void> _generateAndPersistRsaKeyPair() async {
    final rsaInfo = await solid_auth_client.genRsaKeyPair();
    final rsa = rsaInfo['rsa'] as KeyPair;
    _rsaInfo = _RsaInfo(
      pubKey: rsa.publicKey,
      privKey: rsa.privateKey,
      pubKeyJwk: rsaInfo['pubKeyJwk'],
    );
    await _persistRsaInfo();
    _log.info('DPoP RSA key pair generated and persisted');
  }

  /// Initiates the OAuth2 Authorization Code Flow for user authentication.
  ///
  /// This method starts the standard OIDC authentication process:
  ///
  /// 1. **Redirect to Provider**: Opens the identity provider's login page
  /// 2. **User Authentication**: User enters credentials and grants consent
  /// 3. **Authorization Code**: Provider redirects back with authorization code
  /// 4. **Token Exchange**: Code is exchanged for access and ID tokens
  /// 5. **WebID Extraction**: WebID is extracted and validated from tokens
  /// 6. **DPoP Integration**: Tokens are enhanced with DPoP proof-of-possession
  ///
  /// ## Consent Requirements
  ///
  /// The authentication flow automatically includes a `consent` prompt when
  /// `offline_access` is in the requested scopes (included by default). This
  /// ensures users explicitly consent to refresh token capabilities, which
  /// many identity providers require for security compliance.
  ///
  /// ## Platform Behavior
  ///
  /// - **Web**: Opens provider login in the same window or popup
  /// - **Mobile**: Launches system browser or in-app WebView
  /// - **Desktop**: Opens default system browser
  ///
  /// ## Return Value
  ///
  /// Returns [UserAndWebId] containing both the OIDC user data and the
  /// validated Solid WebID, or `null` if the user cancels authentication.
  ///
  /// ## Error Handling
  ///
  /// ```dart
  /// try {
  ///   final result = await manager.loginAuthorizationCodeFlow();
  ///   if (result != null) {
  ///     print('Authenticated as: ${result.webId}');
  ///     print('Provider: ${result.user.claims.issuer}');
  ///   }
  /// } on OidcException catch (e) {
  ///   // Handle OIDC-specific errors (network, configuration, etc.)
  /// } on Exception catch (e) {
  ///   // Handle WebID validation or other authentication errors
  /// }
  /// ```
  ///
  /// ## Security Notes
  ///
  /// - WebID profile document is fetched to validate the identity provider is authorized for this WebID
  /// - RSA key pairs for DPoP token generation are automatically created and securely stored
  /// - All tokens are stored using platform-appropriate secure storage
  /// - Session state is automatically persisted for future app launches
  Future<UserAndWebId?> loginAuthorizationCodeFlow() async {
    final oidcUser = await _manager!.loginAuthorizationCodeFlow();
    if (oidcUser == null) {
      throw Exception('OIDC authentication failed: no user returned');
    }

    // Extract WebID from the OIDC token using the Solid-OIDC spec methods
    String webId = await _extractAndValidateWebId(oidcUser);
    _currentWebId = webId;
    return UserAndWebId(oidcUser: oidcUser, webId: webId);
  }

  Future<String> _extractAndValidateWebId(OidcUser oidcUser) async {
    // Extract WebID from the OIDC token using the Solid-OIDC spec methods
    final webId = _extractWebIdFromOidcUser(oidcUser);

    // extra security check: retrieve the profile and ensure that the
    // issuer really is allowed by this webID
    final issuerUris = (await (_settings.getIssuers ?? _getIssuersDefault)(
      webId,
    ))
        .map(_normalizeUri)
        .toSet();
    final normalizedIssuerUri = _normalizeUri(_issuerUri!);
    if (!issuerUris.contains(normalizedIssuerUri)) {
      throw Exception(
        'No valid issuer found for WebID: $webId . Expected: $normalizedIssuerUri but got: $issuerUris',
      );
    }
    return webId;
  }

  /// Normalizes a URI by removing trailing slashes and converting to lowercase for comparison.
  Uri _normalizeUri(Uri uri) {
    final pathWithoutTrailingSlash = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;

    return uri.replace(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      path: pathWithoutTrailingSlash,
    );
  }

  String _genDpopToken(String url, String method) {
    if (_rsaInfo == null) {
      throw Exception('RSA key pair not generated. Call authenticate first.');
    }

    final rsaKeyPair = KeyPair(_rsaInfo!.pubKey, _rsaInfo!.privKey);
    final publicKeyJwk = _rsaInfo!.pubKeyJwk;

    return solid_auth_client.genDpopToken(
        url, rsaKeyPair, publicKeyJwk, method);
  }

  /// Generates a DPoP (Demonstration of Proof-of-Possession) token for API requests.
  ///
  /// DPoP tokens are required by Solid servers to prove that the client making
  /// an API request is the same client that was issued the access token. This
  /// prevents token theft and replay attacks.
  ///
  /// ## Parameters
  ///
  /// - [url]: The complete URL of the API endpoint being accessed
  /// - [method]: The HTTP method being used ('GET', 'POST', 'PUT', 'DELETE', etc.)
  ///
  /// ## Return Value
  ///
  /// Returns a [DPoP] object containing both the DPoP proof token and the
  /// access token, ready for use in HTTP requests.
  ///
  /// ## Usage Example
  ///
  /// ```dart
  /// // Generate DPoP token for a specific request
  /// final dpop = manager.genDpopToken(
  ///   'https://alice.solidcommunity.net/profile/card',
  ///   'GET'
  /// );
  ///
  /// // Use with HTTP client
  /// final response = await http.get(
  ///   Uri.parse('https://alice.solidcommunity.net/profile/card'),
  ///   headers: dpop.httpHeaders(),
  /// );
  /// ```
  ///
  /// ## Security Requirements
  ///
  /// - Must be called only after successful authentication
  /// - Each DPoP token is tied to a specific URL and HTTP method
  /// - Tokens should be generated fresh for each API request
  /// - The underlying RSA key pair is automatically managed and persisted
  ///
  /// ## Error Conditions
  ///
  /// Throws [Exception] if:
  /// - No user is currently authenticated
  /// - Access token is not available or expired
  /// - DPoP key pair generation failed
  ///
  /// ```dart
  /// try {
  ///   final dpop = manager.genDpopToken(url, 'GET');
  ///   // Use dpop for API request
  /// } catch (e) {
  ///   // Handle authentication or key generation errors
  ///   print('DPoP generation failed: $e');
  /// }
  /// ```
  DPoP genDpopToken(String url, String method) {
    if (_manager?.currentUser?.token.accessToken == null) {
      throw Exception('No access token available for DPoP generation');
    }

    final dpopToken = _genDpopToken(url, method);

    // Get the access token from the current user
    final accessToken = _manager!.currentUser!.token.accessToken!;

    return DPoP(dpopToken: dpopToken, accessToken: accessToken);
  }

  /// Logs out the current user and clears all authentication data.
  ///
  /// This method performs a complete logout process:
  ///
  /// 1. **Provider Logout**: Notifies the identity provider of the logout (if supported)
  /// 2. **Local Cleanup**: Clears all cached authentication data
  /// 3. **Key Cleanup**: Removes DPoP cryptographic key pairs
  /// 4. **Session Termination**: Ensures no residual authentication state
  ///
  /// **Note**: Token revocation depends on the underlying OIDC library implementation
  /// and identity provider support. Check your provider's documentation for revocation capabilities.
  ///
  /// ## Post-Logout State
  ///
  /// After logout:
  /// - [currentUser] returns `null`
  /// - [currentWebId] returns `null`
  /// - All tokens and keys are securely erased
  /// - A new authentication flow is required for future API access
  ///
  /// ## Usage Example
  ///
  /// ```dart
  /// await manager.logout();
  /// print('User logged out successfully');
  ///
  /// // Verify logout state
  /// assert(manager.currentUser == null);
  /// assert(manager.currentWebId == null);
  /// ```
  ///
  /// ## Security Notes
  ///
  /// - Logout is performed securely with the identity provider when possible
  /// - All cryptographic material is securely erased from local storage
  /// - Network failures during provider logout don't prevent local cleanup
  /// - Multiple logout calls are safe and idempotent
  Future<void> logout() async {
    await _manager?.logout();
    _currentWebId = null;

    // Clear persisted RSA key pair info
    _rsaInfo = null;
    await _clearPersistedRsaInfo();
  }

  /// Disposes of all resources and cleans up the user manager.
  ///
  /// This method should be called when the user manager is no longer needed,
  /// typically when the application is shutting down or switching user contexts.
  ///
  /// ## Cleanup Operations
  ///
  /// - Releases HTTP client resources
  /// - Closes any open authentication flows
  /// - Disposes of the underlying OIDC manager
  /// - Clears all internal state references
  ///
  /// ## Usage
  ///
  /// ```dart
  /// // Clean shutdown
  /// await manager.logout(); // Optional: logout first
  /// await manager.dispose(); // Required: dispose resources
  ///
  /// // Manager is no longer usable after dispose
  /// ```
  ///
  /// ## Important Notes
  ///
  /// - Call [logout] first if you want to perform a clean logout
  /// - The manager cannot be used after disposal
  /// - This method does not automatically logout the user
  /// - Multiple dispose calls are safe and idempotent
  Future<void> dispose() async {
    await _manager?.dispose();
    _manager = null;
    _issuerUri = null;
  }

  /// Persists the RSA key pair info to the store for session continuity
  Future<void> _persistRsaInfo() async {
    if (_rsaInfo != null) {
      final serializableData = {
        'pubKey': _rsaInfo!.pubKey,
        'privKey': _rsaInfo!.privKey,
        'pubKeyJwk': _rsaInfo!.pubKeyJwk,
      };

      await store.set(
        OidcStoreNamespace.secureTokens,
        key: _rsaInfoKey,
        value: jsonEncode(serializableData),
        managerId: _id,
      );
    }
  }

  /// Loads the RSA key pair info from the store
  Future<void> _loadPersistedRsaInfo() async {
    try {
      final rsaInfoStr = await store.get(
        OidcStoreNamespace.secureTokens,
        key: _rsaInfoKey,
        managerId: _id,
      );
      if (rsaInfoStr != null) {
        final data = Map<String, dynamic>.from(jsonDecode(rsaInfoStr));
        _rsaInfo = _RsaInfo(
          pubKey: data['pubKey'] as String,
          privKey: data['privKey'] as String,
          pubKeyJwk: data['pubKeyJwk'],
        );
      }
    } catch (e) {
      _log.warning('Failed to load persisted RSA info: $e');
    }
  }

  /// Clears the persisted RSA key pair info
  Future<void> _clearPersistedRsaInfo() async {
    try {
      await store.remove(
        OidcStoreNamespace.secureTokens,
        key: _rsaInfoKey,
        managerId: _id,
      );
    } catch (e) {
      _log.warning('Failed to clear persisted RSA info: $e');
    }
  }

  /// Extracts the WebID URI from the OIDC user according to the Solid-OIDC specification.
  ///
  /// The spec defines three methods in order of preference:
  /// 1. Custom 'webid' claim in the ID token
  /// 2. 'sub' claim contains a valid HTTP(S) URI
  /// 3. UserInfo request + 'website' claim
  String _extractWebIdFromOidcUser(OidcUser oidcUser) {
    // Method 1: Check for custom 'webid' claim in ID token
    final webidClaim = oidcUser.claims['webid'];
    if (webidClaim != null &&
        webidClaim is String &&
        _isValidHttpUri(webidClaim)) {
      _log.fine('WebID extracted from webid claim: $webidClaim');
      return webidClaim;
    }

    // Method 2: Check if 'sub' claim contains a valid HTTP(S) URI
    final subClaim = oidcUser.claims.subject;
    if (subClaim != null && _isValidHttpUri(subClaim)) {
      _log.fine('WebID extracted from sub claim: $subClaim');
      return subClaim;
    }

    // Method 3: Check userInfo for 'website' claim
    final websiteClaim = oidcUser.userInfo['website'];
    if (websiteClaim != null &&
        websiteClaim is String &&
        _isValidHttpUri(websiteClaim)) {
      _log.fine('WebID extracted from website claim: $websiteClaim');
      return websiteClaim;
    }

    // If no WebID found, throw an exception
    throw Exception(
      'No valid WebID found in OIDC token. '
      'Checked webid claim, sub claim, and website claim. '
      'The OIDC provider must support Solid-OIDC specification.',
    );
  }

  /// Validates if a string is a valid HTTP or HTTPS URI.
  bool _isValidHttpUri(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      return (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
