/// Openid functions. Extention from the library `openid_client`.
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
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
/// Authors: Anushka Vidanage

library;

import 'dart:convert';

import 'package:openid_client/openid_client.dart';

class CredentialCustom extends Credential {
  CredentialCustom.fromJson(super.json) : super.fromJson();

  Future<TokenResponse> getTokenResponseCustom({
    bool forceRefresh = false,
    String dPoPToken = '',
  }) async {
    if (!forceRefresh &&
        response.accessToken != null &&
        (_token.expiresAt == null ||
            _token.expiresAt!.isAfter(DateTime.now()))) {
      return _token;
    }
    if (_token.accessToken == null && _token.refreshToken == null) {
      return _token;
    }

    var h =
        base64.encode('${client.clientId}:${client.clientSecret}'.codeUnits);

    var grantType = _token.refreshToken != null
        ? 'refresh_token'
        : 'client_credentials'; // TODO: make this selection more explicit

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
}
