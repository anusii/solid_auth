/// Scope constants used in Solid-OIDC authentication requests.
///
/// Standard OpenID Connect scopes plus the `webid` scope mandated by the
/// Solid-OIDC specification for identity binding.
///
/// Reference: https://solid.github.io/solid-oidc/#scopes
abstract class SolidScopes {
  // ── Standard OIDC scopes ──────────────────────────────────────────────────

  /// Required by all OIDC flows; enables the ID token.
  static const String openid = 'openid';

  /// Requests basic profile claims (name, picture, etc.).
  static const String profile = 'profile';

  /// Requests the user's email address.
  static const String email = 'email';

  /// Requests a refresh token so the session can be renewed silently.
  static const String offlineAccess = 'offline_access';

  // ── Solid-specific scopes ─────────────────────────────────────────────────

  /// **Solid-OIDC mandatory scope.** Requests that the `webid` claim be
  /// included in the ID token. Without this the Solid identity binding
  /// cannot be established.
  static const String webid = 'webid';

  // ── Convenience groupings ─────────────────────────────────────────────────

  /// Minimal scope set for read-only, session-less access to a Solid POD.
  static const List<String> minimal = [openid, webid];

  /// Default scope set — mirrors the previous `solid_auth` defaults and
  /// enables token refresh.
  static const List<String> defaultScopes = [
    openid,
    profile,
    offlineAccess,
    webid,
  ];

  /// Full scope set including email.
  static const List<String> full = [
    openid,
    profile,
    email,
    offlineAccess,
    webid,
  ];
}
