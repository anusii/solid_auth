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

/// Data returned after a successful Solid-OIDC authentication.
///
/// Replaces the raw `Map<String, dynamic>` previously returned by
/// `authenticate()`, giving callers typed access to all token fields.
class SolidAuthData {
  const SolidAuthData({
    required this.accessToken,
    required this.idToken,
    this.refreshToken,
    required this.webId,
    required this.issuer,
    required this.expiresAt,
    this.rawClaims = const {},
  });

  /// The OAuth 2.0 access token. Used as a Bearer token in HTTP requests,
  /// or as the `ath` claim in a DPoP proof.
  final String accessToken;

  /// The OpenID Connect ID token (JWT). Contains the `webid` claim for
  /// Solid-OIDC compliant providers.
  final String idToken;

  /// The refresh token (if `offline_access` scope was requested).
  final String? refreshToken;

  /// The authenticated user's WebID URI, extracted from the ID token.
  final String webId;

  /// The issuer URI of the Solid identity provider.
  final String issuer;

  /// Token expiry time (derived from the `exp` claim in the access token).
  final DateTime expiresAt;

  /// Full decoded claims from the ID token for advanced use-cases.
  final Map<String, dynamic> rawClaims;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Convenience: returns auth headers for a plain Bearer request (no DPoP).
  Map<String, String> get bearerHeaders => {
    'Authorization': 'Bearer $accessToken',
  };

  @override
  String toString() =>
      'SolidAuthData(webId: $webId, issuer: $issuer, expired: $isExpired)';
}
