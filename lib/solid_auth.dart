/// Support for flutter apps authenticating to a Solid server.
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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:http/http.dart' as http;
import 'package:openid_client/openid_client.dart';
import 'package:openid_client/openid_client_io.dart' as oidc_mobile;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:solid_auth/platform_info.dart';
import 'package:solid_auth/src/auth_manager/auth_manager_abstract.dart';

// export 'src/openid/src/openid.dart' show Credential, TokenResponse;

part 'solid_auth_client.dart';
part 'solid_auth_issuer.dart';

/// Set port number to be used in localhost

const int _port = 4400;

/// To get platform information

PlatformInfo currPlatform = PlatformInfo();

/// Initialise authentication manager

AuthManager authManager = AuthManager();
