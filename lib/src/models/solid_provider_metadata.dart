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
library;

import 'package:oidc_core/oidc_core.dart';

/// Extends the standard OpenID Connect discovery document with
/// Solid-specific metadata endpoints.
///
/// Solid servers MUST advertise a `solid_oidc_supported` claim and MAY
/// expose a `registration_endpoint` for dynamic client registration.
///
/// See: https://solid.github.io/solid-oidc/#discovery
class SolidProviderMetadata {
  const SolidProviderMetadata({
    required this.oidcMetadata,
    this.solidOidcSupported,
    this.registrationEndpoint,
    this.storageEndpoint,
  });

  /// The underlying, standards-compliant OIDC provider metadata fetched
  /// via `/.well-known/openid-configuration`.
  final OidcProviderMetadata oidcMetadata;

  /// `solid_oidc_supported` — advertises Solid-OIDC conformance level.
  /// Typically `"https://solidproject.org/TR/solid-oidc"`.
  final String? solidOidcSupported;

  /// Dynamic client registration endpoint (RFC 7591).
  /// Required for app registrations on Solid Community Server and similar.
  final Uri? registrationEndpoint;

  /// The storage endpoint for this user's POD root (if advertised).
  final Uri? storageEndpoint;

  /// Convenience accessors delegated to the wrapped metadata.
  Uri get issuer => oidcMetadata.issuer!;
  Uri get authorizationEndpoint => oidcMetadata.authorizationEndpoint!;
  Uri get tokenEndpoint => oidcMetadata.tokenEndpoint!;
  Uri? get userinfoEndpoint => oidcMetadata.userinfoEndpoint;
  Uri? get jwksUri => oidcMetadata.jwksUri;

  /// Parses Solid-specific extra fields from a raw discovery document JSON map,
  /// while delegating the standard fields to [OidcProviderMetadata].
  factory SolidProviderMetadata.fromJson(Map<String, dynamic> json) {
    return SolidProviderMetadata(
      oidcMetadata: OidcProviderMetadata.fromJson(json),
      solidOidcSupported: json['solid_oidc_supported'] as String?,
      registrationEndpoint: json['registration_endpoint'] != null
          ? Uri.parse(json['registration_endpoint'] as String)
          : null,
      storageEndpoint:
          json['storage'] != null ? Uri.parse(json['storage'] as String) : null,
    );
  }
}
