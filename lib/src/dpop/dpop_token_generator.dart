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

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import 'package:solid_auth/src/dpop/dpop_key_manager.dart';

final _log = Logger('solid_auth.DpopTokenGenerator');
const _uuid = Uuid();

/// Generates DPoP (Demonstrating Proof-of-Possession) proof tokens per
/// RFC 9449 and the Solid-OIDC specification.
///
/// ## Two kinds of DPoP proof
///
/// ### 1. Token-endpoint proof  (call [generateForTokenEndpoint])
///
/// Sent as the `DPoP` header on the token request to the OP.
/// The OP uses it to key-bind the issued access token by embedding
/// `cnf: { jkt: "<thumbprint>" }` in the token payload.
///
/// ```
/// POST /token
/// DPoP: <proof>            ← no `ath` claim here
/// Content-Type: application/x-www-form-urlencoded
/// ...
/// ```
///
/// ### 2. Resource-server proof  (call [generateForRequest])
///
/// Sent alongside every protected-resource HTTP request.
/// The RS checks:
/// - `htm` matches the HTTP method.
/// - `htu` matches the request URL.
/// - `jti` has not been seen before (replay prevention).
/// - The proof is signed by the key whose thumbprint matches `cnf.jkt`
///   in the access token.
/// - `ath` = base64url(SHA-256(ASCII(access_token))).
///
/// ```
/// PATCH /resource
/// Authorization: DPoP <access_token>
/// DPoP: <proof>            ← includes `ath` claim
/// ```
///
/// The `cnf` error your Solid server returned means the access token was
/// issued WITHOUT step 1 — there was no DPoP proof on the token request.
abstract class DpopTokenGenerator {
  DpopTokenGenerator._();

  // ── Token-endpoint proof ───────────────────────────────────────────────────

  /// Generates a DPoP proof for the **token endpoint request**.
  ///
  /// Must be sent as the `DPoP` header when calling the OP's token endpoint.
  /// Do NOT include an `ath` claim here (there is no access token yet).
  ///
  /// [tokenEndpointUrl] — the OP token endpoint URI (e.g.
  ///   `https://solidcommunity.net/token`).
  static Future<String> generateForTokenEndpoint({
    required String tokenEndpointUrl,
    DpopKeyManager? keyManager,
  }) async {
    final km = keyManager ?? await DpopKeyManager.getInstance();
    _log.fine('Generating DPoP token-endpoint proof for: $tokenEndpointUrl');
    return generate(
      httpMethod: 'POST',
      endpointUrl: tokenEndpointUrl,
      keyPair: km.keyPair,
      publicKeyJwk: km.publicKeyJwk,
      accessToken: null, // no ath on token request
    );
  }

  /// Generates a DPoP proof for [httpMethod] on [endpointUrl], automatically
  /// using the managed key pair from [DpopKeyManager].
  ///
  /// Optionally binds the token to [accessToken] via the `ath` claim
  /// (required by Solid-OIDC for resource server requests).
  static Future<String> generateForRequest({
    required String endpointUrl,
    required String httpMethod,
    String? accessToken,
    DpopKeyManager? keyManager,
  }) async {
    // final keyManager = await DpopKeyManager.getInstance();
    final km = keyManager ?? await DpopKeyManager.getInstance();
    return generate(
      endpointUrl: endpointUrl,
      keyPair: km.keyPair,
      publicKeyJwk: km.publicKeyJwk,
      httpMethod: httpMethod,
      accessToken: accessToken,
    );
  }

  // ── Legacy-compatible static API ─────────────────────────────────────────

  /// Generates a DPoP proof JWT.
  ///
  /// Matches the old `genDpopToken(endPointUrl, rsaKeyPair, publicKeyJwk,
  /// httpMethod)` signature so existing call sites require minimal changes.
  ///
  /// Parameters:
  /// - [endpointUrl] — the URL of the resource being accessed.
  /// - [keyPair]     — RSA key pair (from [DpopKeyManager] or supplied externally).
  /// - [publicKeyJwk] — the public key in JWK format, embedded in the JWT header.
  /// - [httpMethod]  — the HTTP method (GET, POST, PUT, PATCH, DELETE, etc.).
  /// - [accessToken] — when provided, the `ath` claim (SHA-256 of the token)
  ///                   is added, binding the proof to the specific token.
  static String generate({
    required String endpointUrl,
    required KeyPair keyPair,
    required Map<String, dynamic> publicKeyJwk,
    required String httpMethod,
    String? accessToken,
  }) {
    _log.fine('Generating DPoP proof: $httpMethod $endpointUrl');

    final String tokenId = _uuid.v4(); // Unique token ID (replay protection)

    /// Initialising token head and body (payload)
    /// https://solid.github.io/solid-oidc/primer/#authorization-code-pkce-flow
    /// https://datatracker.ietf.org/doc/html/rfc7519
    var tokenHead = {'alg': 'RS256', 'typ': 'dpop+jwt', 'jwk': publicKeyJwk};

    // RFC 9449 §4.2: htu MUST NOT include query or fragment components.
    final parsedUrl = Uri.parse(endpointUrl);
    final htu = Uri(
      scheme: parsedUrl.scheme,
      host: parsedUrl.host,
      port: parsedUrl.hasPort ? parsedUrl.port : null,
      path: parsedUrl.path,
    ).toString();

    final payload = <String, dynamic>{
      'htu': htu,
      'htm': httpMethod.toUpperCase(),
      'jti': tokenId,
      'iat': (DateTime.now().millisecondsSinceEpoch / 1000).round(),
    };

    // `ath` claim: base64url(sha256(ascii(access_token)))
    // Required by Solid-OIDC when the DPoP proof accompanies a resource request.
    if (accessToken != null && accessToken.isNotEmpty) {
      payload['ath'] = _sha256Base64Url(accessToken);
    }

    /// Create a json web token
    final jwt = JWT(
      payload,
      header: tokenHead,
    );

    /// Sign the JWT using private key
    return jwt.sign(
      RSAPrivateKey(keyPair.privateKey),
      algorithm: JWTAlgorithm.RS256,
    );
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  /// Returns the base64url-encoded SHA-256 hash of [input] (ASCII encoded).
  /// Used for the `ath` claim per RFC 9449 §4.2.
  static String _sha256Base64Url(String input) {
    return base64Url
        .encode(sha256.convert(ascii.encode(input)).bytes)
        .replaceAll('=', '');
  }
}
