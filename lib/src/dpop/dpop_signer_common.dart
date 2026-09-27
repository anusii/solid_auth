/// Pure-Dart RS256 signing (dart_jsonwebtoken, over pointycastle), for
/// platforms other than web and for the synchronous
/// [DpopTokenGenerator.generate].
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
import 'dart:typed_data';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Parsed keys by PEM, so each key is parsed once rather than per proof.
final Map<String, RSAPrivateKey> _keys = {};

/// Parses [privateKeyPem] (PKCS#1 or PKCS#8), once per key.
RSAPrivateKey parsedPrivateKey(String privateKeyPem) =>
    _keys[privateKeyPem] ??= RSAPrivateKey(privateKeyPem);

/// The base64url (unpadded) RS256 signature of [signingInput].
String signRs256Sync(String signingInput, String privateKeyPem) =>
    base64UrlUnpadded(
      JWTAlgorithm.RS256.sign(
        parsedPrivateKey(privateKeyPem),
        Uint8List.fromList(utf8.encode(signingInput)),
      ),
    );

/// [bytes] as unpadded base64url, as JWS uses.
String base64UrlUnpadded(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
