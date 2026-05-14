import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../dpop/dpop_key_manager.dart';
import '../dpop/dpop_token_generator.dart';

final _log = Logger('solid_auth.SolidDpopHttpClient');

/// An [http.BaseClient] that automatically injects a DPoP proof header on
/// requests to the token endpoint.
///
/// ## Why a custom HTTP client?
///
/// `package:oidc` accepts a custom `http.Client` via
/// `OidcUserManager(httpClient: ...)`. Every HTTP call the manager makes —
/// including the token endpoint POST — goes through this client.
///
/// We detect token-endpoint calls by checking whether the request URL's path
/// ends with the [tokenEndpointPath] segment (or matches [tokenEndpointUri]
/// exactly if provided) and inject a fresh `DPoP` header on those requests.
///
/// For all other requests the call is forwarded unchanged.
///
/// ## Result
///
/// With this client wired in, the token endpoint receives a valid DPoP proof
/// on every token request. The OP responds with an access token that includes
/// `cnf: { jkt: "…" }`, allowing the Resource Server to verify subsequent
/// DPoP-bound resource requests.
class SolidDpopHttpClient extends http.BaseClient {
  SolidDpopHttpClient({
    required this.keyManager,
    http.Client? inner,
    this.tokenEndpointUri,
  }) : _inner = inner ?? http.Client();

  /// The DPoP key manager supplying the key pair and JWK.
  final DpopKeyManager keyManager;

  /// Optional: exact URI of the token endpoint.
  /// When set, only requests to this exact URI get DPoP headers.
  /// When null, any request whose path contains `/token` is treated as a
  /// token-endpoint call (works for all known Solid providers).
  final Uri? tokenEndpointUri;

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_isTokenEndpoint(request.url)) {
      return _sendWithDpop(request);
    }
    return _inner.send(request);
  }

  Future<http.StreamedResponse> _sendWithDpop(
    http.BaseRequest request,
  ) async {
    final dpopProof = await DpopTokenGenerator.generateForTokenEndpoint(
      tokenEndpointUrl: _normalizedUrl(request.url),
      keyManager: keyManager,
    );

    _log.fine('Injecting DPoP header on token request: ${request.url}');

    // Clone the request and add the DPoP header.
    // We must copy it because BaseRequest can only be sent once.
    final copy = _copyRequest(request);
    copy.headers['DPoP'] = dpopProof;
    return _inner.send(copy);
  }

  bool _isTokenEndpoint(Uri url) {
    if (tokenEndpointUri != null) {
      return url == tokenEndpointUri;
    }
    // Heuristic: Solid providers universally use a path ending in /token.
    return url.path.endsWith('/token') || url.path.contains('/token?');
  }

  /// Strips query parameters from the URL for the `htu` claim.
  /// RFC 9449 §4.2: htu MUST NOT include query or fragment components.
  static String _normalizedUrl(Uri url) =>
      url.replace(query: '', fragment: '').toString();

  /// Copies a [http.BaseRequest] (Request or StreamedRequest) into a
  /// fresh [http.Request] with the same method, URL, headers, and body.
  static http.Request _copyRequest(http.BaseRequest original) {
    final copy = http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection;

    if (original is http.Request) {
      copy.bodyBytes = original.bodyBytes;
    }
    return copy;
  }

  @override
  void close() {
    _inner.close();
  }
}
