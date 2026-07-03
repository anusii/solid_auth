/// Tests for the loopback listener guard.
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
/// Authors: Tony Chen
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:solid_auth/src/utils/loopback_listener_guard.dart';

/// Binds a listener on [port] that mimics `oidc_loopback_listener`: it
/// serves a single GET on [path], then closes its server. The returned
/// completer completes when the listener has been released.

Future<Completer<void>> bindStaleOidcListener(int port, String path) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  final released = Completer<void>();
  unawaited(() async {
    await for (final request in server) {
      if (request.method != 'GET' || request.uri.path != path) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      request.response.write('Please return to the app.');
      await request.response.close();
      await server.close();
      released.complete();
      return;
    }
  }());
  return released;
}

Future<bool> portIsFree(int port) async {
  try {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await probe.close();
    return true;
  } on SocketException {
    return false;
  }
}

void main() {
  group('releaseStaleLoopbackListeners', () {
    test('returns true when no candidate URI uses a fixed loopback port',
        () async {
      final free = await releaseStaleLoopbackListeners([
        Uri.parse('com.example.app://redirect'),
        Uri.parse('https://example.com/redirect.html'),
        Uri.parse('http://localhost:0/redirect'),
      ]);
      expect(free, isTrue);
    });

    test('returns true when the port is already free', () async {
      final free = await releaseStaleLoopbackListeners([
        Uri.parse('http://localhost:49181/redirect'),
      ]);
      expect(free, isTrue);
      expect(await portIsFree(49181), isTrue);
    });

    test('releases a stale single-response listener and frees the port',
        () async {
      const port = 49182;
      final released = await bindStaleOidcListener(port, '/redirect');
      expect(await portIsFree(port), isFalse);

      final free = await releaseStaleLoopbackListeners([
        Uri.parse('http://localhost:$port/redirect'),
      ]);

      expect(free, isTrue);
      await released.future.timeout(const Duration(seconds: 2));
      expect(await portIsFree(port), isTrue);
    });

    test('tries each distinct path until the listener is released', () async {
      const port = 49183;
      final released = await bindStaleOidcListener(port, '/redirect');

      // The first URI has the wrong path (the listener answers 404 and
      // keeps waiting); the second matches and releases it.

      final free = await releaseStaleLoopbackListeners([
        Uri.parse('http://localhost:$port/logout'),
        Uri.parse('http://localhost:$port/redirect'),
      ]);

      expect(free, isTrue);
      await released.future.timeout(const Duration(seconds: 2));
      expect(await portIsFree(port), isTrue);
    });

    test('returns false when the port is held by an unrelated server',
        () async {
      const port = 49184;

      // An unrelated server answers requests but never closes.

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      unawaited(() async {
        await for (final request in server) {
          request.response.write('not an oidc listener');
          await request.response.close();
        }
      }());

      final free = await releaseStaleLoopbackListeners([
        Uri.parse('http://localhost:$port/redirect'),
      ]);

      expect(free, isFalse);
      await server.close(force: true);
    });
  });
}
