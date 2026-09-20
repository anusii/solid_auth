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
/// Authors: Graham Williams
library;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'package:logging/logging.dart';

final _log = Logger('solid_auth.ServerClock');

/// The server's idea of the current time, for signing DPoP proofs.
///
/// A DPoP proof carries an `iat` claim, and the server rejects a proof whose
/// `iat` sits outside a tolerance of tens of seconds around its own clock. A
/// device whose clock has drifted therefore cannot log in at all: the
/// authorization code is exchanged, the server answers `invalid_dpop_proof`
/// with "DPoP proof iat is not recent enough", and — because an error from
/// the token endpoint carries no `iss` — the user is shown an unrelated
/// RFC 9207 mix-up warning. A macOS user with "Set time automatically"
/// turned off hit exactly this in September 2026.
///
/// Rather than trusting the device, [syncWith] reads the `Date` header the
/// server returns on any request and remembers the difference. [now] then
/// reports the time as the server sees it, so proofs stay acceptable however
/// far the local clock has wandered.

abstract class ServerClock {
  ServerClock._();

  /// How long a learned offset is trusted before another sync is made. Clock
  /// drift is slow, so this only needs to be short enough to catch the user
  /// correcting their clock, or a laptop waking in another timezone.

  static const _resyncAfter = Duration(minutes: 10);

  /// An offset worth mentioning in the log. Below this the two clocks agree
  /// closely enough that the difference is just network latency.

  static const _notableSkew = Duration(seconds: 5);

  static Duration _offset = Duration.zero;

  static DateTime? _syncedAt;

  /// How far this device's clock is behind the server's. Positive when the
  /// device is behind, negative when it is ahead, zero until a sync succeeds.

  static Duration get offset => _offset;

  /// The current UTC time as the server sees it.

  static DateTime get now => DateTime.now().toUtc().add(_offset);

  /// Forgets any learned offset. For tests, and for a sign-out that should
  /// leave nothing behind.

  static void reset() {
    _offset = Duration.zero;
    _syncedAt = null;
  }

  /// Learns the offset from the `Date` header returned by [url], unless a
  /// recent sync already did.
  ///
  /// Best effort throughout: a request that fails, times out, or comes back
  /// without a usable `Date` simply leaves the previous offset in place, so a
  /// server that omits the header costs nothing but never makes matters
  /// worse. Pass [client] to supply a client (as the tests do); otherwise one
  /// is created and closed here.

  static Future<void> syncWith(Uri url, {http.Client? client}) async {
    final syncedAt = _syncedAt;

    if (syncedAt != null &&
        DateTime.now().toUtc().difference(syncedAt) < _resyncAfter) {
      return;
    }

    final httpClient = client ?? http.Client();

    try {
      // The round trip is timed so that its latency can be discounted: the
      // Date header describes a moment somewhere inside the request, so the
      // midpoint is the closest estimate of the server's clock at the point
      // the reply was written.

      final sentAt = DateTime.now().toUtc();

      final response = await httpClient
          .head(url)
          .timeout(const Duration(seconds: 10));

      final header = response.headers['date'];

      if (header == null) {
        _log.fine('No Date header from $url, keeping the device clock');

        return;
      }

      final midpoint = sentAt.add(
        (DateTime.now().toUtc().difference(sentAt)) ~/ 2,
      );

      _offset = parseHttpDate(header).difference(midpoint);
      _syncedAt = DateTime.now().toUtc();

      if (_offset.abs() >= _notableSkew) {
        _log.info(
          'This device\'s clock is ${_offset.inSeconds}s behind $url. '
          'DPoP proofs will be signed with the server time instead.',
        );
      } else {
        _log.fine('Device clock agrees with $url to within a few seconds');
      }
    } on Object catch (e) {
      _log.fine('Could not read the clock of $url: $e');
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
