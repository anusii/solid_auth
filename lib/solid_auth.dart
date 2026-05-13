/// Solid Auth — Solid-OIDC authentication for Flutter, built on package:oidc.
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

// Core auth facade — the primary API consumers interact with
export 'src/auth/solid_auth_manager.dart';
export 'src/auth/solid_oidc_manager_factory.dart';

// DPoP token generation (unchanged from current solid_auth API)
export 'src/dpop/dpop_token_generator.dart';
export 'src/dpop/dpop_key_manager.dart';

// POD profile access
export 'src/profile/profile_fetcher.dart';

// Utilities
export 'src/utils/webid_utils.dart';
export 'src/utils/solid_scopes.dart';
