// Tests for ServerClock — signing DPoP proofs with the server's clock so a
// drifting device clock cannot make login impossible.

import 'package:flutter_test/flutter_test.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:solid_auth/src/utils/server_clock.dart';

/// A client answering every request with [date] as its `Date` header, or with
/// no such header when [date] is null.

MockClient clientReporting(DateTime? date) => MockClient((request) async {
  return http.Response(
    '',
    200,
    headers: date == null ? {} : {'date': _httpDate(date)},
  );
});

/// Formats [when] as an RFC 1123 date, the form a server sends.

String _httpDate(DateTime when) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final u = when.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');

  return '${days[u.weekday - 1]}, ${two(u.day)} ${months[u.month - 1]} '
      '${u.year} ${two(u.hour)}:${two(u.minute)}:${two(u.second)} GMT';
}

void main() {
  final url = Uri.parse('https://pods.solidcommunity.au');

  setUp(ServerClock.reset);

  test('without a sync the device clock is used', () {
    expect(ServerClock.offset, Duration.zero);
    expect(
      ServerClock.now.difference(DateTime.now().toUtc()).inSeconds.abs(),
      lessThan(2),
    );
  });

  test('a server running ahead pulls the reported time forward', () async {
    final ahead = DateTime.now().toUtc().add(const Duration(minutes: 5));

    await ServerClock.syncWith(url, client: clientReporting(ahead));

    expect(ServerClock.offset.inSeconds, closeTo(300, 2));
    expect(ServerClock.now.difference(ahead).inSeconds.abs(), lessThan(2));
  });

  test('a server running behind pulls it back', () async {
    final behind = DateTime.now().toUtc().subtract(const Duration(minutes: 5));

    await ServerClock.syncWith(url, client: clientReporting(behind));

    expect(ServerClock.offset.inSeconds, closeTo(-300, 2));
  });

  test('a missing Date header leaves the device clock alone', () async {
    await ServerClock.syncWith(url, client: clientReporting(null));

    expect(ServerClock.offset, Duration.zero);
  });

  test('a failing request leaves the device clock alone', () async {
    final failing = MockClient((request) async => throw Exception('offline'));

    await ServerClock.syncWith(url, client: failing);

    expect(ServerClock.offset, Duration.zero);
  });

  test('an unparseable Date header leaves the device clock alone', () async {
    final rubbish = MockClient(
      (request) async => http.Response('', 200, headers: {'date': 'soon'}),
    );

    await ServerClock.syncWith(url, client: rubbish);

    expect(ServerClock.offset, Duration.zero);
  });

  test('a second sync within the window does not ask again', () async {
    final ahead = DateTime.now().toUtc().add(const Duration(minutes: 5));

    await ServerClock.syncWith(url, client: clientReporting(ahead));

    var asked = false;
    final counting = MockClient((request) async {
      asked = true;

      return http.Response('', 200, headers: {});
    });

    await ServerClock.syncWith(url, client: counting);

    expect(asked, isFalse);
    expect(ServerClock.offset.inSeconds, closeTo(300, 2));
  });
}
