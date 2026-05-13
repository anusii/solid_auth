# solid_auth (restructured)

Solid-OIDC authentication for Flutter, now built on the
[OpenID-certified `oidc` package](https://pub.dev/packages/oidc).

---

## Architecture overview

```
solid_auth (public API)
│
├── SolidAuthManager              ← main facade (replaces authenticate())
│     ├── loginFromWebId()        ← resolves issuer, then logs in
│     ├── login()                 ← direct login given issuer URI
│     ├── currentAuthData         ← typed SolidAuthData (not a raw Map)
│     ├── authChanges             ← Stream<SolidAuthData?> (like Firebase Auth)
│     └── logout() / dispose()
│
├── SolidOidcManagerFactory       ← wires SolidOidcConfig → OidcUserManager
│     └── create()
│
├── DpopTokenGenerator            ← DPoP proof JWT generation (unchanged logic)
│     ├── generateForRequest()    ← new: auto-fetches key from DpopKeyManager
│     └── generate()             ← legacy-compatible static method
│
├── DpopKeyManager                ← RSA key-pair lifecycle
├── ProfileFetcher                ← replaces fetchProfileData()
│     └── fetchProfile() → SolidProfile
│
└── WebIdUtils                    ← replaces getIssuer()
      ├── getIssuer()
      └── getProviderMetadata() → SolidProviderMetadata
```

### Dependency map

```
solid_auth
 └── package:oidc          (OidcUserManager, OidcUserManagerSettings, etc.)
      └── oidc_core         (OidcProviderMetadata, OidcToken, etc.)
      └── oidc_default_store (secure token persistence)
 └── dart_jsonwebtoken     (DPoP JWT signing — kept)
 └── fast_rsa              (RSA key generation — kept)
```

The entire forked `openid_client` code is **removed**. All OIDC discovery,
PKCE, token exchange and refresh is delegated to `package:oidc`.

---

## Migration guide — 0.1.x → 0.2.x

| Old (0.1.x)                                          | New (0.2.x)                                        |
|------------------------------------------------------|----------------------------------------------------|
| `String issuer = await getIssuer(webId)`             | `WebIdUtils.getIssuer(webId)` (same signature)     |
| `var data = await authenticate(issuerUri, scopes)`   | `SolidAuthManager.loginFromWebId(webId)` returns `SolidAuthData` |
| `data['accessToken']`                                | `authData.accessToken`                             |
| `data['idToken']`                                    | `authData.idToken`                                 |
| `genDpopToken(url, keyPair, jwk, method)`            | `DpopTokenGenerator.generate(...)` (same params)   |
| `fetchProfileData(webId)`                            | `ProfileFetcher().fetchProfile(webId)`             |

---

## Quick start

```dart
import 'package:solid_auth/solid_auth.dart';

// 1. Create the manager (once, at app level)
final auth = SolidAuthManager(
  config: SolidOidcConfig(
    clientId: 'my_client_id',
    redirectUri: Uri.parse('com.example.app://callback'),
    scopes: SolidScopes.defaultScopes, // includes webid automatically
  ),
);

// 2. Login — resolves issuer from WebID, then runs Authorization Code + PKCE
final authData = await auth.loginFromWebId(
  'https://charlieb.solidcommunity.net/profile/card#me',
);
print(authData.webId);      // https://charlieb.solidcommunity.net/profile/card#me
print(authData.accessToken);

// 3. Generate a DPoP proof for a resource request
final dpop = await DpopTokenGenerator.generateForRequest(
  endpointUrl: 'https://charlieb.solidcommunity.net/private/notes.ttl',
  httpMethod: 'GET',
  accessToken: authData.accessToken,
);
// Use in HTTP headers:
// 'Authorization': 'DPoP ${authData.accessToken}'
// 'DPoP': dpop

// 4. Fetch public profile
final profile = await ProfileFetcher().fetchProfile(authData.webId);
print(profile.name);
print(profile.storage);

// 5. Logout
await auth.logout();
```

---

## Platform setup

Platform-specific setup (Android `build.gradle`, iOS `Info.plist`,
web `redirect.html`, etc.) follows `package:oidc` requirements exactly.
See the [oidc Getting Started guide](https://bdaya-dev.github.io/oidc/oidc-getting-started/).

The old `callback.html` for web should be replaced by the
[`redirect.html`](https://github.com/Bdaya-Dev/oidc/blob/main/packages/oidc/example/web/redirect.html)
from `package:oidc`.
