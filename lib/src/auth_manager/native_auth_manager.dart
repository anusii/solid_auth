/// Native Auth Manager for non-web platforms.
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

import 'package:shared_preferences/shared_preferences.dart';

import 'package:solid_auth/src/auth_manager/auth_manager_abstract.dart';
import 'package:solid_auth/src/openid/src/openid.dart';

/// Auth manager implementation for native platforms (Linux, Windows, macOS, iOS, Android).
///
/// This provides platform-specific implementations using SharedPreferences
/// for storage operations on native platforms.
class NativeAuthManager implements AuthManager {
  @override
  String getKeyValue(String key) {
    // Native platforms don't use localStorage
    return '';
  }

  @override
  getWebUrl() {
    // Not applicable for native platforms
    return null;
  }

  @override
  createAuthenticator(Client client, List<String> scopes, String dPopToken) {
    // Not applicable for native platforms
    return null;
  }

  @override
  getOidcWeb() {
    // Not applicable for native platforms
    return null;
  }

  @override
  userLogout(String logoutUrl) {
    // Native platforms handle logout through URL launcher, not window.open
  }

  @override
  Future<void> clearLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw Exception('Failed to clear SharedPreferences: $e');
    }
  }
}

AuthManager getAuthManager() => NativeAuthManager();
