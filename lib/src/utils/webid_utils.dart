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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../models/solid_provider_metadata.dart';

final _log = Logger('solid_auth.WebIdUtils');

/// Utility functions for working with Solid WebID URIs and deriving
/// the associated identity provider (issuer).
abstract class WebIdUtils {
  WebIdUtils._();

  // ── Issuer discovery ───────────────────────────────────────────────────────

  /// Derives the issuer URI from a WebID by:
  ///
  /// 1. Fetching the WebID profile document (Turtle / JSON-LD).
  /// 2. Looking for an `oidcIssuer` predicate
  ///    (`http://www.w3.org/ns/solid/terms#oidcIssuer`).
  /// 3. Falling back to a heuristic (the WebID's origin) if no explicit
  ///    issuer is advertised.
  ///
  /// Throws a [SolidAuthException] if the issuer cannot be resolved.
  static Future<String> getIssuer(
    String webId, {
    http.Client? httpClient,
  }) async {
    _log.fine('Resolving issuer for WebID: $webId');
    final client = httpClient ?? http.Client();

    try {
      final profileUri = Uri.parse(webId);
      final response = await client.get(
        profileUri,
        headers: {'Accept': 'application/ld+json, text/turtle;q=0.9'},
      );

      if (response.statusCode != 200) {
        throw SolidAuthDiscoveryException(
          'Failed to fetch WebID profile: HTTP ${response.statusCode}',
          webId: webId,
        );
      }

      final issuer = _extractIssuerFromProfile(response.body, profileUri);
      if (issuer != null) {
        _log.fine('Resolved issuer from profile: $issuer');
        return issuer;
      }

      // Heuristic fallback: use origin as issuer
      final fallback = profileUri.origin;
      _log.warning(
        'No oidcIssuer found in profile for $webId — '
        'falling back to origin: $fallback',
      );
      return fallback;
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Fetches and parses the Solid-extended OpenID Connect discovery document
  /// for the given [issuerUri].
  ///
  /// This wraps `OidcEndpoints.getProviderMetadata` and adds Solid-specific
  /// field parsing (e.g. `solid_oidc_supported`, `registration_endpoint`).
  static Future<SolidProviderMetadata> getProviderMetadata(
    String issuerUri, {
    http.Client? httpClient,
  }) async {
    _log.fine('Fetching discovery document for: $issuerUri');
    final client = httpClient ?? http.Client();

    try {
      final discoveryUri = Uri.parse(issuerUri).replace(
        path: '/.well-known/openid-configuration',
      );

      final response = await client.get(
        discoveryUri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw SolidAuthDiscoveryException(
          'Discovery document request failed: HTTP ${response.statusCode}',
          webId: issuerUri,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SolidProviderMetadata.fromJson(json);
    } finally {
      if (httpClient == null) client.close();
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  /// Attempts to extract the `solid:oidcIssuer` value from a profile document.
  /// Supports both JSON-LD and a naive Turtle scan (for the common pattern).
  static String? _extractIssuerFromProfile(String body, Uri profileUri) {
    // Try JSON-LD path first
    try {
      final decoded = jsonDecode(body);
      final graphs = decoded is List ? decoded : [decoded];
      for (final node in graphs) {
        if (node is Map) {
          final issuerEntry =
              node['http://www.w3.org/ns/solid/terms#oidcIssuer'];
          if (issuerEntry is List && issuerEntry.isNotEmpty) {
            final v = issuerEntry.first;
            if (v is Map && v.containsKey('@id')) return v['@id'] as String;
            if (v is Map && v.containsKey('@value')) {
              return v['@value'] as String;
            }
          }
        }
      }
    } catch (_) {
      // Not JSON-LD — try Turtle heuristic below
    }

    // Naive Turtle scan: look for `solid:oidcIssuer <URI>` pattern
    final turtlePattern = RegExp(
      r'solid:oidcIssuer\s+<([^>]+)>',
      caseSensitive: false,
    );
    final match = turtlePattern.firstMatch(body);
    return match?.group(1);
  }
}

// ── Exceptions ─────────────────────────────────────────────────────────────

/// Base class for all solid_auth errors.
class SolidAuthException implements Exception {
  const SolidAuthException(this.message);
  final String message;

  @override
  String toString() => 'SolidAuthException: $message';
}

/// Thrown when issuer/discovery-document resolution fails.
class SolidAuthDiscoveryException extends SolidAuthException {
  const SolidAuthDiscoveryException(super.message, {required this.webId});
  final String webId;

  @override
  String toString() => 'SolidAuthDiscoveryException($webId): $message';
}

/// Thrown when the OIDC token exchange or validation fails.
class SolidAuthTokenException extends SolidAuthException {
  const SolidAuthTokenException(super.message);
}
