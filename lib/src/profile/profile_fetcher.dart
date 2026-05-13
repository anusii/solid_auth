import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('solid_auth.ProfileFetcher');

/// Fetches and parses a Solid POD's public profile document from a WebID URI.
///
/// Replaces the old `fetchProfileData(webId)` function. The profile document
/// is typically served as Turtle or JSON-LD. This class returns the raw body
/// alongside a lightly-parsed [SolidProfile] for the most common fields.
///
/// For full RDF parsing, consumers should use a Turtle/JSON-LD library such
/// as `rdf_mapper` or `solid_flutter`.
class ProfileFetcher {
  const ProfileFetcher({http.Client? httpClient})
      : _httpClient = httpClient;

  final http.Client? _httpClient;

  /// Fetches the profile document for [webId] and returns a [SolidProfile].
  ///
  /// Negotiates `application/ld+json` first, then `text/turtle`.
  Future<SolidProfile> fetchProfile(String webId) async {
    _log.fine('Fetching profile for: $webId');

    final client = _httpClient ?? http.Client();
    final ownClient = _httpClient == null;

    try {
      final response = await client.get(
        Uri.parse(webId),
        headers: {'Accept': 'application/ld+json, text/turtle;q=0.9'},
      );

      if (response.statusCode != 200) {
        throw ProfileFetchException(
          'HTTP ${response.statusCode} fetching profile for $webId',
          webId: webId,
          statusCode: response.statusCode,
        );
      }

      final contentType = response.headers['content-type'] ?? '';
      return SolidProfile._parse(
        webId: webId,
        body: response.body,
        contentType: contentType,
      );
    } finally {
      if (ownClient) client.close();
    }
  }
}

// ── Model ──────────────────────────────────────────────────────────────────

/// Lightweight representation of a Solid POD public profile.
///
/// Contains the raw document body plus the fields most commonly needed
/// by Solid apps. For complete RDF access, parse [rawBody] directly.
class SolidProfile {
  const SolidProfile({
    required this.webId,
    required this.rawBody,
    required this.contentType,
    this.name,
    this.storage,
    this.oidcIssuer,
    this.inbox,
  });

  /// The WebID URI this profile belongs to.
  final String webId;

  /// The raw profile document body (Turtle or JSON-LD).
  final String rawBody;

  /// The MIME type of the profile document.
  final String contentType;

  /// `foaf:name` or `vcard:fn`, if found.
  final String? name;

  /// `pim:storage` — the root container URI of the user's POD, if advertised.
  final Uri? storage;

  /// `solid:oidcIssuer` — the identity provider URI, if advertised.
  final Uri? oidcIssuer;

  /// `ldp:inbox` — the user's LDP inbox URI, if advertised.
  final Uri? inbox;

  factory SolidProfile._parse({
    required String webId,
    required String body,
    required String contentType,
  }) {
    String? name;
    Uri? storage;
    Uri? oidcIssuer;
    Uri? inbox;

    if (contentType.contains('json')) {
      // JSON-LD path
      try {
        final doc = jsonDecode(body);
        final nodes = doc is List ? doc : [doc];
        for (final node in nodes) {
          if (node is Map) {
            name ??= _jsonLdValue(node, 'http://xmlns.com/foaf/0.1/name') ??
                _jsonLdValue(
                    node, 'http://www.w3.org/2006/vcard/ns#fn');
            storage ??= _jsonLdUri(
                node, 'http://www.w3.org/ns/pim/space#storage');
            oidcIssuer ??= _jsonLdUri(
                node, 'http://www.w3.org/ns/solid/terms#oidcIssuer');
            inbox ??=
                _jsonLdUri(node, 'http://www.w3.org/ns/ldp#inbox');
          }
        }
      } catch (e) {
        _log.warning('Failed to parse JSON-LD profile: $e');
      }
    } else {
      // Naive Turtle scan (no full RDF parsing).
      name = _turtleValue(body, r'foaf:name|vcard:fn');
      storage = _turtleUri(body, r'pim:storage|space:storage');
      oidcIssuer = _turtleUri(body, r'solid:oidcIssuer');
      inbox = _turtleUri(body, r'ldp:inbox');
    }

    return SolidProfile(
      webId: webId,
      rawBody: body,
      contentType: contentType,
      name: name,
      storage: storage,
      oidcIssuer: oidcIssuer,
      inbox: inbox,
    );
  }

  // ── JSON-LD helpers ────────────────────────────────────────────────────────

  static String? _jsonLdValue(Map node, String predicate) {
    final entry = node[predicate];
    if (entry is List && entry.isNotEmpty) {
      final v = entry.first;
      if (v is Map) return (v['@value'] ?? v['@id']) as String?;
    }
    return null;
  }

  static Uri? _jsonLdUri(Map node, String predicate) {
    final val = _jsonLdValue(node, predicate);
    return val != null ? Uri.tryParse(val) : null;
  }

  // ── Turtle helpers (naive regex — good enough for well-formed profiles) ───

  static String? _turtleValue(String body, String predicatePattern) {
    final pattern = RegExp(
      '(?:$predicatePattern)\\s+"([^"]+)"',
      caseSensitive: false,
    );
    return pattern.firstMatch(body)?.group(1);
  }

  static Uri? _turtleUri(String body, String predicatePattern) {
    final pattern = RegExp(
      '(?:$predicatePattern)\\s+<([^>]+)>',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(body);
    return match != null ? Uri.tryParse(match.group(1)!) : null;
  }
}

// ── Exception ─────────────────────────────────────────────────────────────

class ProfileFetchException implements Exception {
  const ProfileFetchException(
    this.message, {
    required this.webId,
    this.statusCode,
  });

  final String message;
  final String webId;
  final int? statusCode;

  @override
  String toString() => 'ProfileFetchException($webId): $message';
}
