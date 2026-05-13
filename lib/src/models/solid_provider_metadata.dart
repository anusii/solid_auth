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
      storageEndpoint: json['storage'] != null
          ? Uri.parse(json['storage'] as String)
          : null,
    );
  }
}
