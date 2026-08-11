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

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';

import 'package:solid_auth/src/auth/solid_auth_store.dart';

final _log = Logger('solid_auth.SolidAuthSessionStore');

/// Holds the Solid-specific parameters needed to restore a previous
/// authentication session on app restart.
///
/// Returned by [SolidAuthSessionStore.loadSession].
class SolidAuthSessionData {
  const SolidAuthSessionData({
    required this.issuerUri,
    required this.scopes,
    required this.privateKeyPem,
    required this.publicKeyPem,
  });

  /// The OIDC issuer URI (e.g. `https://solidcommunity.net`).
  final String issuerUri;

  /// The OAuth scopes that were requested during the original login.
  final List<String> scopes;

  /// PEM-encoded RSA-2048 private key used for DPoP proofs.
  final String privateKeyPem;

  /// PEM-encoded RSA-2048 public key paired with [privateKeyPem].
  final String publicKeyPem;
}

/// Persists and retrieves the Solid-specific authentication parameters that
/// are needed to restore a session across app restarts.
///
/// Uses [OidcDefaultStore] (`OidcStoreNamespace.secureTokens`) with
/// `managerId: null` so the keys do not collide with the OIDC manager's own
/// namespaced token entries.
///
/// ## What is stored
///
/// | Key | Value |
/// |-----|-------|
/// | `solid_auth_issuer_uri` | Resolved OIDC issuer URI |
/// | `solid_auth_scopes` | JSON-encoded scope list |
/// | `solid_auth_rsa_private` | PEM-encoded RSA private key |
/// | `solid_auth_rsa_public` | PEM-encoded RSA public key |
///
/// The OIDC access/refresh tokens themselves are stored by `package:oidc`
/// automatically in the same underlying secure storage — this class only
/// tracks the Solid-specific extras needed to reconstruct the manager.
class SolidAuthSessionStore {
  static const _issuerUriKey = 'solid_auth_issuer_uri';
  static const _scopesKey = 'solid_auth_scopes';
  static const _privateKeyKey = 'solid_auth_rsa_private';
  static const _publicKeyKey = 'solid_auth_rsa_public';

  // Platform-aware store: persistent (OS-backed) on native, in-memory on web
  // so the DPoP private key is never written to localStorage (see
  // [createSolidAuthStore]).
  final OidcStore _store = createSolidAuthStore();

  /// Persists all parameters required to restore this session later.
  ///
  /// Should be called immediately after a successful login.
  Future<void> saveSession({
    required String issuerUri,
    required List<String> scopes,
    required String privateKeyPem,
    required String publicKeyPem,
  }) async {
    await _store.init();
    _log.fine('Saving session for issuer: $issuerUri');
    await _store.setMany(
      OidcStoreNamespace.secureTokens,
      values: {
        _issuerUriKey: issuerUri,
        _scopesKey: jsonEncode(scopes),
        _privateKeyKey: privateKeyPem,
        _publicKeyKey: publicKeyPem,
      },
      managerId: null,
    );
  }

  /// Loads previously saved session parameters.
  ///
  /// Returns `null` if no session has been saved (e.g. first launch or after
  /// logout).
  Future<SolidAuthSessionData?> loadSession() async {
    await _store.init();
    final map = await _store.getMany(
      OidcStoreNamespace.secureTokens,
      keys: {_issuerUriKey, _scopesKey, _privateKeyKey, _publicKeyKey},
      managerId: null,
    );

    final issuerUri = map[_issuerUriKey];
    final privateKeyPem = map[_privateKeyKey];
    final publicKeyPem = map[_publicKeyKey];

    if (issuerUri == null ||
        privateKeyPem == null ||
        publicKeyPem == null ||
        issuerUri.isEmpty ||
        privateKeyPem.isEmpty ||
        publicKeyPem.isEmpty) {
      _log.fine('No stored session found');
      return null;
    }

    final rawScopes = map[_scopesKey];
    final scopes = rawScopes != null
        ? (jsonDecode(rawScopes) as List<dynamic>).cast<String>()
        : <String>[];

    return SolidAuthSessionData(
      issuerUri: issuerUri,
      scopes: scopes,
      privateKeyPem: privateKeyPem,
      publicKeyPem: publicKeyPem,
    );
  }

  /// Removes all stored session parameters.
  ///
  /// Should be called on logout or when the session is no longer valid.
  Future<void> clearSession() async {
    await _store.init();
    _log.fine('Clearing stored session');
    await _store.removeMany(
      OidcStoreNamespace.secureTokens,
      keys: {_issuerUriKey, _scopesKey, _privateKeyKey, _publicKeyKey},
      managerId: null,
    );
  }
}
