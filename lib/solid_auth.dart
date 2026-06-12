/// Support for flutter apps authenticating to a Solid server.
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
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

/// Solid Auth — Solid-OIDC authentication flow for Flutter
/// Built on package:oidc (https://pub.dev/packages/oidc)
/// Inspired by the package (https://pub.dev/packages/solid_oidc_auth)
///
/// Main entry point. Import this file to access the public API:
///
/// ```dart
/// import 'package:solid_auth/solid_auth.dart';
/// ```
library solid_auth;

// Public models
export 'src/models/solid_auth_data.dart';
export 'src/models/solid_provider_metadata.dart';

// Core auth functionality. The primary API consumers interact with
export 'src/auth/solid_auth_manager.dart';
export 'src/auth/solid_oidc_manager_factory.dart';
export 'src/auth/solid_oidc_config.dart';

// DPoP token generation
export 'src/dpop/dpop_token_generator.dart';
export 'src/dpop/dpop_key_manager.dart';

// Utilities
export 'src/utils/webid_utils.dart';
export 'src/utils/solid_scopes.dart';
