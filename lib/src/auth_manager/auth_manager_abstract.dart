/// Auth Manager class.
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

import 'package:solid_auth/src/auth_manager/auth_manager_stub.dart'
    if (dart.library.html) 'web_auth_manager.dart';
// import just for the client class. Not used anywhere else.
import 'package:solid_auth/src/openid/src/openid.dart';

abstract class AuthManager {
  // some generic methods to be exposed.

  // returns a value based on the key
  String getKeyValue(String key) {
    return 'I am from the interface';
  }

  getWebUrl() {}
  createAuthenticator(Client client, List<String> scopes, String dPopToken) {}
  getOidcWeb() {}
  userLogout(String logoutUrl) {}

  // factory constructor to return the correct implementation.
  factory AuthManager() => getAuthManager();
}
