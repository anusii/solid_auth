import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:logging/logging.dart';

final _log = Logger('solid_auth.DpopKeyManager');

/// Manages the RSA key pair used for DPoP proofs.
///
/// ## Why this must be created BEFORE authentication
///
/// Solid-OIDC requires DPoP key binding at the **token endpoint** level
/// (RFC 9449 §5). The client MUST send a DPoP proof JWT as the `DPoP`
/// HTTP header on the token endpoint request. The OP then:
///
/// 1. Validates the proof.
/// 2. Computes `jkt` = base64url(SHA-256(RFC 7638 JWK thumbprint)).
/// 3. Embeds `cnf: { jkt: "…" }` in the issued access token.
///
/// A Resource Server verifying a `PATCH` / `GET` / etc. request later
/// checks that the DPoP proof was signed by the key whose thumbprint
/// matches `cnf.jkt` in the access token.
///
/// If the token was issued WITHOUT a DPoP proof at token-request time
/// there is no `cnf` claim at all, and the RS returns:
///
/// > "Expected object property cnf, got: [object Object]"
///
/// **Fix**: generate the key pair here ONCE, inject it into every token
/// request via a `package:oidc` token hook, and reuse the same key pair
/// for all subsequent resource-level DPoP proofs.
class DpopKeyManager {
  DpopKeyManager._({
    required this.keyPair,
    required this.publicKeyJwk,
    required this.jkt,
  });

  /// RSA-2048 key pair (PEM-encoded).
  final KeyPair keyPair;

  /// Public key as a JWK map — embedded in every DPoP proof JWT header.
  final Map<String, dynamic> publicKeyJwk;

  /// JWK thumbprint (RFC 7638, SHA-256, base64url, no padding).
  ///
  /// This is what the OP stores as `cnf.jkt` inside the access token.
  /// Resource Servers use this value to confirm the proof was signed by
  /// the same key that was presented at token-issuance time.
  final String jkt;

  // ── Singleton ─────────────────────────────────────────────────────────────

  static DpopKeyManager? _instance;

  /// Returns the cached key manager, generating a fresh pair if none exists.
  ///
  /// Call **before** starting the auth flow so the key is ready when the
  /// token-endpoint hook fires.
  static Future<DpopKeyManager> getInstance() async {
    return _instance ??= await _generate();
  }

  /// Generates a new RSA-2048 pair and replaces the cached instance.
  ///
  /// Use on logout or to rotate the DPoP binding key.
  static Future<DpopKeyManager> rotate() async {
    _instance = null;
    return getInstance();
  }

  /// Clears the cached instance (call on logout).
  static void clear() {
    _instance = null;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static Future<DpopKeyManager> _generate() async {
    _log.fine('Generating RSA-2048 DPoP key pair');
    final keyPair = await RSA.generate(2048);
    final jwk = await _buildJwk(keyPair.publicKey);
    final jkt = _computeJkt(jwk);
    _log.fine('DPoP key pair ready — jkt: $jkt');
    return DpopKeyManager._(keyPair: keyPair, publicKeyJwk: jwk, jkt: jkt);
  }

  /// Builds an RSA JWK from PEM. Only kty/n/e are strictly required for the
  /// thumbprint; alg/use are added for RS compatibility.
  static Future<Map<String, dynamic>> _buildJwk(String publicKeyPem) async {
    final jwkJson = await RSA.convertPublicKeyToJWK(publicKeyPem);
    final raw = jsonDecode(jwkJson) as Map<String, dynamic>;
    return <String, dynamic>{
      'kty': 'RSA',
      'use': 'sig',
      'alg': 'RS256',
      if (raw['n'] != null) 'n': raw['n'],
      if (raw['e'] != null) 'e': raw['e'],
    };
  }

  /// RFC 7638 §3.2 — JWK thumbprint for RSA keys.
  ///
  /// Required members in lexicographic order: e, kty, n.
  /// Result: base64url( SHA-256( UTF8( canonical JSON ) ) ), no padding.
  static String _computeJkt(Map<String, dynamic> jwk) {
    final canonical = jsonEncode(<String, dynamic>{
      'e': jwk['e'],
      'kty': jwk['kty'],
      'n': jwk['n'],
    });
    final digest = sha256.convert(utf8.encode(canonical));
    return _base64UrlNoPad(Uint8List.fromList(digest.bytes));
  }

  static String _base64UrlNoPad(Uint8List bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
