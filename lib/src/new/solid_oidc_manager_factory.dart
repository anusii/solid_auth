import 'package:http/http.dart' as http;
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:logging/logging.dart';

import '../dpop/dpop_key_manager.dart';
import '../models/solid_provider_metadata.dart';
import '../utils/solid_scopes.dart';
import 'solid_dpop_http_client.dart';

final _log = Logger('solid_auth.SolidOidcManagerFactory');

/// Configuration for building an [OidcUserManager] for Solid-OIDC.
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

  final String clientId;
  final Uri redirectUri;
  final Uri? postLogoutRedirectUri;
  final List<String> scopes;
  final String? clientSecret;

  /// Optional base HTTP client. Wrapped internally by [SolidDpopHttpClient].
  /// You do NOT need to add DPoP logic here — that is handled automatically.
  final http.Client? httpClient;

  final Map<String, dynamic>? extraTokenParameters;
  final Map<String, dynamic>? extraAuthParameters;
}

/// Factory that constructs a fully configured [OidcUserManager] for
/// Solid-OIDC, with automatic DPoP key binding at the token endpoint.
///
/// ## What changed vs the previous version
///
/// The previous factory created an [OidcUserManager] with a plain HTTP client,
/// so token requests were sent without a `DPoP` header. The OP therefore issued
/// plain Bearer tokens (no `cnf` claim), and the Resource Server rejected them:
///
/// > "Expected object property cnf, got: [object Object]"
///
/// The fix is to wrap the HTTP client with [SolidDpopHttpClient], which
/// automatically injects a fresh DPoP proof on every request to the token
/// endpoint. The same [DpopKeyManager] instance is returned alongside the
/// manager so it can be reused for resource-request proofs.
abstract class SolidOidcManagerFactory {
  SolidOidcManagerFactory._();

  /// Creates an [OidcUserManager] and [DpopKeyManager], both pre-configured
  /// for Solid-OIDC with automatic token-endpoint DPoP injection.
  ///
  /// [metadata] is optional — pass it to skip the network discovery call.
  ///
  /// Returns a record `(manager, keyManager)`. The [DpopKeyManager] MUST be
  /// reused when generating DPoP proofs for resource requests so the key pair
  /// stays consistent with the `cnf.jkt` embedded in the access token.
  static Future<({OidcUserManager manager, DpopKeyManager keyManager})> create({
    required String issuerUri,
    required SolidOidcConfig config,
    SolidProviderMetadata? metadata,
  }) async {
    _log.fine('Creating OidcUserManager for issuer: $issuerUri');

    final scopes = _ensureWebIdScope(config.scopes);

    // 1. Obtain (or generate) the DPoP key pair BEFORE the manager is used.
    //    The key pair must exist before the first token-endpoint call so the
    //    SolidDpopHttpClient can sign the proof.
    final keyManager = await DpopKeyManager.getInstance();

    // 2. Wrap the HTTP client so token requests get an injected DPoP header.
    final dpopClient = SolidDpopHttpClient(
      keyManager: keyManager,
      inner: config.httpClient,
    );

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
      extraAuthenticationParameters: config.extraAuthParameters ?? {},
      extraTokenParameters: config.extraTokenParameters ?? {},
    );

    final manager = metadata != null
        ? OidcUserManager(
            discoveryDocument: metadata.oidcMetadata,
            clientCredentials: clientAuth,
            store: OidcDefaultStore(),
            settings: settings,
            httpClient: dpopClient, // ← DPoP-aware client
          )
        : OidcUserManager.lazy(
            discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
              Uri.parse(issuerUri),
            ),
            clientCredentials: clientAuth,
            store: OidcDefaultStore(),
            settings: settings,
            httpClient: dpopClient, // ← DPoP-aware client
          );

    return (manager: manager, keyManager: keyManager);
  }

  static List<String> _ensureWebIdScope(List<String> scopes) {
    if (scopes.contains(SolidScopes.webid)) return scopes;
    _log.warning(
      'webid scope missing — adding automatically (Solid-OIDC requirement)',
    );
    return [...scopes, SolidScopes.webid];
  }
}
