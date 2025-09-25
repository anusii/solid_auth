/// Web Auth Manager
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

import 'package:openidconnect_web/openidconnect_web.dart';
import 'package:web/web.dart' hide Client;

import 'package:solid_auth/src/auth_manager/auth_manager_abstract.dart';
import 'package:solid_auth/src/openid/openid_client_browser.dart';

late Window windowLoc;

class WebAuthManager implements AuthManager {
  WebAuthManager() {
    windowLoc = window;
    // storing something initially just to make sure it works.
    // windowLoc.localStorage.setItem('MyKey', 'I am from web local storage');
    windowLoc.localStorage.setItem('MyKey', 'I am from web local storage');
  }

  @override
  String getWebUrl() {
    if (window.location.href.contains('#/')) {
      return window.location.href.replaceAll('#/', 'callback.html');
    } else {
      return ('${window.location.href}callback.html');
    }
  }

  @override
  Authenticator createAuthenticator(
    Client client,
    List<String> scopes,
    String dPopToken,
  ) {
    var authenticator =
        Authenticator(client, scopes: scopes, popToken: dPopToken);
    return authenticator;
  }

  @override
  OpenIdConnectWeb getOidcWeb() {
    OpenIdConnectWeb oidc = OpenIdConnectWeb();
    return oidc;
  }

  @override
  String getKeyValue(String key) {
    // return windowLoc.localStorage.getItem(key) as String;
    return windowLoc.localStorage.getItem(key)!;
  }

  @override
  userLogout(String logoutUrl) {
    final child = window.open(logoutUrl, 'user_logout');
    child!.close();
  }
}

AuthManager getAuthManager() => WebAuthManager();
