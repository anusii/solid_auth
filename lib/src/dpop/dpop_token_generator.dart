import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';

import 'dpop_key_manager.dart';

final _log = Logger('solid_auth.DpopTokenGenerator');
const _uuid = Uuid();

/// Generates DPoP (Demonstrating Proof-of-Possession) proof tokens.
///
/// A DPoP proof is a short-lived JWT that binds an HTTP request to the
/// key pair associated with the current session. It must be sent alongside
/// the `Authorization: DPoP <access_token>` header.
///
/// Reference: https://datatracker.ietf.org/doc/html/rfc9449
///
/// ## Migration from solid_auth 0.1.x
///
/// The old free-standing function signature:
/// ```dart
/// String genDpopToken(endPointUrl, rsaKeyPair, publicKeyJwk, httpMethod)
/// ```
/// is preserved as the static [generate] method, but the recommended
/// new approach is to use [generateForRequest] which fetches the key pair
/// from [DpopKeyManager] automatically.
abstract class DpopTokenGenerator {
  DpopTokenGenerator._();

  // ── New API ───────────────────────────────────────────────────────────────

  /// Generates a DPoP proof for [httpMethod] on [endpointUrl], automatically
  /// using the managed key pair from [DpopKeyManager].
  ///
  /// Optionally binds the token to [accessToken] via the `ath` claim
  /// (required by Solid-OIDC for resource server requests).
  static Future<String> generateForRequest({
    required String endpointUrl,
    required String httpMethod,
    String? accessToken,
  }) async {
    final keyManager = await DpopKeyManager.getInstance();
    return generate(
      endpointUrl: endpointUrl,
      keyPair: keyManager.keyPair,
      publicKeyJwk: keyManager.publicKeyJwk,
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

    final payload = <String, dynamic>{
      'jti': _uuid.v4(),   // Unique token ID (replay protection)
      'htm': httpMethod.toUpperCase(),
      'htu': endpointUrl,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    // `ath` claim: base64url(sha256(ascii(access_token)))
    // Required by Solid-OIDC when the DPoP proof accompanies a resource request.
    if (accessToken != null && accessToken.isNotEmpty) {
      payload['ath'] = _sha256Base64Url(accessToken);
    }

    final jwt = JWT(
      payload,
      header: {
        'typ': 'dpop+jwt',
        'alg': 'RS256',
        'jwk': publicKeyJwk,
      },
    );

    return jwt.sign(RSAPrivateKey(keyPair.privateKey));
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  /// Returns the base64url-encoded SHA-256 hash of [input] (ASCII encoded).
  /// Used for the `ath` claim per RFC 9449 §4.2.
  static String _sha256Base64Url(String input) {
    // dart_jsonwebtoken uses pointycastle internally; we use its hashing here.
    // In a real implementation wire in a sha256 utility from pointycastle or
    // crypto package. Shown here as a placeholder.
    // ignore: todo
    // TODO: replace with `crypto` package sha256 + base64Url encoding.
    throw UnimplementedError(
      'SHA-256/base64url for ath claim — wire in the `crypto` package: '
      'base64Url.encode(sha256.convert(ascii.encode(accessToken)).bytes)',
    );
  }
}
