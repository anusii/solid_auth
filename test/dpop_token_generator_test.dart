// Tests for DpopTokenGenerator: proofs carry the right claims (including the
// server's clock), verify against the key, and are signed identically by the
// synchronous pure-Dart signer and the platform signer (Web Crypto on web).
//
// Runs in the VM and in a browser: `flutter test` and
// `flutter test --platform chrome`.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as dj;
import 'package:fast_rsa/fast_rsa.dart' show KeyPair;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointycastle/asymmetric/api.dart' as pc;

import 'package:solid_auth/src/dpop/dpop_signer.dart';
import 'package:solid_auth/src/dpop/dpop_signer_common.dart';
import 'package:solid_auth/src/dpop/dpop_token_generator.dart';
import 'package:solid_auth/src/utils/server_clock.dart';

/// A throwaway 2048-bit key, for these tests only.
const _pem = '''-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEAulLJBDHw9Eu7TIFmwMlfgvN09fR8776YAsmGkMForyjQMq7a
InxRPIkxiiFdiQSNufkFqNPDTqAGoFgJfWBMGN5y6/fjejiWVKe5ImEHoon4I5Km
DSDGZXNIXuTlUelLrCoFghk+q58qrblv8xXtcIhCGqszAosaoevF5mmTGVbRQIul
J26pxZoBvpWT550Cx2/TSZ2BtszRXwpN4p74wx6IGIhTVp0TT7X3aiWDxqtLV4Bv
Hc8kLGNFQSAoQCDDU1B1YRCsobsOWwOpaSDdEYw8DnfHSmkOVNp0Vj4dm7liIDPs
gG/Kn+5TxdxUU6lSv5WhthCdahTqW6Jw8l5h3QIDAQABAoIBACQ7/z2inLJVm/oX
3Cy3vKxRvjgqsLVLAnLgUBwMkNgnfr2shV1Zgc7c+1ZagL8ptIorJG+dpwi+VCuQ
k1/ff00CzaSYE5PsN0gFShqmdf6lCC2a0lIRQqPuFG/n4bTZQs8baPDRCgAENx+L
xXqnlAJjbT+UdZoUBTziBh12AJZXlw3XHxXKzF0SsQt51Vp9zVYsuN7Xkxn/t+pS
R+do/JwV5WBTgfDIzUQouigId0eqK+THltFuzFABKPBDKfSr/m90xo0tCoojG8OM
p6znIYmkV14RmzLyQOdviheI9m+AagWr0vbZBjkrf4BUhe2+wP/Q8vgWFkhMsT5v
V+QJ+F0CgYEA/BRB2rNmm5Q8S6xvge+KyVeSlfotb6e3Ui+2BurzmndPLNB7KDCd
jswwzrWlKFxxLf1c9VDc3Ul9S8hR3lkMjFziNVjcYv8IXGJWHteGdDMMvdiqRoi8
kKL7q7HesHeiwNVhep/qXRVXddNE0BIlE6znI+nC2XobGQNJo39NLs8CgYEAvTiy
s/+dEpglhwaAR/6i47BhWKLteHKI7z7fP/aq01uRTPm8vNQchXBB7H27zmgMcn+6
/rDvBy0wJ4V1SCiPtALMsh+NfyRScY+9FWTlGg4VvQgqzGkaqtrlzamDhaMOlcLS
HFYGvfuuS1IunueybhBAkDdsROI8wScp70Rjr5MCgYEAkw3ePQ9bVHdtlVfK1SpA
9KQ5x3Ri/TgCIdfjgLWf1wSzE5mrvw5dW+iSsIQXDSygegvMJvA9aHputb7uw59/
SoMFE8n7B2VwIzTauLNSpIcDb9ztuKgcGOR7nPXuy1N/hq70ZuzTc+n3U60j/54W
Mxwy2yiLmwM4u6bHVrH0/NECgYEAhbbTUa+IZ+NsYYaOkFG4+f1iTSiVd1A4xBhB
2wmMnd9PRn4Uibu6i/FQJLaVSL7uTNtGYUTXJNMh/EurHVrMcgCodhcl/nrEZ8uT
atLpswfRBMwIsnpzhdk6G6N2dbFMVThfEfcYvJhmCoQAvfotdOm3NjJ0KBlXpYbv
c014xFECgYEA7ft02OeoUCo9K83gVrF0fbdXm8wIpxziichGYzsUpry0MHkTu/Y/
6hM6Y+caP3uSFbWsdMdBGcpTRdvdoKVxBFS5IgpPfeDReyKruF8f5a2Ib1uUsVO8
uCINA24WVTeIFlq23edyzcbMbpGAajRVKe+Jot1DimaxVRooOPcwdBw=
-----END RSA PRIVATE KEY-----''';

final _key = dj.RSAPrivateKey(_pem).key;

final _publicKey = dj.RSAPublicKey.raw(
  pc.RSAPublicKey(_key.modulus!, _key.publicExponent!),
);

final _jwk = <String, dynamic>{
  'kty': 'RSA',
  'e': base64UrlUnpadded(_bytes(_key.publicExponent!)),
  'n': base64UrlUnpadded(_bytes(_key.modulus!)),
  'alg': 'RS256',
};

List<int> _bytes(BigInt v) {
  final hex = v.toRadixString(16);
  final even = hex.length.isOdd ? '0$hex' : hex;
  return [
    for (var i = 0; i < even.length; i += 2)
      int.parse(even.substring(i, i + 2), radix: 16),
  ];
}

Map<String, dynamic> _claims(String proof) =>
    jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(proof.split('.')[1])),
          ),
        )
        as Map<String, dynamic>;

void main() {
  tearDown(ServerClock.reset);

  test('a proof verifies against the key and carries the request', () {
    final proof = DpopTokenGenerator.generate(
      endpointUrl: 'https://pod.example.org/alice/data/inbox/1.ttl?x=1#y',
      keyPair: KeyPair('', _pem),
      publicKeyJwk: _jwk,
      httpMethod: 'get',
      accessToken: 'the-access-token',
    );

    final verified = dj.JWT.verify(
      proof,
      _publicKey,
      // DPoP proofs are typed `dpop+jwt`, not `JWT`.
      checkHeaderType: false,
    );
    expect(verified.header!['typ'], 'dpop+jwt');
    expect(verified.header!['jwk'], _jwk);

    final claims = _claims(proof);
    expect(claims['htu'], 'https://pod.example.org/alice/data/inbox/1.ttl');
    expect(claims['htm'], 'GET');
    expect(claims['jti'], isNotEmpty);
    expect(
      claims['ath'],
      base64UrlUnpadded(sha256.convert(ascii.encode('the-access-token')).bytes),
    );
  });

  test("a proof carries the server's time, not the device's", () async {
    final serverNow = DateTime.now().toUtc().add(const Duration(hours: 1));
    await ServerClock.syncWith(
      Uri.parse('https://pod.example.org/'),
      client: MockClient(
        (_) async =>
            http.Response('', 200, headers: {'date': _httpDate(serverNow)}),
      ),
    );

    final proof = DpopTokenGenerator.generate(
      endpointUrl: 'https://pod.example.org/alice/',
      keyPair: KeyPair('', _pem),
      publicKeyJwk: _jwk,
      httpMethod: 'GET',
    );

    final iat = _claims(proof)['iat'] as int;
    expect(
      (iat - serverNow.millisecondsSinceEpoch ~/ 1000).abs(),
      lessThanOrEqualTo(2),
    );
  });

  test('the platform signer signs exactly as the pure-Dart one', () async {
    final input = DpopTokenGenerator.signingInput(
      endpointUrl: 'https://pod.example.org/alice/data/inbox/1.ttl',
      publicKeyJwk: _jwk,
      httpMethod: 'GET',
      accessToken: 'the-access-token',
      jti: 'fixed-id',
      issuedAt: DateTime.utc(2026, 9, 25),
    );

    // RS256 is deterministic: same key and input, same signature.
    expect(await signRs256(input, _pem), signRs256Sync(input, _pem));
    // And again, from the cached key.
    expect(await signRs256(input, _pem), signRs256Sync(input, _pem));
  });
}

/// [when] as an RFC 1123 date, the form a server sends.
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
