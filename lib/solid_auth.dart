/// A Flutter library for authenticating with Solid pods using OpenID Connect.
///
/// This library provides a simple, reactive interface for Solid authentication
/// that handles the complexity of Solid-OIDC flows, token management, WebID discovery,
/// and DPoP (Demonstration of Proof-of-Possession) tokens required by Solid servers.
///
/// ## What is Solid?
///
/// Solid is a web decentralization project that gives users control over their
/// data by storing it in personal data pods. Users authenticate with identity
/// providers and grant applications access to specific data in their pods.
///
/// ## Key Features
///
/// - **Reactive Authentication State**: Use `ValueListenable` to update UI when
///   authentication status changes
/// - **Automatic Session Restoration**: Persists login across app restarts
/// - **Multi-Platform Support**: Works on web, mobile, and macOS (Windows/Linux have redirect URI limitations)
/// - **DPoP Token Support**: Handles security tokens required by Solid servers
/// - **WebID Discovery**: Automatically finds identity providers from WebIDs
/// - **Secure Token Storage**: Uses platform-appropriate secure storage
///
/// ## Quick Start
///
/// ```dart
/// import 'package:solid_auth/solid_auth.dart';
///
/// // 1. Initialize SolidAuth with your client configuration
/// final solidAuth = SolidAuth(
///   oidcClientId: 'https://myapp.com/client-profile.jsonld',
///   appUrlScheme: 'com.mycompany.myapp',
///   frontendRedirectUrl: Uri.parse('https://myapp.com/auth/callback.html'),
/// );
///
/// // 2. Initialize and check for existing session
/// await solidAuth.init();
///
/// // 3. Build reactive UI
/// ValueListenableBuilder<bool>(
///   valueListenable: solidAuth.isAuthenticatedNotifier,
///   builder: (context, isAuthenticated, child) {
///     if (isAuthenticated) {
///       return Text('Welcome, ${solidAuth.currentWebId}!');
///     } else {
///       return ElevatedButton(
///         onPressed: () => authenticate(),
///         child: Text('Login with Solid'),
///       );
///     }
///   },
/// );
///
/// // 4. Authenticate user
/// Future<void> authenticate() async {
///   try {
///     final result = await solidAuth.authenticate(
///       'https://alice.solidcommunity.net/profile/card#me'
///     );
///     print('Authenticated as: ${result.webId}');
///   } catch (e) {
///     print('Authentication failed: $e');
///   }
/// }
///
/// // 5. Make authenticated API requests
/// Future<void> fetchData() async {
///   final dpop = solidAuth.genDpopToken(
///     'https://alice.solidcommunity.net/private/data.ttl',
///     'GET'
///   );
///
///   final response = await http.get(
///     Uri.parse('https://alice.solidcommunity.net/private/data.ttl'),
///     headers: {
///       ...dpop.httpHeaders(), // DPoP authentication headers
///       'Accept': 'text/turtle', // Specify desired RDF format
///       'User-Agent': 'MyApp/1.0',
///     },
///   );
/// }
/// ```
///
/// ## Client Configuration
///
/// Your application needs a public client profile document (also called a client
/// identifier document or client configuration) typically named `client-profile.jsonld`
/// that describes your app to Solid identity providers.
///
/// ### Redirect URI Construction
///
/// The redirect URIs must match the patterns used by SolidAuth based on your platform:
///
/// **For `redirect_uris`:**
/// - Web: The exact `frontendRedirectUrl` you provide to SolidAuth
/// - Mobile/Desktop: `{appUrlScheme}://redirect`
///
/// **For `post_logout_redirect_uris`:**
/// - Web: The exact `frontendRedirectUrl` you provide to SolidAuth
/// - Mobile/Desktop: `{appUrlScheme}://logout`
///
/// ### Required Scopes
///
/// The `scope` field **must** include these mandatory scopes:
/// - `openid`: Required for OpenID Connect authentication
/// - `webid`: Required for Solid WebID functionality
/// - `offline_access`: Required for token refresh capability
///
/// Additional scopes like `profile` can be included as needed.
///
/// ### Example Configuration
///
/// ```json
/// {
///   "@context": "https://www.w3.org/ns/solid/oidc-context.jsonld",
///   "client_id": "https://myapp.com/client-profile.jsonld",
///   "client_name": "My Solid App",
///   "application_type": "native",
///   "redirect_uris": [
///     "https://myapp.com/auth/callback.html",
///     "com.mycompany.myapp://redirect"
///   ],
///   "post_logout_redirect_uris": [
///     "https://myapp.com/auth/callback.html",
///     "com.mycompany.myapp://logout"
///   ],
///   "scope": "openid webid offline_access profile",
///   "grant_types": ["authorization_code", "refresh_token"],
///   "response_types": ["code"],
///   "token_endpoint_auth_method": "none"
/// }
/// ```
///
/// ## Security Considerations
///
/// - **HTTPS Required**: All redirect URIs must use HTTPS in production
/// - **Client Registration**: All redirect URIs must be pre-registered in your
///   client profile document
/// - **DPoP Tokens**: Generate fresh DPoP tokens for each API request
/// - **Token Storage**: The library uses secure platform storage for tokens
/// - **WebID Validation**: WebIDs are validated by fetching their profile documents
///   and verifying the declared identity providers match the authentication source
///
/// ## Platform-Specific Setup
///
/// This library builds on the `oidc` package. For detailed platform-specific
/// setup instructions, see the [OIDC Getting Started Guide](https://bdaya-dev.github.io/oidc/oidc-getting-started/).
///
/// ### All Platforms
/// - Create and host your `client-profile.jsonld` on HTTPS
/// - Ensure all redirect URIs are declared in your client profile document
/// - Set the `client_id` field to the URL where your client profile document is hosted
///
/// ## Learn More
///
/// - [Solid Project](https://solidproject.org/)
/// - [Solid OIDC Specification](https://solid.github.io/solid-oidc/)
/// - [WebID Specification](https://www.w3.org/2005/Incubator/webid/spec/identity/)
library solid_auth;

export 'src/solid_auth.dart';
