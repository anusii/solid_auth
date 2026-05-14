import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';

import 'dpop_key_manager.dart';

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
    return _build(
      httpMethod: 'POST',
      endpointUrl: tokenEndpointUrl,
      keyPair: km.keyPair,
      publicKeyJwk: km.publicKeyJwk,
      accessToken: null, // no ath on token request
    );
  }

  // ── Resource-server proof ──────────────────────────────────────────────────

  /// Generates a DPoP proof for a **protected resource request**.
  ///
  /// Automatically fetches the key pair from [DpopKeyManager.getInstance].
  /// The [accessToken] is required — it is hashed into the `ath` claim which
  /// binds the proof to the specific token being used.
  static Future<String> generateForRequest({
    required String endpointUrl,
    required String httpMethod,
    required String accessToken,
    DpopKeyManager? keyManager,
  }) async {
    final km = keyManager ?? await DpopKeyManager.getInstance();
    _log.fine('Generating DPoP resource proof: $httpMethod $endpointUrl');
    return _build(
      httpMethod: httpMethod,
      endpointUrl: endpointUrl,
      keyPair: km.keyPair,
      publicKeyJwk: km.publicKeyJwk,
      accessToken: accessToken,
    );
  }

  // ── Legacy-compatible static method ────────────────────────────────────────

  /// Drop-in replacement for the old `genDpopToken(url, keyPair, jwk, method)`.
  ///
  /// Provide [accessToken] for resource requests (adds `ath` claim).
  /// Omit it when generating a token-endpoint proof.
  static String generate({
    required String endpointUrl,
    required KeyPair keyPair,
    required Map<String, dynamic> publicKeyJwk,
    required String httpMethod,
    String? accessToken,
  }) {
    return _build(
      httpMethod: httpMethod,
      endpointUrl: endpointUrl,
      keyPair: keyPair,
      publicKeyJwk: publicKeyJwk,
      accessToken: accessToken,
    );
  }

  // ── Core builder ───────────────────────────────────────────────────────────

  static String _build({
    required String httpMethod,
    required String endpointUrl,
    required KeyPair keyPair,
    required Map<String, dynamic> publicKeyJwk,
    String? accessToken,
  }) {
    final payload = <String, dynamic>{
      'jti': _uuid.v4(),
      'htm': httpMethod.toUpperCase(),
      'htu': endpointUrl,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    // ath = base64url(SHA-256(ASCII(access_token))) per RFC 9449 §4.2
    // Required on resource requests; MUST be absent on token-endpoint proofs.
    if (accessToken != null && accessToken.isNotEmpty) {
      payload['ath'] = _sha256Base64Url(accessToken);
    }

    final jwt = JWT(
      payload,
      header: JWTHeader(
        algorithm: JWTAlgorithm.RS256,
        typ: 'dpop+jwt',
        // The public key in JWK form is embedded directly in the JWT header.
        // This allows the RS to verify the signature without a key lookup.
        extra: {'jwk': publicKeyJwk},
      ),
    );

    return jwt.sign(RSAPrivateKey(keyPair.privateKey));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// base64url( SHA-256( ASCII( token ) ) ), no padding.
  static String _sha256Base64Url(String token) {
    final bytes = utf8.encode(token); // ASCII subset is valid UTF-8
    final digest = sha256.convert(bytes);
    return base64Url
        .encode(Uint8List.fromList(digest.bytes))
        .replaceAll('=', '');
  }
}
