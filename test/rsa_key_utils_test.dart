/// Tests for the pure Dart RSA key utilities used by DPoP.
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

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/asn1.dart';

import 'package:solid_auth/src/dpop/rsa_key_utils.dart';

void main() {
  group('generateRsaKeyPair', () {
    test('produces PKCS#1 PEM armour matching the fast_rsa output format',
        () async {
      final pair = await generateRsaKeyPair(bits: 1024);

      expect(pair.publicKey, startsWith('-----BEGIN RSA PUBLIC KEY-----'));
      expect(pair.publicKey.trim(), endsWith('-----END RSA PUBLIC KEY-----'));
      expect(pair.privateKey, startsWith('-----BEGIN RSA PRIVATE KEY-----'));
      expect(
        pair.privateKey.trim(),
        endsWith('-----END RSA PRIVATE KEY-----'),
      );
    });

    test('keys are accepted by dart_jsonwebtoken for RS256 sign and verify',
        () async {
      final pair = await generateRsaKeyPair(bits: 1024);

      final token = jwt.JWT({'sub': 'test'}).sign(
        jwt.RSAPrivateKey(pair.privateKey),
        algorithm: jwt.JWTAlgorithm.RS256,
      );
      final verified = jwt.JWT.verify(
        token,
        jwt.RSAPublicKey(pair.publicKey),
      );

      expect(verified.payload['sub'], equals('test'));
    });

    test('defaults to a 2048-bit modulus', () async {
      final pair = await generateRsaKeyPair();
      final jwk = rsaPublicKeyJwkFromPem(pair.publicKey);

      // A 2048-bit modulus is 256 bytes, i.e. 342 base64url characters
      // once the padding is stripped.
      expect((jwk['n'] as String).length, equals(342));
    });
  });

  group('rsaPublicKeyJwkFromPem', () {
    test('returns an RFC 7517 JWK with unpadded base64url values', () async {
      final pair = await generateRsaKeyPair(bits: 1024);
      final jwk = rsaPublicKeyJwkFromPem(pair.publicKey);

      expect(jwk['kty'], equals('RSA'));
      expect(jwk['e'], equals('AQAB'));
      expect(jwk['n'], isNot(contains('=')));
      expect(jwk['n'], isNotEmpty);
    });

    test('parses SPKI (BEGIN PUBLIC KEY) layouts identically', () async {
      final pair = await generateRsaKeyPair(bits: 1024);

      // Re-wrap the PKCS#1 structure in an SPKI envelope to confirm both
      // PEM layouts decode to the same JWK.
      final pkcs1Der = base64.decode(
        pair.publicKey
            .split('\n')
            .where((line) => line.isNotEmpty && !line.startsWith('-----'))
            .join(),
      );
      final spki = ASN1Sequence(
        elements: [
          ASN1Sequence(
            elements: [
              ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'),
              ASN1Null(),
            ],
          ),
          ASN1BitString(stringValues: pkcs1Der),
        ],
      );
      final spkiPem = '-----BEGIN PUBLIC KEY-----\n'
          '${base64.encode(spki.encode())}\n'
          '-----END PUBLIC KEY-----\n';

      expect(
        rsaPublicKeyJwkFromPem(spkiPem),
        equals(rsaPublicKeyJwkFromPem(pair.publicKey)),
      );
    });
  });
}
