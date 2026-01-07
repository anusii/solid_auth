// Copyright (c) 2017, Rik Bellens.
// All rights reserved.

// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the <organization> nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// ignore_for_file: depend_on_referenced_packages

// ignore: unnecessary_library_name
library openid_client.openid;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:jose/jose.dart';
import 'package:pointycastle/digests/sha256.dart';

import 'http_util.dart' as http;
import 'model.dart';
import 'openid_exception.dart';
import 'scopes.dart';

export 'model.dart';
export 'http_util.dart' show HttpRequestException;

/// Represents an OpenId Provider
class Issuer {
  /// The OpenId Provider's metadata
  final OpenIdProviderMetadata metadata;

  final Map<String, String> claimsMap;

  final JsonWebKeyStore _keyStore;

  /// Creates an issuer from its metadata.
  Issuer(this.metadata, {this.claimsMap = const {}})
      : _keyStore = metadata.jwksUri == null
            ? JsonWebKeyStore()
            : (JsonWebKeyStore()..addKeySetUrl(metadata.jwksUri!));

  /// Url of the facebook issuer.
  ///
  /// Note: facebook does not support OpenID Connect, but the authentication
  /// works.
  static final Uri facebook = Uri.parse('https://www.facebook.com');

  /// Url of the google issuer.
  static final Uri google = Uri.parse('https://accounts.google.com');

  /// Url of the yahoo issuer.
  static final Uri yahoo = Uri.parse('https://api.login.yahoo.com');

  /// Url of the microsoft issuer.
  static final Uri microsoft =
      Uri.parse('https://login.microsoftonline.com/common');

  /// Url of the salesforce issuer.
  static final Uri salesforce = Uri.parse('https://login.salesforce.com');

  static Uri firebase(String id) =>
      Uri.parse('https://securetoken.google.com/$id');

  static final Map<Uri, Issuer?> _discoveries = {
    facebook: Issuer(
      OpenIdProviderMetadata.fromJson({
        'issuer': facebook.toString(),
        'authorization_endpoint': 'https://www.facebook.com/v2.8/dialog/oauth',
        'token_endpoint': 'https://graph.facebook.com/v2.8/oauth/access_token',
        'userinfo_endpoint': 'https://graph.facebook.com/v2.8/879023912133394',
        'response_types_supported': ['token', 'code', 'code token'],
        'token_endpoint_auth_methods_supported': ['client_secret_post'],
        'scopes_supported': supportedScopes,
      }),
    ),
    google: null,
    yahoo: null,
    microsoft: null,
    salesforce: null,
  };

  static Iterable<Uri> get knownIssuers => _discoveries.keys;

  /// Discovers the OpenId Provider's metadata based on its uri.
  static Future<Issuer> discover(Uri uri, {http.Client? httpClient}) async {
    if (_discoveries[uri] != null) return _discoveries[uri]!;

    var segments = uri.pathSegments.toList();
    if (segments.isNotEmpty && segments.last.isEmpty) {
      segments.removeLast();
    }
    segments.addAll(['.well-known', 'openid-configuration']);
    uri = uri.replace(pathSegments: segments);

    var json = await http.get(uri, client: httpClient);
    return _discoveries[uri] = Issuer(OpenIdProviderMetadata.fromJson(json));
  }
}

/// Represents the client application.
class Client {
  /// The id of the client.
  final String clientId;

  /// A secret for authenticating the client to the OP.
  final String? clientSecret;

  /// The [Issuer] representing the OP.
  final Issuer issuer;

  final http.Client? httpClient;

  Client(this.issuer, this.clientId, {this.clientSecret, this.httpClient});

  static Future<Client> forIdToken(
    String idToken, {
    http.Client? httpClient,
  }) async {
    var token = JsonWebToken.unverified(idToken);
    var claims = OpenIdClaims.fromJson(token.claims.toJson());
    var issuer = await Issuer.discover(claims.issuer, httpClient: httpClient);
    if (!await token.verify(issuer._keyStore)) {
      throw ArgumentError('Unable to verify token');
    }
    var clientId = claims.authorizedParty ?? claims.audience.single;
    return Client(issuer, clientId, httpClient: httpClient);
  }

  /// Creates a [Credential] for this client.
  Credential createCredential({
    String? accessToken,
    String? tokenType,
    String? refreshToken,
    Duration? expiresIn,
    DateTime? expiresAt,
    String? idToken,
  }) =>
      Credential._(
        this,
        TokenResponse.fromJson({
          'access_token': accessToken,
          'token_type': tokenType,
          'refresh_token': refreshToken,
          'id_token': idToken,
          if (expiresIn != null) 'expires_in': expiresIn.inSeconds,
          if (expiresAt != null)
            'expires_at': expiresAt.millisecondsSinceEpoch ~/ 1000,
        }),
        null,
      );
}

class Credential {
  TokenResponse _token;
  final Client client;
  final String? nonce;

  final StreamController<TokenResponse> _onTokenChanged =
      StreamController.broadcast();

  Credential._(this.client, this._token, this.nonce);

  Map<String, dynamic>? get response => _token.toJson();

  Future<UserInfo> getUserInfo() async {
    var uri = client.issuer.metadata.userinfoEndpoint;
    if (uri == null) {
      throw UnsupportedError('Issuer does not support userinfo endpoint.');
    }
    return UserInfo.fromJson(await _get(uri));
  }

  /// Emits a new [TokenResponse] every time the token is refreshed
  Stream<TokenResponse> get onTokenChanged => _onTokenChanged.stream;

  /// Allows clients to notify the authorization server that a previously
  /// obtained refresh or access token is no longer needed
  ///
  /// See https://tools.ietf.org/html/rfc7009
  Future<void> revoke() async {
    var methods =
        client.issuer.metadata.tokenEndpointAuthMethodsSupported ?? [];
    var uri = client.issuer.metadata.revocationEndpoint;
    if (uri == null) {
      throw UnsupportedError('Issuer does not support revocation endpoint.');
    }
    var request = _token.refreshToken != null
        ? {'token': _token.refreshToken, 'token_type_hint': 'refresh_token'}
        : {'token': _token.accessToken, 'token_type_hint': 'access_token'};

    if (methods.contains('client_secret_basic')) {
      var h = base64
          .encode('${client.clientId}:${client.clientSecret ?? ''}'.codeUnits);
      await http.post(
        client.issuer.tokenEndpoint,
        headers: {'authorization': 'Basic $h'},
        body: request,
        client: client.httpClient,
      );
    } else {
      await http.post(
        uri,
        body: {
          ...request,
          'client_id': client.clientId,
          if (client.clientSecret != null) 'client_secret': client.clientSecret,
        },
        client: client.httpClient,
      );
    }
  }

  /// Returns an url to redirect to for a Relying Party to request that an
  /// OpenID Provider log out the End-User.
  ///
  /// [redirectUri] is an url to which the Relying Party is requesting that the
  /// End-User's User Agent be redirected after a logout has been performed.
  ///
  /// [state] is an opaque value used by the Relying Party to maintain state
  /// between the logout request and the callback to [redirectUri].
  ///
  /// See https://openid.net/specs/openid-connect-rpinitiated-1_0.html
  Uri? generateLogoutUrl({Uri? redirectUri, String? state}) {
    return client.issuer.metadata.endSessionEndpoint?.replace(
      queryParameters: {
        'id_token_hint': _token.idToken.toCompactSerialization(),
        if (redirectUri != null)
          'post_logout_redirect_uri': redirectUri.toString(),
        if (state != null) 'state': state,
      },
    );
  }

  http.Client createHttpClient([http.Client? baseClient]) =>
      http.AuthorizedClient(
        baseClient ?? client.httpClient ?? http.Client(),
        this,
      );

  Future _get(Uri uri) async {
    return http.get(uri, client: createHttpClient());
  }

  IdToken get idToken => _token.idToken;

  Stream<Exception> validateToken({
    bool validateClaims = true,
    bool validateExpiry = true,
  }) async* {
    var keyStore = JsonWebKeyStore();
    var jwksUri = client.issuer.metadata.jwksUri;
    if (jwksUri != null) {
      keyStore.addKeySetUrl(jwksUri);
    }
    if (!await idToken.verify(
      keyStore,
      allowedArguments: client.issuer.metadata.idTokenSigningAlgValuesSupported,
    )) {
      yield JoseException('Could not verify token signature');
    }

    yield* Stream.fromIterable(
      idToken.claims
          .validate(
            expiryTolerance: const Duration(seconds: 30),
            issuer: client.issuer.metadata.issuer,
            clientId: client.clientId,
            nonce: nonce,
          )
          .where(
            (e) =>
                validateExpiry ||
                !(e is JoseException && e.message.startsWith('JWT expired.')),
          ),
    );
  }

  String? get refreshToken => _token.refreshToken;

  Future<TokenResponse> getTokenResponse({
    bool forceRefresh = false,
    String dPoPToken = '',
  }) async {
    if (!forceRefresh &&
        _token.accessToken != null &&
        (_token.expiresAt == null ||
            _token.expiresAt!.isAfter(DateTime.now()))) {
      return _token;
    }
    if (_token.accessToken == null && _token.refreshToken == null) {
      return _token;
    }

    var h =
        base64.encode('${client.clientId}:${client.clientSecret}'.codeUnits);

    var grantType =
        _token.refreshToken != null ? 'refresh_token' : 'client_credentials';

    ///Generate DPoP token using the RSA private key
    var json = await http.post(
      client.issuer.tokenEndpoint,
      headers: {
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate, br',
        'content-type': 'application/x-www-form-urlencoded',
        'DPoP': dPoPToken,
        'Authorization': 'Basic $h',
      },
      body: {
        'grant_type': grantType,
        'token_type': 'DPoP',
        if (grantType == 'refresh_token') 'refresh_token': _token.refreshToken,
        if (grantType == 'client_credentials')
          'scope': _token.toJson()['scope'],
        // 'client_id': client.clientId,
        // if (client.clientSecret != null) 'client_secret': client.clientSecret
      },
      client: client.httpClient,
    );

    if (json['error'] != null) {
      throw OpenIdException(
        json['error'],
        json['error_description'],
        json['error_uri'],
      );
    }

    updateToken(json);
    return _token;
  }

  /// Updates the token with the given [json] and notifies all listeners
  /// of the new token.
  ///
  /// This method is used internally by [getTokenResponse], but can also be
  /// used to update the token manually, e.g. when no refresh token is available
  /// and the token is updated by other means.
  void updateToken(Map<String, dynamic> json) {
    _token =
        TokenResponse.fromJson({'refresh_token': _token.refreshToken, ...json});
    _onTokenChanged.add(_token);
  }

  Credential.fromJson(Map<String, dynamic> json, {http.Client? httpClient})
      : this._(
          Client(
            Issuer(
              OpenIdProviderMetadata.fromJson((json['issuer'] as Map).cast()),
            ),
            json['client_id'],
            clientSecret: json['client_secret'],
            httpClient: httpClient,
          ),
          TokenResponse.fromJson((json['token'] as Map).cast()),
          json['nonce'],
        );

  Map<String, dynamic> toJson() => {
        'issuer': client.issuer.metadata.toJson(),
        'client_id': client.clientId,
        'client_secret': client.clientSecret,
        'token': _token.toJson(),
        'nonce': nonce,
      };
}

extension _IssuerX on Issuer {
  Uri get tokenEndpoint {
    var endpoint = metadata.tokenEndpoint;
    if (endpoint == null) {
      throw const OpenIdException.missingTokenEndpoint();
    }
    return endpoint;
  }
}

enum FlowType {
  implicit,
  authorizationCode,
  proofKeyForCodeExchange,
  jwtBearer,
  password,
  clientCredentials,
}

class Flow {
  final FlowType type;

  final String? responseType;

  final Client client;

  final List<String> scopes = [];

  final String state;

  final Map<String, String> _additionalParameters;

  Uri redirectUri;

  String dPoPToken = '';

  // Flow._(this.type, this.responseType, this.client,
  //     {String? state,
  //     String? codeVerifier,
  //     Map<String, String>? additionalParameters,
  //     Uri? redirectUri,
  //     List<String> scopes = const ['openid', 'profile', 'email']})
  //     : state = state ?? _randomString(20),
  //       _additionalParameters = {...?additionalParameters},
  //       redirectUri = redirectUri ?? Uri.parse('http://localhost') {
  //   var supportedScopes = client.issuer.metadata.scopesSupported ?? [];
  //   for (var s in scopes) {
  //     if (supportedScopes.contains(s)) {
  //       this.scopes.add(s);
  //     }
  //   }

  Flow._(
    this.type,
    this.responseType,
    this.client, {
    String? state,
    String? codeVerifier,
    Map<String, String>? additionalParameters,
    Uri? redirectUri,
    List<String> scopes = const ['openid', 'profile', 'offline_access'],
  })  : state = state ?? _randomString(20),
        _additionalParameters = {...?additionalParameters},
        redirectUri = redirectUri ?? Uri.parse('http://localhost') {
    var supportedScopes = client.issuer.metadata.scopesSupported ?? [];
    for (var s in scopes) {
      if (!supportedScopes.contains(s)) {
        this.scopes.remove(s);
      }
    }

    var verifier = codeVerifier ?? _randomString(50);
    var challenge = base64Url
        .encode(SHA256Digest().process(Uint8List.fromList(verifier.codeUnits)))
        .replaceAll('=', '');
    _proofKeyForCodeExchange = {
      'code_verifier': verifier,
      'code_challenge': challenge,
    };
  }

  /// Creates a new [Flow] for the password flow.
  ///
  /// This flow can be used for active authentication by highly-trusted
  /// applications. Call [Flow.loginWithPassword] to authenticate a user with
  /// their username and password.
  Flow.password(
    Client client, {
    List<String> scopes = const ['openid', 'profile', 'email'],
  }) : this._(
          FlowType.password,
          '',
          client,
          scopes: scopes,
        );

  Flow.authorizationCode(
    Client client, {
    String? state,
    String? prompt,
    String? accessType,
    Uri? redirectUri,
    Map<String, String>? additionalParameters,
    List<String> scopes = const ['openid', 'profile', 'email'],
  }) : this._(
          FlowType.authorizationCode,
          'code',
          client,
          state: state,
          additionalParameters: {
            if (prompt != null) 'prompt': prompt,
            if (accessType != null) 'access_type': accessType,
            ...?additionalParameters,
          },
          scopes: scopes,
          redirectUri: redirectUri,
        );

  Flow.authorizationCodeWithPKCE(
    Client client, {
    String? state,
    String? prompt,
    List<String> scopes = const ['openid', 'profile', 'email'],
    String? codeVerifier,
    Map<String, String>? additionalParameters,
  }) : this._(
          FlowType.proofKeyForCodeExchange,
          'code',
          client,
          state: state,
          scopes: scopes,
          codeVerifier: codeVerifier,
          additionalParameters: {
            if (prompt != null) 'prompt': prompt,
            ...?additionalParameters,
          },
        );

  Flow.implicit(Client client, {String? state, String? device, String? prompt})
      : this._(
          FlowType.implicit,
          [
            'token id_token',
            'id_token token',
            'id_token',
            'token',
          ].firstWhere(
            (v) => client.issuer.metadata.responseTypesSupported.contains(v),
          ),
          client,
          state: state,
          scopes: [
            'openid',
            'profile',
            'email',
            if (device != null) 'offline_access',
          ],
          additionalParameters: {
            if (device != null) 'device': device,
            if (prompt != null) 'prompt': prompt,
          },
        );

  Flow.jwtBearer(Client client) : this._(FlowType.jwtBearer, null, client);

  Flow.clientCredentials(Client client, {List<String> scopes = const []})
      : this._(FlowType.clientCredentials, 'token', client, scopes: scopes);

  Uri get authenticationUri => client.issuer.metadata.authorizationEndpoint
      .replace(queryParameters: _authenticationUriParameters);

  late Map<String, String> _proofKeyForCodeExchange;

  final String _nonce = _randomString(16);

  Map<String, String?> get _authenticationUriParameters {
    var v = {
      ..._additionalParameters,
      'response_type': responseType,
      'scope': scopes.join(' '),
      'client_id': client.clientId,
      'redirect_uri': redirectUri.toString(),
      'state': state,
    }..addAll(
        responseType!.split(' ').contains('id_token') ? {'nonce': _nonce} : {},
      );

    if (type == FlowType.proofKeyForCodeExchange) {
      v.addAll({
        'code_challenge_method': 'S256',
        'code_challenge': _proofKeyForCodeExchange['code_challenge'],
      });
    }
    return v;
  }

  Future<TokenResponse> _getToken(String? code) async {
    var methods = client.issuer.metadata.tokenEndpointAuthMethodsSupported;
    dynamic json;
    if (type == FlowType.jwtBearer) {
      json = await http.post(
        client.issuer.tokenEndpoint,
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': code,
        },
        client: client.httpClient,
      );
    } else if (type == FlowType.proofKeyForCodeExchange) {
      var h =
          base64.encode('${client.clientId}:${client.clientSecret}'.codeUnits);
      json = await http.post(
        client.issuer.tokenEndpoint,
        headers: {
          'Accept': '*/*',
          'Accept-Encoding': 'gzip, deflate, br',
          'DPoP': dPoPToken,
          'content-type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic $h',
          //'Connection': 'keep-alive',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri.toString(),
          // 'client_id': client.clientId,
          // if (client.clientSecret != null)
          //   'client_secret': client.clientSecret,
          'code_verifier': _proofKeyForCodeExchange['code_verifier'],
        },
        client: client.httpClient,
      );
    } else if (type == FlowType.clientCredentials) {
      json = await http.post(
        client.issuer.tokenEndpoint,
        body: {
          'grant_type': 'client_credentials',
          'client_id': client.clientId,
          if (client.clientSecret != null) 'client_secret': client.clientSecret,
          'scope': scopes.join(' '),
        },
        client: client.httpClient,
      );
    } else if (methods!.contains('client_secret_post')) {
      json = await http.post(
        client.issuer.tokenEndpoint,
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri.toString(),
          'client_id': client.clientId,
          'client_secret': client.clientSecret,
        },
        client: client.httpClient,
      );
    } else if (methods.contains('client_secret_basic')) {
      var h =
          base64.encode('${client.clientId}:${client.clientSecret}'.codeUnits);
      json = await http.post(
        client.issuer.tokenEndpoint,
        headers: {'authorization': 'Basic $h'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri.toString(),
        },
        client: client.httpClient,
      );
    } else {
      throw UnsupportedError('Unknown auth methods: $methods');
    }
    return TokenResponse.fromJson(json);
  }

  /// Login with username and password
  ///
  /// Only allowed for [Flow.password] flows.
  Future<Credential> loginWithPassword({
    required String username,
    required String password,
  }) async {
    if (type != FlowType.password) {
      throw UnsupportedError('Flow is not password');
    }
    var json = await http.post(
      client.issuer.tokenEndpoint,
      body: {
        'grant_type': 'password',
        'username': username,
        'password': password,
        'scope': scopes.join(' '),
        'client_id': client.clientId,
      },
      client: client.httpClient,
    );
    return Credential._(client, TokenResponse.fromJson(json), null);
  }

  Future<Credential> loginWithClientCredentials() async {
    if (type != FlowType.clientCredentials) {
      throw UnsupportedError('Flow is not clientCredentials');
    }
    var json = await http.post(
      client.issuer.tokenEndpoint,
      body: {
        'grant_type': 'client_credentials',
        'client_id': client.clientId,
        if (client.clientSecret != null) 'client_secret': client.clientSecret,
        'scope': scopes.join(' '),
      },
      client: client.httpClient,
    );
    return Credential._(client, TokenResponse.fromJson(json), null);
  }

  Future<Credential> callback(Map<String, String> response) async {
    if (response['state'] != state) {
      throw ArgumentError('State does not match');
    }
    if (type == FlowType.jwtBearer) {
      var code = response['jwt'];
      return Credential._(client, await _getToken(code), null);
    } else if (response.containsKey('code') &&
        (type == FlowType.proofKeyForCodeExchange ||
            client.clientSecret != null)) {
      var code = response['code'];
      return Credential._(client, await _getToken(code), null);
    } else if (response.containsKey('access_token') ||
        response.containsKey('id_token')) {
      return Credential._(client, TokenResponse.fromJson(response), _nonce);
    } else {
      return Credential._(client, TokenResponse.fromJson(response), _nonce);
    }
  }
}

String _randomString(int length) {
  var r = Random.secure();
  var chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  return Iterable.generate(length, (_) => chars[r.nextInt(chars.length)])
      .join();
}
