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
/// Android and iOS take [OidcDefaultStore]'s own hardened recommendations: an
/// Android-Keystore-backed key on Android, and first-unlock-this-device
/// keychain items (never iCloud-synced) on iOS.
///
/// 20260920 gjw macOS departs from the recommendation, turning OFF the data
/// protection keychain. That keychain requires the app to hold a keychain
/// access group, which comes from the `keychain-access-groups` entitlement or
/// from the `com.apple.application-identifier` an embedded provisioning
/// profile supplies. An app distributed with Developer ID has neither, so
/// every write failed: todopod 1.0.46 logged "tried writing secure tokens
/// using package:flutter_secure_storage, but it failed" and fell back to
/// shared_preferences, while READS returned errSecItemNotFound, which the
/// plugin reports as a plain null rather than an error. Nothing then caught a
/// failure to fall back on, so the PKCE `code_verifier` written before the
/// browser flow read back as null, the code exchange went out without it, and
/// the server answered invalid_grant — surfacing as an RFC 9207 mix-up
/// warning. The legacy file-based keychain needs no entitlement and works for
/// a signed, unsandboxed app. The cost is that `kSecAttrAccessible` is ignored
/// there, so items follow the login keychain rather than being pinned to
/// first-unlock-this-device. An App Store build is sandboxed and ships a
/// provisioning profile, so it can use the data protection keychain: give it
/// its own options rather than reusing these.

OidcDefaultStore createSolidTokenStore() => OidcDefaultStore(
  secureStorageInstance: const FlutterSecureStorage(
    aOptions: OidcDefaultStore.recommendedAndroidOptions,
    iOptions: OidcDefaultStore.recommendedIOSOptions,
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      usesDataProtectionKeychain: false,
    ),
  ),
);
