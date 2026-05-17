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
