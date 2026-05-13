import 'package:http/http.dart' as http;
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:logging/logging.dart';

import '../models/solid_provider_metadata.dart';
import '../utils/solid_scopes.dart';

final _log = Logger('solid_auth.SolidOidcManagerFactory');

/// Configuration for building an [OidcUserManager] targeted at a Solid POD.
class SolidOidcConfig {
  const SolidOidcConfig({
    required this.clientId,
    required this.redirectUri,
    this.postLogoutRedirectUri,
    this.scopes = SolidScopes.defaultScopes,
    this.clientSecret,
    this.httpClient,
    this.extraTokenParameters,
    this.extraAuthParameters,
  });

  /// Your registered client ID. For dynamic registration this is assigned
  /// by the Solid server after registration.
  final String clientId;

  /// The redirect URI registered with the identity provider.
  /// On web this should be the `redirect.html` page URL.
  final Uri redirectUri;

  /// Post-logout redirect URI (optional).
  final Uri? postLogoutRedirectUri;

  /// Scopes to request. Defaults to [SolidScopes.defaultScopes] which
  /// includes the mandatory `webid` scope.
  final List<String> scopes;

  /// Optional client secret for confidential clients.
  /// Leave null for public clients (mobile / SPA).
  final String? clientSecret;

  /// Custom HTTP client (useful for proxying or testing).
  final http.Client? httpClient;

  /// Extra parameters sent with every token request.
  final Map<String, dynamic>? extraTokenParameters;

  /// Extra parameters sent with every authorization request.
  final Map<String, dynamic>? extraAuthParameters;
}

/// Factory that constructs a fully configured [OidcUserManager] for
/// Solid-OIDC authentication.
///
/// This is the key wiring point between `solid_auth` and `package:oidc`.
/// It handles:
/// - Solid-specific discovery document wrapping.
/// - Correct scope defaults (`webid` always included).
/// - DPoP-ready token hooks (wired in separately via [SolidDpopHook]).
/// - Platform-appropriate storage via [OidcDefaultStore].
///
/// Example:
/// ```dart
/// final manager = await SolidOidcManagerFactory.create(
///   issuerUri: 'https://solidcommunity.net',
///   config: SolidOidcConfig(
///     clientId: 'my_client_id',
///     redirectUri: Uri.parse('com.example.app://callback'),
///   ),
/// );
/// await manager.init();
/// ```
abstract class SolidOidcManagerFactory {
  SolidOidcManagerFactory._();

  /// Creates an [OidcUserManager] pre-configured for Solid-OIDC.
  ///
  /// [metadata] is optional — pass it if you have already fetched the
  /// discovery document to avoid an extra network round-trip.
  static OidcUserManager create({
    required String issuerUri,
    required SolidOidcConfig config,
    SolidProviderMetadata? metadata,
  }) {
    _log.fine('Creating OidcUserManager for issuer: $issuerUri');

    // Ensure webid scope is always present (Solid-OIDC requirement).
    final scopes = _ensureWebIdScope(config.scopes);

    final clientAuth = config.clientSecret != null
        ? OidcClientAuthentication.clientSecretPost(
            clientId: config.clientId,
            clientSecret: config.clientSecret!,
          )
        : OidcClientAuthentication.none(clientId: config.clientId);

    final settings = OidcUserManagerSettings(
      redirectUri: config.redirectUri,
      postLogoutRedirectUri: config.postLogoutRedirectUri,
      scope: scopes,
      extraAuthenticationParameters: {
        // Solid-OIDC requires PKCE; package:oidc uses it by default for
        // the Authorization Code flow, so no extra wiring is needed.
        ...?config.extraAuthParameters,
      },
      extraTokenParameters: config.extraTokenParameters ?? {},
    );

    if (metadata != null) {
      // Use the pre-fetched discovery document to skip a network call.
      return OidcUserManager(
        discoveryDocument: metadata.oidcMetadata,
        clientCredentials: clientAuth,
        store: OidcDefaultStore(),
        settings: settings,
        httpClient: config.httpClient,
      );
    }

    // Lazy path: let package:oidc fetch the discovery document on init().
    return OidcUserManager.lazy(
      discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
        Uri.parse(issuerUri),
      ),
      clientCredentials: clientAuth,
      store: OidcDefaultStore(),
      settings: settings,
      httpClient: config.httpClient,
    );
  }

  static List<String> _ensureWebIdScope(List<String> scopes) {
    if (scopes.contains(SolidScopes.webid)) return scopes;
    _log.warning(
      'webid scope missing from config — adding it automatically '
      '(required by Solid-OIDC spec).',
    );
    return [...scopes, SolidScopes.webid];
  }
}
