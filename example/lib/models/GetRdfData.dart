/// SolidPod library to support privacy first data store on Solid Servers
///
// Time-stamp: <Wednesday 2025-09-17 09:19:35 +1000 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute ANU
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
/// Authors: AUTHORS

// Add the library directive as we have doc entries above. We publish the above
// meta doc lines in the docs.

library;

// Class to read the turtle files and extract values from triples
class PodProfile {
  String profileRdfStr = '';

  PodProfile(String profileRdfStr) {
    this.profileRdfStr = profileRdfStr;
  }

  List<dynamic> divideRdfData(String profileRdfStr) {
    List<String> rdfDataList = [];
    String vcardPrefix = '';
    String foafPrefix = '';

    var profileDataList = profileRdfStr.split('\n');
    for (var i = 0; i < profileDataList.length; i++) {
      String dataItem = profileDataList[i];
      if (dataItem.contains(';')) {
        var itemList = dataItem.split(';');
        for (var j = 0; j < itemList.length; j++) {
          String item = itemList[j];
          rdfDataList.add(item);
        }
      } else {
        rdfDataList.add(dataItem);
      }

      if (dataItem.contains('<http://www.w3.org/2006/vcard/ns#>')) {
        var itemList = dataItem.split(' ');
        vcardPrefix = itemList[1];
      }

      if (dataItem.contains('<http://xmlns.com/foaf/0.1/>')) {
        var itemList = dataItem.split(' ');
        foafPrefix = itemList[1];
      }
    }
    return [rdfDataList, vcardPrefix, foafPrefix];
  }

  List<dynamic> dividePrvRdfData() {
    List<String> rdfDataList = [];
    final Map prefixList = {};

    var profileDataList = profileRdfStr.split('\n');
    for (var i = 0; i < profileDataList.length; i++) {
      String dataItem = profileDataList[i];
      if (dataItem.contains(';')) {
        var itemList = dataItem.split(';');
        for (var j = 0; j < itemList.length; j++) {
          String item = itemList[j];
          rdfDataList.add(item);
        }
      } else {
        rdfDataList.add(dataItem);
      }

      if (dataItem.contains('@prefix')) {
        var itemList = dataItem.split(' ');
        prefixList[itemList[1]] = itemList[2];
      }
    }
    return [rdfDataList, prefixList];
  }

  String getProfPicture() {
    var rdfRes = divideRdfData(profileRdfStr);
    List<String> rdfDataList = rdfRes[0];
    String vcardPrefix = rdfRes[1];
    String foafPrefix = rdfRes[2];
    String pictureUrl = '';
    String optionalPictureUrl = '';
    for (var i = 0; i < rdfDataList.length; i++) {
      String dataItem = rdfDataList[i];
      if (dataItem.contains(vcardPrefix + 'hasPhoto')) {
        var itemList = dataItem.split('<');
        pictureUrl = itemList[1].replaceAll('>', '');
      }
      if (dataItem.contains(foafPrefix + 'img')) {
        var itemList = dataItem.split('<');
        optionalPictureUrl = itemList[1].replaceAll('>', '');
      }
    }
    if (pictureUrl.isEmpty & optionalPictureUrl.isNotEmpty) {
      pictureUrl = optionalPictureUrl;
    }
    return pictureUrl;
  }

  String getProfName() {
    String profName = '';
    var rdfRes = divideRdfData(profileRdfStr);
    List<String> rdfDataList = rdfRes[0];
    String vcardPrefix = rdfRes[1];
    for (var i = 0; i < rdfDataList.length; i++) {
      String dataItem = rdfDataList[i];
      if (dataItem.contains(vcardPrefix + 'fn')) {
        var itemList = dataItem.split('"');
        profName = itemList[1];
      }
    }
    if (profName.isEmpty) {
      profName = 'John Doe';
    }
    return profName;
  }

  String getPersonalInfo(String infoLabel) {
    String personalInfo = '';
    var rdfRes = divideRdfData(profileRdfStr);
    List<String> rdfDataList = rdfRes[0];
    String vcardPrefix = rdfRes[1];
    for (var i = 0; i < rdfDataList.length; i++) {
      String dataItem = rdfDataList[i];
      if (dataItem.contains(vcardPrefix + infoLabel)) {
        var itemList = dataItem.split('"');
        personalInfo = itemList[1];
      }
    }
    return personalInfo;
  }

  String getAddressId(String infoLabel) {
    String personalInfo = '';
    var rdfRes = divideRdfData(profileRdfStr);
    List<String> rdfDataList = rdfRes[0];
    String vcardPrefix = rdfRes[1];
    for (var i = 0; i < rdfDataList.length; i++) {
      String dataItem = rdfDataList[i];
      if (dataItem.contains(vcardPrefix + infoLabel)) {
        var itemList = dataItem.split(':');
        personalInfo = itemList[2];
      }
    }
    return personalInfo;
  }
}
