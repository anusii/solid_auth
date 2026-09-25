/// Signs DPoP proofs: RS256 (RSASSA-PKCS1-v1_5 with SHA-256) over a JWS
/// signing input, on whichever platform the app runs.
///
/// Every request to a POD carries a freshly signed proof, so this is on the
/// path of every read and write. On web it uses the browser's Web Crypto
/// API: signing in pure Dart compiled to JavaScript takes about 250 ms per
/// proof, Web Crypto well under 1 ms. Elsewhere the pure-Dart signer takes
/// 2-3 ms, and runs with the key parsed once rather than on every proof.
///
/// RS256 is deterministic, so both produce identical signatures for the
/// same key and input.
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

export 'package:solid_auth/src/dpop/dpop_signer_native.dart'
    if (dart.library.js_interop) 'package:solid_auth/src/dpop/dpop_signer_web.dart';
