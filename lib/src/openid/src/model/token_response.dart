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

part of '../model.dart';

class TokenResponse extends JsonObject {
  /// OAuth 2.0 Access Token
  ///
  /// This is returned unless the response_type value used is `id_token`.
  String? get accessToken => this['access_token'];

  /// OAuth 2.0 Token Type value
  ///
  /// The value MUST be Bearer or another token_type value that the Client has
  /// negotiated with the Authorization Server.
  String? get tokenType => this['token_type'];

  /// Refresh token
  String? get refreshToken => this['refresh_token'];

  /// Expiration time of the Access Token since the response was generated.
  Duration? get expiresIn => expiresAt == null
      ? getTyped('expires_in')
      : expiresAt!.difference(clock.now());

  /// ID Token
  IdToken get idToken =>
      getTyped('id_token', factory: (v) => IdToken.unverified(v))!;

  DateTime? get expiresAt => getTyped('expires_at');

  TokenResponse.fromJson(Map<String, dynamic> json)
      : super.from({
          if (json['expires_in'] != null && json['expires_at'] == null)
            'expires_at': DateTime.now()
                    .add(
                      Duration(
                        seconds: json['expires_in'] is String
                            ? int.parse(json['expires_in'])
                            : json['expires_in'],
                      ),
                    )
                    .millisecondsSinceEpoch ~/
                1000,
          ...json,
        });
}
