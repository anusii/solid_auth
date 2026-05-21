# solid_auth

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)

[![GitHub License](https://img.shields.io/github/license/anusii/solid_auth)](https://raw.githubusercontent.com/anusii/solid_auth/dev/LICENSE)
[![GitHub Version](https://img.shields.io/badge/dynamic/yaml?url=https://raw.githubusercontent.com/anusii/solid_auth/master/pubspec.yaml&query=$.version&label=version&logo=github)](https://github.com/anusii/solid_auth/blob/dev/CHANGELOG.md)
[![Pub Version](https://img.shields.io/pub/v/solid_auth?label=pub.dev&labelColor=333940&logo=flutter)](https://pub.dev/packages/solid_auth)
[![GitHub Last Updated](https://img.shields.io/github/last-commit/anusii/solid_auth?label=last%20updated)](https://github.com/anusii/solid_auth/commits/dev/)
[![GitHub Commit Activity (main)](https://img.shields.io/github/commit-activity/w/anusii/solid_auth/dev)](https://github.com/anusii/solid_auth/commits/dev/)
[![GitHub Issues](https://img.shields.io/github/issues/anusii/solid_auth)](https://github.com/anusii/solid_auth/issues)

Solid-OIDC authentication for Flutter apps. Handles Authorization Code + PKCE, DPoP key binding (RFC 9449), and WebID-based issuer discovery. This package is built on the OpenID-certified [`package:oidc`](https://pub.dev/packages/oidc).

---

## Features

- **Solid-OIDC login** via Authorization Code + PKCE on all platforms (Android, iOS, Web, Windows, macOS, Linux)
- **DPoP key binding** - generates and manages RSA-2048 key pairs; injects DPoP proof headers automatically at every token request
- **Session persistence** - saves tokens and DPoP keys to secure storage; silently restores sessions on app restart
- **WebID issuer discovery** - resolves an OIDC issuer from any WebID profile URL
- **Typed auth result** (`SolidAuthData`) - replaces the old raw `Map<String, dynamic>`

---

## Installation

```yaml
dependencies:
  solid_auth: ^0.2.0
```

<!-- If your app targets **web**, also declare the `fast_rsa` WASM worker assets in your app's `pubspec.yaml` (the package omits them from its own asset list):

```yaml
flutter:
  assets:
    - packages/fast_rsa/web/assets/worker.js
    - packages/fast_rsa/web/assets/wasm_exec.js
    - packages/fast_rsa/web/assets/rsa.wasm
``` -->

---

## Quick Start

```dart
import 'package:solid_auth/solid_auth.dart';

// 1. Create the manager once (e.g. at widget level or in a provider).
final auth = SolidAuthManager(
  config: SolidOidcConfig(
    clientId: 'https://your-domain/client-profile.jsonld',
    redirectUri: Uri.parse('https://your-domain/redirect.html'),
    postLogoutRedirectUri: Uri.parse('https://your-domain/redirect.html'),
    scopes: SolidScopes.defaultScopes, // includes `webid` automatically
  ),
);

// 2. Login — resolves issuer from WebID, then runs Authorization Code + PKCE.
final authData = await auth.authenticate(
  'https://pods.solidcommunity.au/alice-barnes/profile/card#me',
);
print(authData.webId);        // https://pods.solidcommunity.au/alice-barnes/profile/card#me
print(authData.accessToken);

// 3. Generate a DPoP proof for a protected resource request.
final dpop = await DpopTokenGenerator.generateForRequest(
  endpointUrl: 'https://pods.solidcommunity.au/alice-barnes/notepod/data/notes.ttl',
  httpMethod: 'GET',
  accessToken: authData.accessToken,
  keyManager: auth.keyManager, // must be the same key bound to the access token
);
// Use in HTTP headers:
//   'Authorization': 'DPoP ${authData.accessToken}'
//   'DPoP': dpop

// 4. Logout.
await auth.logout();
```

---

## Session Restore

After a successful login, `solid_auth` automatically saves the session (OIDC tokens + DPoP key pair) to platform-native secure storage. On the next app launch you can resume without requiring the user to log in again:

```dart
// Call this in initState before showing the login UI.
final auth = SolidAuthManager(config: SolidOidcConfig(...));

final data = await auth.tryRestoreSession();
if (data != null) {
  // Valid session found — navigate directly to the authenticated screen.
  print('Welcome back, ${data.webId}');
} else {
  // No stored session — show the login screen.
}
```

`tryRestoreSession()` returns `null` if no session exists, if the refresh token has expired, or if any storage error occurs (in which case the stored session is cleared so the next login starts clean).

Calling `logout()` or `forgetUser()` always clears the stored session.

---

## DPoP for Resource Requests

Every request to a Solid server protected resource needs both an `Authorization` header and a fresh DPoP proof. The proof must be signed by the **same** RSA key that was active during login (the access token's `cnf.jkt` claim is bound to it):

```dart
Future<http.Response> getPrivateResource(
  SolidAuthManager auth,
  String resourceUrl,
) async {
  final authData = auth.currentAuthData!;

  final dpop = await DpopTokenGenerator.generateForRequest(
    endpointUrl: resourceUrl,
    httpMethod: 'GET',
    accessToken: authData.accessToken,
    keyManager: auth.keyManager,
  );

  return http.get(
    Uri.parse(resourceUrl),
    headers: {
      'Authorization': 'DPoP ${authData.accessToken}',
      'DPoP': dpop,
    },
  );
}
```

> **Important:** Always pass `keyManager: auth.keyManager`. The default (`DpopKeyManager.getInstance()`) returns the current singleton, which may be a freshly-generated key after an app restart, producing a thumbprint that the server will reject.

---

## Platform Setup

`redirectUri` and `postLogoutRedirectUri` must be registered in your [client ID document](https://solid.github.io/solid-oidc/#clientids-document) (`client-profile.jsonld`) and match the correct format for each platform:

| Platform | URI format | Notes |
|---|---|---|
| Web | `https://your-domain/redirect.html` | Must be same origin as the app - `oidc` uses `BroadcastChannel` (same-origin only) |
| Android / iOS | `com.example.app://redirect` | Custom URI scheme registered with the OS |
| Windows / Linux / macOS | `http://localhost:4400/redirect` | **Fixed port required** - see below |

### Desktop: use a fixed port

`oidc_desktop` binds a loopback HTTP server to the port in your `redirectUri`. If you use port `0`, the OS assigns a random port that is never registered in the client document, causing the Solid server to reject logout with `post_logout_redirect_uri not registered`. Use a fixed port (e.g. `4400`) in both the app and the client document.

Both `redirect_uris` and `post_logout_redirect_uris` in the client ID document must list every URI used across platforms:

```json
{
  "redirect_uris": [
    "https://your-domain/redirect.html",
    "http://localhost:4400/redirect"
  ],
  "post_logout_redirect_uris": [
    "https://your-domain/redirect.html",
    "http://localhost:4400/redirect"
  ]
}
```

For Android, iOS, and other platform-specific setup steps (manifest entries, URL schemes, etc.), follow the [`package:oidc` Getting Started guide](https://bdaya-dev.github.io/oidc/oidc-getting-started/).

---

## Migration Guide - 0.1.x → 0.2.x

> [!IMPORTANT]
> Upgrading from `0.1.x` to `0.2.x` is a **breaking change**. The underlying architecture has been re-engineered. The forked `openid_client` is replaced by the OpenID-certified `package:oidc`, and the top-level `authenticate()` function is replaced by `SolidAuthManager`. Please review the full README and use the table below to update your call sites.

| Old (0.1.x) | New (0.2.x) |
|---|---|
| `String issuer = await getIssuer(webId)` | `WebIdUtils.getIssuer(webId)` (same signature) |
| `var data = await authenticate(issuerUri, scopes)` | `await SolidAuthManager.authenticate(webIdOrIssuer)` - returns `SolidAuthData` |
| `data['accessToken']` | `authData.accessToken` |
| `data['idToken']` | `authData.idToken` |
| `genDpopToken(url, keyPair, jwk, method)` | `DpopTokenGenerator.generateForRequest(endpointUrl:, httpMethod:, accessToken:, keyManager: auth.keyManager)` |
| `fetchProfileData(webId)` | Removed - use `http` + parse the Turtle response directly |
| *(new)* | `auth.tryRestoreSession()` - silent session restore on app startup |
