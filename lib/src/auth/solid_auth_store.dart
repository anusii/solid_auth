/// OIDC storage selection for Solid-OIDC sessions.
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
/// Authors: Tony Chen

library;

import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

final _log = Logger('solid_auth.SolidAuthStore');

// Pure-Dart web detection (this package does not depend on Flutter, so we
// cannot use `kIsWeb`). The `dart.library.js_interop` environment flag is set
// by the compiler on web targets (JS and WASM) and absent on native.

const bool _kIsWeb = bool.fromEnvironment('dart.library.js_interop');

// A single shared in-memory store used for the whole web session, so the OIDC
// manager and the session store operate on the same data within a session.

final OidcStore _webMemoryStore = OidcMemoryStore();

// The persistent session-store keys a previous (persistent) build wrote to web
// localStorage; used only to purge them from upgrading clients.

const Set<String> _legacyWebSessionKeys = {
  'solid_auth_issuer_uri',
  'solid_auth_scopes',
  'solid_auth_rsa_private',
  'solid_auth_rsa_public',
};

/// Returns the OIDC store used for DPoP keys, tokens and session state.
///
/// On the **web** platform this is a single shared in-memory store, so the DPoP
/// private key and the OIDC tokens are NEVER written to `localStorage`. On web,
/// `flutter_secure_storage` keeps its AES-GCM key unwrapped in the same
/// `localStorage` as the ciphertext, so persisting these secrets there would
/// let any same-origin script (XSS) or a storage snapshot recover both the
/// tokens and the DPoP private key — defeating DPoP entirely. The trade-off is
/// that a web session does not survive a page reload: the user re-authenticates
/// and a fresh DPoP key pair is generated.
///
/// Native platforms keep the persistent, OS-backed store (`OidcDefaultStore`),
/// so their sessions are restored across app restarts exactly as before.

OidcStore createSolidAuthStore() =>
    _kIsWeb ? _webMemoryStore : OidcDefaultStore();

/// Remove any DPoP private key / session parameters a previous *persistent*
/// build left in web `localStorage`.
///
/// New sessions never write these on web (see [createSolidAuthStore]), but an
/// upgrading client may still have the old, exposed values on disk. This is a
/// best-effort, web-only cleanup; a no-op on native platforms. Short-lived OIDC
/// token entries are left to expire rather than enumerated here.

Future<void> purgeLegacyWebSecrets() async {
  if (!_kIsWeb) {
    return;
  }
  try {
    final persistent = OidcDefaultStore();
    await persistent.init();
    await persistent.removeMany(
      OidcStoreNamespace.secureTokens,
      keys: _legacyWebSessionKeys,
    );
    _log.fine('Purged legacy web session secrets from persistent storage');
  } on Object catch (e) {
    // Never fail login because of a best-effort cleanup.

    _log.fine('purgeLegacyWebSecrets() skipped: ${e.runtimeType}');
  }
}
