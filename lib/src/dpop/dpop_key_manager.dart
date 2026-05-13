import 'dart:convert';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:logging/logging.dart';

final _log = Logger('solid_auth.DpopKeyManager');

/// Manages the RSA key pair used for generating DPoP proofs.
///
/// DPoP (Demonstrating Proof-of-Possession) binds an access token to a
/// specific key pair so that the token cannot be replayed by another party.
///
/// Reference: https://datatracker.ietf.org/doc/html/rfc9449
///
/// The key pair is generated once per session and cached. For long-running
/// apps you may want to rotate the key pair periodically.
class DpopKeyManager {
  DpopKeyManager._({
    required this.keyPair,
    required this.publicKeyJwk,
  });

  /// The RSA key pair — both private and public key in PEM format.
  final KeyPair keyPair;

  /// The public key as a JSON Web Key (JWK) map, included in every DPoP proof
  /// header under `"jwk"`.
  final Map<String, dynamic> publicKeyJwk;

  static DpopKeyManager? _instance;

  /// Generates a new RSA-2048 key pair and returns a [DpopKeyManager].
  ///
  /// The result is cached for the lifetime of the process. Call [rotate] to
  /// generate a fresh pair (e.g. after a long idle period).
  static Future<DpopKeyManager> getInstance() async {
    if (_instance != null) return _instance!;
    return rotate();
  }

  /// Generates a new key pair, replacing any cached instance.
  static Future<DpopKeyManager> rotate() async {
    _log.fine('Generating new RSA-2048 key pair for DPoP');
    final keyPair = await RSA.generate(2048);
    final jwk = await _publicKeyToJwk(keyPair.publicKey);
    _instance = DpopKeyManager._(keyPair: keyPair, publicKeyJwk: jwk);
    _log.fine('DPoP key pair ready (kid: ${jwk['kid']})');
    return _instance!;
  }

  /// Clears the cached key pair (e.g. on logout).
  static void clear() {
    _instance = null;
  }

  // ── JWK conversion ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _publicKeyToJwk(
    String publicKeyPem,
  ) async {
    // fast_rsa can export a public key as a PKCS#1 DER and we convert to JWK.
    final jwkJson = await RSA.convertPublicKeyToJWK(publicKeyPem);
    final jwk = jsonDecode(jwkJson) as Map<String, dynamic>;
    // Ensure the key type is set correctly for RS256.
    return {
      'kty': 'RSA',
      'use': 'sig',
      'alg': 'RS256',
      ...jwk,
    };
  }
}
