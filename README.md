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

// Decode access token to recheck the WebID
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

String endPointUrl; // The URL of the resource that is being requested
KeyPair rsaKeyPair; // Public/private key pair (RSA)
dynamic publicKeyJwk; // JSON web key of the public key
String httpMethod; // Http method to be used (eg: POST, PATCH)

// Generate DPoP token
String dPopToken = genDpopToken(endPointUrl, rsaKeyPair, publicKeyJwk, httpMethod);

```

## Additional information

The source code can be accessed via [GitHub repository](https://github.com/anusii/solid_auth). You can also file issues you face at [GitHub Issues](https://github.com/anusii/solid_auth/issues).

### Running Solid Auth in web applications

In order to successfully run `solid auth` in a web application you also need to create a custom `callback.html` file inside the `web` directory. After created simply copy and paste the following code into that file.

```html
<!DOCTYPE html>
<html>

<head>
    <script>
        const AUTH_DESTINATION_KEY = "openidconnect_auth_destination_url";
        const AUTH_RESPONSE_KEY = "openidconnect_auth_response_info";

        window.onload = function () {
            if (window.opener && window.opener !== window) { //Used when working as a popup. Uses post message to respond to the parent window                
                var parent = window.opener ?? window.parent;
                parent.postMessage(location.href, "*");
            } else { //Used for redirect loop functionality.                
                //Get the original page destination                
                const destination = sessionStorage.getItem(AUTH_DESTINATION_KEY || "/");
                sessionStorage.removeItem(AUTH_DESTINATION_KEY);
                //Store the current window location that will be used to get the information for authentication
                sessionStorage.setItem(AUTH_RESPONSE_KEY, window.location);

                //Redirect to where we're going so that we can restore state completely
                location.assign(destination);
            }
        }
    </script>
</head>

<body>
</body>

</html>
```
