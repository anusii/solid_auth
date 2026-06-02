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
import 'package:oidc_default_store/oidc_default_store.dart';

import 'package:solid_auth/src/dpop/dpop_key_manager.dart';
import 'package:solid_auth/src/dpop/dpop_token_generator.dart';
import 'package:solid_auth/src/models/solid_provider_metadata.dart';
import 'package:solid_auth/src/utils/solid_scopes.dart';

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
  static Future<({OidcUserManager manager, DpopKeyManager keyManager})> create({
    required String issuerUri,
    required SolidOidcConfig config,
    SolidProviderMetadata? metadata,
  }) async {
    _log.fine('Creating OidcUserManager for issuer: $issuerUri');

    // Ensure webid scope is always present (Solid-OIDC requirement).
    final scopes = _ensureWebIdScope(config.scopes);

    // 1. Generate (or reuse) the DPoP key pair BEFORE the manager is used.
    //    The key must exist before the first token-endpoint call so the hook
    //    can sign the proof.
    final keyManager = await DpopKeyManager.getInstance();

    // 2. Build the DPoP injection hook using OidcHook.modifyRequest.
    //
    //    OidcTokenHookRequest exposes:
    //      .request  — OidcTokenRequest (has .grantType, .tokenEndpoint, etc.)
    //      .headers  — Map<String, String>, mutated in place before the HTTP
    //                  call is fired.
    //
    //    We inject a fresh DPoP proof on every token request (authorization_code,
    //    refresh_token, etc.) because the Solid OP requires it each time.
    final dpopTokenHook = OidcHook<OidcTokenHookRequest, OidcTokenResponse>(
      modifyRequest: (hookRequest) async {
        final tokenEndpointUrl = hookRequest.tokenEndpoint.toString();

        _log.fine(
          'DPoP hook: generating proof for token endpoint: $tokenEndpointUrl '
          '(grant_type=${hookRequest.request.grantType})',
        );

        final dpopProof = await DpopTokenGenerator.generateForTokenEndpoint(
          tokenEndpointUrl: tokenEndpointUrl,
          keyManager: keyManager,
        );

        // Mutate the headers map in place — OidcUserManagerBase reads it
        // after modifyRequest returns and includes it in the HTTP POST.
        hookRequest.headers!['DPoP'] = dpopProof;

        return hookRequest;
      },
    );

    // 3. Wire the hook into OidcUserManagerSettings.
    final settings = OidcUserManagerSettings(
      redirectUri: config.redirectUri,
      postLogoutRedirectUri: config.postLogoutRedirectUri,
      scope: scopes,
      extraAuthenticationParameters: config.extraAuthParameters ?? {},
      extraTokenParameters: config.extraTokenParameters ?? {},
      hooks: OidcUserManagerHooks(
        token: dpopTokenHook,
      ),
    );

    final clientAuth = config.clientSecret != null
        ? OidcClientAuthentication.clientSecretPost(
            clientId: config.clientId,
            clientSecret: config.clientSecret!,
          )
        : OidcClientAuthentication.none(clientId: config.clientId);

    // final settings = OidcUserManagerSettings(
    //   redirectUri: config.redirectUri,
    //   postLogoutRedirectUri: config.postLogoutRedirectUri,
    //   scope: scopes,
    //   extraAuthenticationParameters: {
    //     // Solid-OIDC requires PKCE; package:oidc uses it by default for
    //     // the Authorization Code flow, so no extra wiring is needed.
    //     ...?config.extraAuthParameters,
    //   },
    //   extraTokenParameters: config.extraTokenParameters ?? {},
    // );

    // 4. Construct the manager — plain httpClient, no DPoP wrapping needed.
    final manager = metadata != null
        ? OidcUserManager(
            discoveryDocument: metadata.oidcMetadata,
            clientCredentials: clientAuth,
            store: OidcDefaultStore(),
            settings: settings,
            httpClient: config.httpClient,
          )
        : OidcUserManager.lazy(
            discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
              Uri.parse(issuerUri),
            ),
            clientCredentials: clientAuth,
            store: OidcDefaultStore(),
            settings: settings,
            httpClient: config.httpClient,
          );

    // if (metadata != null) {
    //   // Use the pre-fetched discovery document to skip a network call.
    //   return OidcUserManager(
    //     discoveryDocument: metadata.oidcMetadata,
    //     clientCredentials: clientAuth,
    //     store: OidcDefaultStore(),
    //     settings: settings,
    //     httpClient: config.httpClient,
    //   );
    // }

    // // Lazy path: let package:oidc fetch the discovery document on init().
    // return OidcUserManager.lazy(
    //   discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
    //     Uri.parse(issuerUri),
    //   ),
    //   clientCredentials: clientAuth,
    //   store: OidcDefaultStore(),
    //   settings: settings,
    //   httpClient: config.httpClient,
    // );

    return (manager: manager, keyManager: keyManager);
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
