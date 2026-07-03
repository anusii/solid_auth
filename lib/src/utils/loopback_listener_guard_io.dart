/// Support for flutter apps authenticating to a Solid server.
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

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('solid_auth.LoopbackListenerGuard');

/// How long to wait for a stale listener to answer the release request.

const _releaseRequestTimeout = Duration(seconds: 2);

/// Releases loopback redirect listeners left behind by abandoned browser
/// flows.
///
/// On Windows and Linux, `package:oidc` completes login and logout by
/// binding an HTTP listener on the loopback redirect port (for example
/// `http://localhost:4400/redirect`) and waiting for the browser to redirect
/// back to it. If the user abandons the browser window — say, by ignoring
/// the identity provider's sign-out confirmation page — that listener stays
/// bound indefinitely, and the next login or logout attempt dies with an
/// unhandled [SocketException] the moment it tries to bind the same port.
///
/// This guard probes each fixed loopback port named in [redirectUris]. When
/// a port is already bound, it sends a plain GET to the redirect URI, which
/// the stale listener treats as the browser redirect it has been waiting
/// for: it responds, closes its server and lets the abandoned flow complete
/// harmlessly (a redirect carrying no `state` merely clears the local user).
///
/// Returns true when every relevant port is free (possibly after a release),
/// or false when a port remains bound — for instance when an unrelated
/// application owns it — in which case the caller should avoid starting a
/// loopback-based browser flow.

Future<bool> releaseStaleLoopbackListeners(List<Uri> redirectUris) async {
  final candidates = redirectUris.where(_isFixedLoopbackHttpUri).toList();
  if (candidates.isEmpty) return true;

  var allFree = true;
  for (final port in candidates.map((uri) => uri.port).toSet()) {
    if (await _isPortFree(port)) continue;

    _log.info(
      'Loopback port $port is already bound — attempting to release a '
      'stale redirect listener from an abandoned browser flow.',
    );

    var freed = false;
    final triedPaths = <String>{};
    for (final uri in candidates.where((u) => u.port == port)) {
      // The stale listener only answers its own path, so try each
      // distinct path once.

      if (!triedPaths.add(uri.path)) continue;
      try {
        await http.get(uri).timeout(_releaseRequestTimeout);
      } on Object catch (e) {
        _log.finer('Release request to $uri failed: $e');
      }
      if (await _isPortFree(port)) {
        freed = true;
        break;
      }
    }

    if (freed) {
      // Give the released flow a moment to finish unwinding (it clears
      // the local user on completion) before a new flow reuses the port.

      await Future<void>.delayed(const Duration(milliseconds: 100));
    } else {
      _log.warning(
        'Loopback port $port could not be released; it may be held by '
        'another application.',
      );
      allFree = false;
    }
  }
  return allFree;
}

/// True for `http://localhost:<port>/...` style URIs with an explicit,
/// fixed port — the only kind that can collide across flows. A port of 0
/// asks the operating system for an ephemeral port, so it never conflicts.

bool _isFixedLoopbackHttpUri(Uri uri) {
  if (uri.scheme != 'http') return false;
  if (!uri.hasPort || uri.port == 0) return false;
  return uri.host == 'localhost' || uri.host == '127.0.0.1';
}

/// Probes whether [port] can be bound on the IPv4 loopback interface.

Future<bool> _isPortFree(int port) async {
  try {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await probe.close();
    return true;
  } on SocketException {
    return false;
  }
}
