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
/// Authors: Graham Williams
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

/// Builds the store used for everything solid_auth persists between runs.
///
/// Every [OidcDefaultStore] in solid_auth must come from here. The
/// [FlutterSecureStorage] instance is required, not optional: without it
/// [OidcDefaultStore] falls back to `package:shared_preferences` for its
/// `secureTokens` namespace, and that namespace holds the whole set of
/// credentials — the access, refresh and ID tokens and the PKCE
/// `code_verifier` written by `package:oidc`, plus the DPoP RSA private key
/// written by `SolidAuthSessionStore`. On disk in the clear, the refresh token
/// lets anything able to read the app's preferences file mint access tokens
/// for the user's POD without their password, and the DPoP private key is what
/// binds those tokens to this client, so leaking the pair is full
/// impersonation. Ordinary home-directory backups collect the file
/// (RFC 9700 §4.14).
///
/// The per-platform options are [OidcDefaultStore]'s own hardened
/// recommendations on Android and iOS: an Android-Keystore-backed key, and
/// first-unlock-this-device keychain items (never iCloud-synced).
///
/// macOS takes those same recommendations with one change:
/// `usesDataProtectionKeychain` is turned OFF. `flutter_secure_storage`
/// defaults it on, and the macOS data protection keychain is reachable only by
/// a process that carries a keychain access group — either declared as the
/// restricted `keychain-access-groups` entitlement, or defaulted from the
/// `com.apple.application-identifier` that an embedded provisioning profile
/// supplies. Developer ID distribution embeds no profile, so a notarized app
/// has neither, and the OS then answers asymmetrically:
///
/// - `SecItemAdd` fails with `errSecMissingEntitlement` (-34018). The plugin
///   turns that into a `PlatformException`, [OidcDefaultStore] catches it and
///   silently falls back to `package:shared_preferences` — so the secret is
///   written, in the clear, to the app's plist.
/// - `SecItemCopyMatching` returns `errSecItemNotFound` (-25300), which is not
///   an error at all. The plugin returns null, [OidcDefaultStore] reads that as
///   "never stored" and does NOT fall back — so the value just written is
///   invisible.
///
/// Every secret in this namespace is therefore both leaked to disk and lost on
/// read. For `package:oidc` 4.x that includes the PKCE `code_verifier` (stored
/// under `code_verifier.<state id>`), so the code exchange goes out without
/// one and the OP rejects it with `invalid_grant - PKCE verification failed`:
/// login is impossible in a notarized build.
///
/// Turning the flag off moves macOS to the file-based (login) keychain, which
/// needs no entitlement, works whether or not the app is sandboxed, and is
/// where a Developer ID app's secrets belong. `accessibility` is a data
/// protection attribute and is simply ignored there.
///
/// 20260920 tonypioneer Diagnosed against the notarized todopod 1.0.46 DMG.

OidcDefaultStore createSolidTokenStore() => OidcDefaultStore(
  secureStorageInstance: const FlutterSecureStorage(
    aOptions: OidcDefaultStore.recommendedAndroidOptions,
    iOptions: OidcDefaultStore.recommendedIOSOptions,
    mOptions: macOsKeychainOptions,
  ),
);

/// The macOS keychain options used for everything solid_auth persists.
///
/// [OidcDefaultStore.recommendedMacOsOptions] with the data protection
/// keychain turned off — see [createSolidTokenStore] for why that flag cannot
/// be left on in a Developer ID build.

const MacOsOptions macOsKeychainOptions = MacOsOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
  usesDataProtectionKeychain: false,
);
