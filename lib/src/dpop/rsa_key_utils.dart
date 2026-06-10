/// Pure Dart RSA key pair generation and JWK conversion for DPoP proofs.
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
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';

import 'package:solid_auth/src/utils/isolate_runner_stub.dart'
    if (dart.library.io) 'package:solid_auth/src/utils/isolate_runner_io.dart';

/// An RSA key pair held as PEM-encoded strings.
///
/// Mirrors the shape of the `KeyPair` class previously provided by the
/// `fast_rsa` plugin (public key first), so existing call sites continue to
/// compile unchanged.
class KeyPair {
  /// Creates a key pair from PEM-encoded [publicKey] and [privateKey].
  KeyPair(this.publicKey, this.privateKey);

  /// PEM-encoded public key (PKCS#1, `RSA PUBLIC KEY`).
  String publicKey;

  /// PEM-encoded private key (PKCS#1, `RSA PRIVATE KEY`).
  String privateKey;
}

/// Generates an RSA key pair of [bits] length in pure Dart.
///
/// The keys are returned PEM-encoded in PKCS#1 form (`RSA PRIVATE KEY` /
/// `RSA PUBLIC KEY`), matching the output of the `fast_rsa` plugin that this
/// replaces, so previously persisted keys and freshly generated ones remain
/// interchangeable.
///
/// On native platforms the (CPU-intensive) generation runs on a background
/// isolate; on the web it runs inline as `dart:isolate` is unavailable there.
Future<KeyPair> generateRsaKeyPair({int bits = 2048}) =>
    runInBackground(() => generateRsaKeyPairSync(bits: bits));

/// Generates an RSA key pair of [bits] length on the current isolate.
///
/// Prefer [generateRsaKeyPair], which moves the work off the main isolate
/// where the platform supports it.
KeyPair generateRsaKeyPairSync({int bits = 2048}) {
  final random = FortunaRandom();
  final seeder = Random.secure();
  random.seed(
    KeyParameter(
      Uint8List.fromList(List<int>.generate(32, (_) => seeder.nextInt(256))),
    ),
  );

  final generator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), bits, 64),
        random,
      ),
    );

  final pair = generator.generateKeyPair();
  final publicKey = pair.publicKey;
  final privateKey = pair.privateKey;

  return KeyPair(
    _encodePem('RSA PUBLIC KEY', _pkcs1PublicKeyDer(publicKey)),
    _encodePem('RSA PRIVATE KEY', _pkcs1PrivateKeyDer(privateKey)),
  );
}

/// Converts a PEM-encoded RSA public key to a JWK map (RFC 7517).
///
/// Accepts both PKCS#1 (`BEGIN RSA PUBLIC KEY`) and SPKI
/// (`BEGIN PUBLIC KEY`) layouts, covering keys generated here as well as
/// keys persisted by earlier `fast_rsa`-based releases.
Map<String, dynamic> rsaPublicKeyJwkFromPem(String publicKeyPem) {
  var sequence =
      ASN1Parser(_derFromPem(publicKeyPem)).nextObject() as ASN1Sequence;

  // An SPKI layout nests the PKCS#1 sequence inside a BIT STRING following
  // the algorithm identifier; unwrap it first.
  final elements = sequence.elements!;
  if (elements.length == 2 && elements[1] is ASN1BitString) {
    final inner =
        Uint8List.fromList((elements[1] as ASN1BitString).stringValues!);
    sequence = ASN1Parser(inner).nextObject() as ASN1Sequence;
  }

  final modulus = (sequence.elements![0] as ASN1Integer).integer!;
  final exponent = (sequence.elements![1] as ASN1Integer).integer!;

  return <String, dynamic>{
    'kty': 'RSA',
    'n': _base64UrlUint(modulus),
    'e': _base64UrlUint(exponent),
  };
}

// ── Internal ─────────────────────────────────────────────────────────────────

/// DER-encodes [key] as a PKCS#1 `RSAPublicKey` structure (RFC 8017 §A.1.1).
Uint8List _pkcs1PublicKeyDer(RSAPublicKey key) {
  final sequence = ASN1Sequence(
    elements: [
      ASN1Integer(key.modulus),
      ASN1Integer(key.publicExponent),
    ],
  );
  return sequence.encode();
}

/// DER-encodes [key] as a PKCS#1 `RSAPrivateKey` structure (RFC 8017 §A.1.2).
Uint8List _pkcs1PrivateKeyDer(RSAPrivateKey key) {
  final d = key.privateExponent!;
  final p = key.p!;
  final q = key.q!;
  final sequence = ASN1Sequence(
    elements: [
      ASN1Integer(BigInt.zero), // Version: two-prime.
      ASN1Integer(key.modulus),
      ASN1Integer(key.publicExponent),
      ASN1Integer(d),
      ASN1Integer(p),
      ASN1Integer(q),
      ASN1Integer(d % (p - BigInt.one)), // d mod (p - 1).
      ASN1Integer(d % (q - BigInt.one)), // d mod (q - 1).
      ASN1Integer(q.modInverse(p)), // (inverse of q) mod p.
    ],
  );
  return sequence.encode();
}

/// Wraps DER bytes in PEM armour with 64-character base64 lines.
String _encodePem(String label, Uint8List der) {
  final body = base64.encode(der);
  final buffer = StringBuffer('-----BEGIN $label-----\n');
  for (var i = 0; i < body.length; i += 64) {
    buffer.writeln(body.substring(i, min(i + 64, body.length)));
  }
  buffer.write('-----END $label-----\n');
  return buffer.toString();
}

/// Strips PEM armour and decodes the base64 body to DER bytes.
Uint8List _derFromPem(String pem) {
  final body = pem
      .split(RegExp(r'\r\n?|\n'))
      .where((line) => line.isNotEmpty && !line.startsWith('-----'))
      .join();
  return base64.decode(body);
}

/// Encodes [value] as a base64url string without padding (RFC 7518 §6.3).
String _base64UrlUint(BigInt value) =>
    base64Url.encode(_unsignedBigEndianBytes(value)).replaceAll('=', '');

/// Minimal unsigned big-endian byte representation of [value].
Uint8List _unsignedBigEndianBytes(BigInt value) {
  final byteLength = (value.bitLength + 7) >> 3;
  final bytes = Uint8List(byteLength == 0 ? 1 : byteLength);
  var remaining = value;
  for (var i = bytes.length - 1; i >= 0; i--) {
    bytes[i] = (remaining & BigInt.from(0xff)).toInt();
    remaining = remaining >> 8;
  }
  return bytes;
}
