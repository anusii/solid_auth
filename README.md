<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages). 
-->

# Solid Auth

Solid Auth is an implementation of [Solid-OIDC flow](https://solid.github.io/solid-oidc/) which can be used to authenticate a client application to a Solid POD. Solid OIDC is built on top of OpenID Connect 1.0.

The authentication process works with both Android and Web based client applications. The package can also be used to create DPoP proof tokens for accessing private data inside PODs after the authentication.

This package includes the source code of two other packages, [openid_client](https://pub.dev/packages/openid_client) and [dart_jsonwebtoken](https://pub.dev/packages/dart_jsonwebtoken), with slight modifications done to those package files in order to be compatible with Solid-OIDC flow.

## Features

* Authenticate a client application to a Solid POD
* Create DPoP tokens for accessing data inside a POD
* Access public profile data of a POD using its WebID

<!-- ## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package. -->

## Usage

To use this package add `solid_auth` as a dependency in your `pubspec.yaml` file. An example project that uses `solid_auth` can be found [here](https://github.com/anusii/solid_auth/tree/main/example).

### Authentication Example

```dart
import 'package:solid_auth/solid_auth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

// Example WebID
String _myWebId = 'https://charlieb.solidcommunity.net/profile/card#me';

// Get issuer URI
String _issuerUri = await getIssuer(_myWebId);

// Define scopes. Also possible scopes -> webid, email, api
final List<String> _scopes = <String>[
  'openid',
  'profile',
  'offline_access',
];

// Authentication process for the POD issuer
var authData = await authenticate(Uri.parse(_issuerUri), _scopes);

// Decode access token to get the correct webId
String accessToken = authData['accessToken'];
Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);
String webId = decodedToken['webid'];

```

### Accessing Public Data Example

```dart
import 'package:solid_auth/solid_auth.dart';

// Example WebID
String _myWebId = 'https://charlieb.solidcommunity.net/profile/card#me';

// Get issuer URI
Future<String> profilePage = await fetchProfileData(_myWebId);

```

### Generating DPoP Token Example

```dart
import 'package:solid_auth/solid_auth.dart';

String endPointUrl; // The url of the resource that is being requested
KeyPair rsaKeyPair; // Public/private key pair (RSA)
dynamic publicKeyJwk; // JSON web key of the public key
String httpMethod; // Http method to be used (eg: POST, PATCH)

// Generate DPoP token
String dPopToken = genDpopToken(endPointUrl, rsaKeyPair, 
                                publicKeyJwk, httpMethod);

```

## Additional information

The source code can be accessed via [GitHub repository](https://github.com/anusii/solid_auth). You can also file issues you face in GitHub.

<!-- TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more. -->
