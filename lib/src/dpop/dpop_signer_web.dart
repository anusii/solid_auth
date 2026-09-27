/// RS256 signing on web, with the browser's Web Crypto API: see
/// dpop_signer.dart.
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
/// Authors: Jess Moore

library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:solid_auth/src/dpop/dpop_signer_common.dart';

/// Imported keys by PEM: importing is far slower than signing, so each key
/// is imported once. Not extractable, and usable only for signing.
final Map<String, Future<web.CryptoKey>> _keys = {};

String _jwkInt(BigInt value) {
  var hex = value.toRadixString(16);
  if (hex.length.isOdd) {
    hex = '0$hex';
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return base64UrlUnpadded(bytes);
}

final JSObject _algorithm =
    {'name': 'RSASSA-PKCS1-v1_5', 'hash': 'SHA-256'}.jsify()! as JSObject;

Future<web.CryptoKey> _importKey(String privateKeyPem) {
  final key = parsedPrivateKey(privateKeyPem).key;
  final p = key.p!;
  final q = key.q!;
  final d = key.privateExponent!;
  final jwk =
      {
            'kty': 'RSA',
            'n': _jwkInt(key.modulus!),
            'e': _jwkInt(key.publicExponent!),
            'd': _jwkInt(d),
            'p': _jwkInt(p),
            'q': _jwkInt(q),
            'dp': _jwkInt(d % (p - BigInt.one)),
            'dq': _jwkInt(d % (q - BigInt.one)),
            'qi': _jwkInt(q.modInverse(p)),
          }.jsify()!
          as web.JsonWebKey;
  return web.window.crypto.subtle
      .importKey('jwk', jwk, _algorithm, false, ['sign'.toJS].toJS)
      .toDart;
}

// Reached through dpop_signer.dart's conditional export, which the
// unused-code check doesn't follow (it only sees the native branch).
// ignore: unused-code
/// The base64url (unpadded) RS256 signature of [signingInput].
Future<String> signRs256(String signingInput, String privateKeyPem) async {
  final key = await (_keys[privateKeyPem] ??= _importKey(privateKeyPem));
  final signature = await web.window.crypto.subtle
      .sign(_algorithm, key, Uint8List.fromList(utf8.encode(signingInput)).toJS)
      .toDart;
  return base64UrlUnpadded((signature! as JSArrayBuffer).toDart.asUint8List());
}
