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

part of 'solid_auth.dart';

/// Get POD issuer URI
Future<String> getIssuer(String textUrl) async {
  String issuerUri = '';
  if (textUrl.contains('profile/card#me')) {
    String pubProf = await fetchProfileData(textUrl);
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
