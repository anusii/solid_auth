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
import 'package:oidc/oidc.dart';

import 'package:solid_auth/src/utils/solid_scopes.dart';

/// Configuration for building an [OidcUserManager] targeted at a Solid POD.
///
/// Includes fine-grained control over the OpenID Connect authentication
/// process, including security settings, token management, and platform-specific
/// behaviors. It extends the standard OIDC configuration with Solid-specific
/// requirements and optimizations.
///
/// Example
///
/// Used internally by [SolidOidcManagerFactory], but may be exposed for advanced
/// use cases requiring custom OIDC flow configuration:
///
/// ```dart
/// final settings = SolidOidcConfig(
///   clientId: 'my_client_id'
///   redirectUri: Uri.parse('https://myapp.com/callback'),
///   refreshBefore: Duration(minutes: 5),
/// );
/// ```
/// Solid-Specific Defaults
///
/// This class provides sensible defaults for Solid OIDC:
/// - Default scopes: `['openid', 'webid', 'offline_access']` (recommended for Flutter apps)
/// - Automatic `consent` prompt when `offline_access` scope is requested
/// - WebID discovery integration via [getIssuers]
/// - DPoP token support for enhanced security
/// - Automatic session restoration capabilities
///
/// cope Usage in Solid
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
class SolidOidcConfig {
  const SolidOidcConfig({
    required this.clientId,
    required this.redirectUri,
    this.postLogoutRedirectUri,
    this.scopes = SolidScopes.defaultScopes,
    this.clientSecret,
    this.httpClient,
    this.uiLocales,
    this.extraTokenHeaders,
    this.prompt = const [],
    this.display,
    this.acrValues,
    this.maxAge,
    this.expiryTolerance = const Duration(minutes: 1),
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

  /// see [OidcTokenRequest.extra]
  final Map<String, String>? extraTokenHeaders;

  /// see [OidcRevocationRequest.extra]
  final Map<String, dynamic>? extraRevocationParameters;

  /// Extra headers to send with the revocation request.
  final Map<String, String>? extraRevocationHeaders;

  /// see [OidcIdTokenVerificationOptions.expiryTolerance].
  final Duration expiryTolerance;

  /// platform-specific options.
  final OidcPlatformSpecificOptions? options;

  /// the uri of the front channel logout flow.
  /// this Uri MUST be registered with the OP first.
  /// the OP will call this Uri when it wants to logout the user.
  final Uri? frontChannelLogoutUri;

  /// Settings to control using the user_info endpoint.
  final OidcUserInfoSettings userInfoSettings;

  /// The options to use when listening to platform channels.
  ///
  /// [frontChannelLogoutUri] must be set for this to work.
  final OidcFrontChannelRequestListeningOptions
  frontChannelRequestListeningOptions;

  /// How early the token gets refreshed.
  ///
  /// for example:
  ///
  /// - if `Duration.zero` is returned, the token gets refreshed once it's expired.
  /// - (default) if `Duration(minutes: 1)` is returned, it will refresh the token 1 minute before it expires.
  /// - if `null` is returned, automatic refresh is disabled.
  final OidcRefreshBeforeCallback? refreshBefore;

  /// Settings related to the session management spec.
  final OidcSessionManagementSettings sessionManagementSettings;

  /// pass this function to control how an `id_token` is fetched from a
  /// token response.
  ///
  /// This can be used to trick the user manager into using a JWT `access_token`
  /// as an `id_token` for example.
  final Future<String?> Function(OidcToken token)? getIdToken;

  /// Whether to support offline authentication or not.
  ///
  /// When this option is enabled, expired tokens will NOT be removed if the
  /// server can't be contacted
  ///
  /// This parameter is disabled by default due to security concerns.
  final bool supportOfflineAuth;

  /// Customized hooks to modify the user manager behavior.
  final OidcUserManagerHooks? hooks;

  /// Legacy no-op, retained only for source compatibility.
  ///
  /// `package:oidc` 1.0+ removed the fail-open opt-out this used to control.
  /// ID token signature verification is now unconditionally strict regardless
  /// of this value. Kept as a field so existing call sites setting it don't
  /// fail to compile; it is no longer read by [SolidOidcManagerFactory].
  final bool strictJwtVerification;

  /// overrides a token's expires_in value.
  final Duration? Function(OidcTokenResponse tokenResponse)? getExpiresIn;

  /// Extra parameters sent with every token request.
  final Map<String, dynamic>? extraTokenParameters;

  /// Extra parameters sent with every authorization request.
  final Map<String, dynamic>? extraAuthParameters;
}
