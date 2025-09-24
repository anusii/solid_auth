/// Openid Client Browser management. Extention from the library `openid_client`.
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

import 'package:openid_client/openid_client_browser.dart';
import 'package:web/web.dart';

class AuthenticatorCustom extends Authenticator {
  
  AuthenticatorCustom._(this.flow) : super.credential = _credentialFromUri(flow);

  // With PKCE flow
  AuthenticatorCustom(
    Client client, {
    Iterable<String> scopes = const [],
    popToken = '',
  }) : this._(
          Flow.authorizationCodeWithPKCE(
            client,
            state: window.localStorage.getItem('openid_client:state'),
          )
            ..scopes.addAll(scopes)
            ..redirectUri = Uri.parse(
              window.location.href.contains('#/')
                  ? window.location.href.replaceAll('#/', 'callback.html')
                  : '${window.location.href}callback.html',
            ).removeFragment()
            ..dPoPToken = popToken,
        );
  
  /// Redirects the browser to the authentication URI.
  void authorize() {
    _forgetCredentials();
    window.localStorage.setItem('openid_client:state', flow.state);
    window.location.href = flow.authenticationUri.toString();
  }

  /// Redirects the browser to the logout URI.
  void logout() async {
    _forgetCredentials();
    var c = await credential;
    if (c == null) return;
    var uri = c.generateLogoutUrl(
        redirectUri: Uri.parse(window.location.href).removeFragment());
    if (uri != null) {
      window.location.href = uri.toString();
    }
  }

  void _forgetCredentials() {
    window.localStorage.removeItem('openid_client:state');
    window.localStorage.removeItem('openid_client:auth');
  }

  static Future<Credential?> _credentialFromUri(Flow flow) async {
    var uri = Uri.parse(window.location.href);
    var iframe = uri.queryParameters['iframe'] != null;
    uri = Uri(query: uri.fragment);
    var q = uri.queryParameters;
    if (q.containsKey('access_token') ||
        q.containsKey('code') ||
        q.containsKey('id_token')) {
      window.history.replaceState(''.toJS, '',
          Uri.parse(window.location.href).removeFragment().toString());
      window.localStorage.removeItem('openid_client:state');

      var c = await flow.callback(q.cast());
      if (iframe) window.parent!.postMessage(c.response?.toJSBox, '*'.toJS);
      return c;
    }
    return null;
  }
  
}