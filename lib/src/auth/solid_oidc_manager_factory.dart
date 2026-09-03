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

import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

import 'package:solid_auth/src/auth/solid_oidc_config.dart';
import 'package:solid_auth/src/dpop/dpop_key_manager.dart';
import 'package:solid_auth/src/dpop/dpop_token_generator.dart';
import 'package:solid_auth/src/models/solid_provider_metadata.dart';
import 'package:solid_auth/src/utils/solid_scopes.dart';

final _log = Logger('solid_auth.SolidOidcManagerFactory');

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

    // Generate (or reuse) the DPoP key pair BEFORE the manager is used.
    // The key must exist before the first token-endpoint call so the hook
    // can sign the proof.
    final keyManager = await DpopKeyManager.getInstance();

    // Initialise OIDC manager hooks
    final hooks = config.hooks ?? OidcUserManagerHooks();

    // Build the DPoP injection hook using OidcHook.modifyRequest.
    //
    // OidcTokenHookRequest exposes:
    //   .request  — OidcTokenRequest (has .grantType, .tokenEndpoint, etc.)
    //   .headers  — Map<String, String>, mutated in place before the HTTP
    //               call is fired.
    //
    // We inject a fresh DPoP proof on every token request (authorization_code,
    // refresh_token, etc.) because the Solid OP requires it each time.
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
        hookRequest.headers ??= {};
        hookRequest.headers!['DPoP'] = dpopProof;

        return Future.value(hookRequest);
      },
    );

    // Create OIDC hook group and combine any existing hooks with the created
    // dpopTokenHook.
    hooks.token = OidcHookGroup(
      hooks: [if (hooks.token != null) hooks.token!, dpopTokenHook],
      executionHook:
          (hooks.token
              is OidcExecutionHookMixin<
                OidcTokenHookRequest,
                OidcTokenResponse
              >)
          ? hooks.token
                as OidcExecutionHookMixin<
                  OidcTokenHookRequest,
                  OidcTokenResponse
                >
          : dpopTokenHook,
    );

    // Wire the hook into OidcUserManagerSettings.
    final settings = OidcUserManagerSettings(
      // config.strictJwtVerification is intentionally not forwarded: oidc_core
      // 1.0+ removed the corresponding fail-open opt-out entirely, so ID token
      // signature verification is now unconditionally strict. See
      // [SolidOidcConfig.strictJwtVerification] for the retained legacy field.
      scope: scopes,
      frontChannelLogoutUri: config.frontChannelLogoutUri,
      redirectUri: config.redirectUri,
      postLogoutRedirectUri: config.postLogoutRedirectUri,
      hooks: hooks,
      acrValues: config.acrValues,
      display: config.display,
      expiryTolerance: config.expiryTolerance,
      extraAuthenticationParameters: config.extraAuthParameters,
      extraTokenHeaders: config.extraTokenHeaders,
      extraTokenParameters: config.extraTokenParameters,
      uiLocales: config.uiLocales,
      prompt: _getEffectivePrompts(scopes, config),
      maxAge: config.maxAge,
      extraRevocationHeaders: config.extraRevocationHeaders,
      extraRevocationParameters: config.extraRevocationParameters,
      options: config.options,
      frontChannelRequestListeningOptions:
          config.frontChannelRequestListeningOptions,
      refreshBefore: config.refreshBefore,
      getExpiresIn: config.getExpiresIn,
      sessionManagementSettings: config.sessionManagementSettings,
      getIdToken: config.getIdToken,
      supportOfflineAuth: config.supportOfflineAuth,
      userInfoSettings: config.userInfoSettings,
      // oidc_core 2.0+ defaults init() to OidcInitMode.cacheFirst, which
      // returns a possibly-stale cached token immediately and refreshes in
      // the background (a second, later userChanges emission). solid_auth's
      // tryRestoreSession() reads currentAuthData synchronously right after
      // init() resolves, so it needs the pre-2.0 guarantee that init() has
      // already refreshed an expired token by the time it returns.
      initMode: OidcInitMode.blockingValidate,
    );

    final clientAuth = config.clientSecret != null
        ? OidcClientAuthentication.clientSecretPost(
            clientId: config.clientId,
            clientSecret: config.clientSecret!,
          )
        : OidcClientAuthentication.none(clientId: config.clientId);

    // Construct the manager — plain httpClient, no DPoP wrapping needed.
    final manager = metadata != null
        ? OidcUserManager(
            discoveryDocument: metadata.oidcMetadata,
            clientCredentials: clientAuth,
            store: OidcDefaultStore(),
            settings: settings,
            httpClient: config.httpClient,
            keyStore: null,
            id: null,
          )
        : OidcUserManager.lazy(
            discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
              Uri.parse(issuerUri),
            ),
            clientCredentials: clientAuth,
            store: OidcDefaultStore(),
            settings: settings,
            httpClient: config.httpClient,
            keyStore: null,
            id: null,
          );

    // Return OIDC manager and custom key manager
    return (manager: manager, keyManager: keyManager);
  }

  // Check if the current scope contains webid.
  // Solid-OIDC specification require webid to be included in the
  // request scopes. If not available add the webid to the scopes
  static List<String> _ensureWebIdScope(List<String> scopes) {
    if (scopes.contains(SolidScopes.webid)) return scopes;
    _log.warning(
      'webid scope missing from config — adding it automatically '
      '(required by Solid-OIDC spec).',
    );
    return [...scopes, SolidScopes.webid];
  }

  // Calculates the effective prompts for the OIDC authorization request.
  // - Includes all configured prompts from [SolidOidcConfig.prompt]
  // - Automatically adds `consent` when `offline_access` is in the provided scopes
  // - Custom prompts from [SolidOidcConfig.prompt] are preserved
  //
  // Automatic Consent Prompt (Default Behavior)
  //
  // The `consent` prompt is required when requesting `offline_access` because:
  // - Refresh tokens allow long-term access without user interaction
  // - Users must explicitly consent to this enhanced access level
  // - Many OIDC providers require explicit consent for offline access
  //
  // Returns a list of prompt values to be sent to the identity provider
  // during the authorization request.
  static List<String> _getEffectivePrompts(
    List<String> scopes,
    SolidOidcConfig config,
  ) {
    // Default behavior: include configured prompts and add consent for offline_access
    final prompts = <String>{...config.prompt};

    // Automatically add 'consent' prompt when offline_access is requested
    // This ensures users explicitly consent to refresh token capabilities
    if (scopes.contains('offline_access')) {
      prompts.add('consent');
    }

    return prompts.toList()
      // Ensure consistent ordering
      ..sort();
  }
}
