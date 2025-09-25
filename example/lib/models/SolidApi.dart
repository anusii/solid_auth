// Dart imports:
import 'dart:async';

// Package imports:
import 'package:http/http.dart' as http;

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
Future<String> updateProfile(String profCardUrl, String accessToken,
    String dPopToken, String query) async {
  final editResponse = await http.patch(
    Uri.parse(profCardUrl),
    headers: <String, String>{
      'Accept': '*/*',
      'Authorization': 'DPoP $accessToken',
      'Connection': 'keep-alive',
      'Content-Type': 'application/sparql-update',
      'Content-Length': query.length.toString(),
      'DPoP': dPopToken,
    },
    body: query,
  );

  if (editResponse.statusCode == 200 || editResponse.statusCode == 205) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return 'success';
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
