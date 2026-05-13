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
