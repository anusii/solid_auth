// Dart imports:
import 'dart:async';
import 'dart:math';

// Package imports:
import 'package:http/http.dart' as http;
import 'package:solid_auth/solid_auth.dart';

const _chars =
    'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890_-';
const _hexChars = '0123456789abcdef';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

String getRandomHex(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _hexChars.codeUnitAt(_rnd.nextInt(_hexChars.length))));

// Get private profile information using access and dPoP tokens
Future<String> fetchPrvProfile(
    String profCardUrl, String accessToken, String dPopToken) async {
  final profResponse = await http.get(
    Uri.parse(profCardUrl),
    headers: <String, String>{
      'Accept': '*/*',
      'Authorization': 'DPoP $accessToken',
      'Connection': 'keep-alive',
      'DPoP': '$dPopToken',
    },
  );

  if (profResponse.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return profResponse.body;
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load profile data! Try again in a while.');
  }
}

// Update profile information
Future<String> updateProfile(
    String profCardUrl, SolidAuth solidAuth, String query) async {
  // Generate DPoP token
  final dPopToken = solidAuth.genDpopToken(profCardUrl, 'PATCH');

  final editResponse = await http.patch(
    Uri.parse(profCardUrl),
    headers: <String, String>{
      'Accept': '*/*',
      'Connection': 'keep-alive',
      'Content-Type': 'application/sparql-update',
      'Content-Length': query.length.toString(),
      ...dPopToken.httpHeaders(),
    },
    body: query,
  );

  if (editResponse.statusCode == 200 || editResponse.statusCode == 205) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return editResponse.body;
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to write profile data! Try again in a while.');
  }
}

// Generate Sparql query
String genSparqlQuery(
    String action, String subject, String predicate, String object,
    {String? prevObject, String? format}) {
  String query = '';

  switch (action) {
    case "INSERT":
      {
        query = 'INSERT DATA {<$subject> <$predicate> "$object".};';
      }
      break;

    case "DELETE":
      {
        query = 'DELETE DATA {<$subject> <$predicate> "$object".};';
      }
      break;

    case "UPDATE":
      {
        query =
            'DELETE DATA {<$subject> <$predicate> "$prevObject".}; INSERT DATA {<$subject> <$predicate> "$object".};';
      }
      break;

    case "UPDATE_LANG":
      {
        query =
            'DELETE DATA {<$subject> <$predicate> "$prevObject"@en.}; INSERT DATA {<$subject> <$predicate> "$object"@en.};';
      }
      break;

    case "UPDATE_DATE":
      {
        query =
            'DELETE DATA {<$subject> <$predicate> "$prevObject"^^<$format>.}; ' +
                'INSERT DATA {<$subject> <$predicate> "$object"^^<$format>.};';
      }
      break;

    case "READ":
      {
        query = "Invalid";
      }
      break;

    default:
      {
        query = "Invalid";
      }
      break;
  }

  return query;
}
