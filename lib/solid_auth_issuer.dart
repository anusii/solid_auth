/// Solid issuer management.
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
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

import 'dart:async';

import 'package:http/http.dart' as http;

/// In-memory cache: maps a server URL / WebID to its resolved OIDC issuer URI.
/// The issuer URI for a given Solid server never changes at runtime, so a
/// simple process-lifetime cache is safe and avoids repeated HTTP round-trips.
final Map<String, String> _issuerCache = {};

/// Profile-body cache: maps the plain profile card URL (fragment stripped) to
/// the Turtle body fetched during [getIssuer].
///
/// When the user enters a WebID URL such as `https://example.org/profile/card#me`,
/// [getIssuer] must fetch the profile document to extract the OIDC issuer URI.
/// The same document is needed again after authentication to populate profile
/// data. Caching it here avoids a redundant (second) HTTP round-trip.
final Map<String, String> _profileBodyCache = {};

/// Returns the profile card body that was fetched during [getIssuer], or `null`
/// if the profile has not been fetched yet (e.g. the server URL is a plain
/// issuer URI rather than a WebID URL).
String? getCachedIssuerProfileBody(String profUrl) =>
    _profileBodyCache[profUrl];

/// Get POD issuer URI.
///
/// Results are cached in memory so that repeated calls for the same [textUrl]
/// (e.g. when the user logs out and back in) skip the network look-up.
Future<String> getIssuer(String textUrl) async {
  // Return cached result immediately when available.
  if (_issuerCache.containsKey(textUrl)) {
    return _issuerCache[textUrl]!;
  }

  String issuerUri = '';
  if (textUrl.contains('profile/card#me')) {
    String pubProf = await fetchProfileData(textUrl);
    // Cache the profile body under the plain URL (without #me fragment).
    // authenticate.dart can reuse this to skip a second HTTP GET.
    _profileBodyCache[textUrl.replaceAll('#me', '')] = pubProf;
    issuerUri = getIssuerUri(pubProf);
  }

  if (issuerUri == '') {
    /// This reg expression works with localhost and other urls
    RegExp exp = RegExp(r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+(\.|\:)[\w\.]+');
    Iterable<RegExpMatch> matches = exp.allMatches(textUrl);
    for (var match in matches) {
      issuerUri = textUrl.substring(match.start, match.end);
    }
  }

  if (issuerUri.isNotEmpty) {
    _issuerCache[textUrl] = issuerUri;
  }

  return issuerUri;
}

/// Get public profile information from webId
Future<String> fetchProfileData(String profUrl) async {
  final response = await http.get(
    Uri.parse(profUrl),
    headers: <String, String>{
      'Content-Type': 'text/turtle',
    },
  );

  if (response.statusCode == 200) {
    /// If the server did return a 200 OK response,
    /// then parse the JSON.
    return response.body;
  } else {
    /// If the server did not return a 200 OK response,
    /// then throw an exception.
    throw Exception('Failed to load data! Try again in a while.');
  }
}

/// Read public profile RDF file and get the issuer URI
String getIssuerUri(String profileRdfStr) {
  String issuerUri = '';
  var profileDataList = profileRdfStr.split('\n');
  for (var i = 0; i < profileDataList.length; i++) {
    String dataItem = profileDataList[i];
    if (dataItem.contains(';')) {
      var itemList = dataItem.split(';');
      for (var j = 0; j < itemList.length; j++) {
        String item = itemList[j];
        if (item.contains('solid:oidcIssuer')) {
          var issuerUriDivide = item.replaceAll(' ', '').split('<');
          issuerUri = issuerUriDivide[1].replaceAll('>', '');
        }
      }
    }
  }
  return issuerUri;
}
