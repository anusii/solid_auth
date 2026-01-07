// Copyright (c) 2017, Rik Bellens.
// All rights reserved.

// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the <organization> nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// ignore_for_file: depend_on_referenced_packages

/// An exception thrown when a response is received in the openid error format.
class OpenIdException implements Exception {
  /// An error code
  final String? code;

  /// Human-readable text description of the error.
  final String? message;

  /// A URI identifying a human-readable web page with information about the
  /// error, used to provide the client developer with additional information
  /// about the error.
  final String? uri;

  static const _defaultMessages = {
    'duplicate_requests':
        'The Client sent simultaneous requests to the User Questioning Polling Endpoint for the same question_id. This error is responded to oldest requests. The last request is processed normally.',
    'forbidden':
        'The Client sent a request to the User Questioning Polling Endpoint whereas it is configured with a client_notification_endpoint.',
    'high_rate_client':
        'The Client sent requests at a too high rate, amongst all question_id. Information about the allowed and recommended rates can be included in the error_description.',
    'high_rate_question':
        'The Client sent requests at a too high rate for a given question_id. Information about the allowed and recommended rates can be included in the error_description.',
    'invalid_question_id':
        'The Client sent a request to the User Questioning Polling Endpoint for a question_id that does not exist or is not valid for the requesting Client.',
    'invalid_request':
        'The User Questioning Request is not valid. The request is missing a required parameter, includes an unsupported parameter value (other than grant type), repeats a parameter, includes multiple credentials, utilizes more than one mechanism for authenticating the client, or is otherwise malformed.',
    'no_suitable_method':
        'There is no Questioning Method suitable with the User Questioning Request. The OP can use this error code when it does not implement mechanisms suitable for the wished AMR or ACR.',
    'timeout':
        'The Questioned User did not answer in the allowed period of time.',
    'unauthorized':
        'The Client is not authorized to use the User Questioning API or did not send a valid Access Token.',
    'unknown_user':
        'The Questioned User mentioned in the user_id attribute of the User Questioning Request is unknown.',
    'unreachable_user':
        'The Questioned User mentioned in the User Questioning Request (either in the Access Token or in the user_id attribute) is unreachable. The OP can use this error when it does not have a reachability identifier (e.g. MSISDN) for the Question User or when the reachability identifier is not operational (e.g. unsubscribed MSISDN).',
    'user_refused_to_answer':
        'The Questioned User refused to make a statement to the question.',
    'interaction_required':
        'The Authorization Server requires End-User interaction of some form to proceed. This error MAY be returned when the prompt parameter value in the Authentication Request is none, but the Authentication Request cannot be completed without displaying a user interface for End-User interaction.',
    'login_required':
        'The Authorization Server requires End-User authentication. This error MAY be returned when the prompt parameter value in the Authentication Request is none, but the Authentication Request cannot be completed without displaying a user interface for End-User authentication.',
    'account_selection_required':
        'The End-User is REQUIRED to select a session at the Authorization Server. The End-User MAY be authenticated at the Authorization Server with different associated accounts, but the End-User did not select a session. This error MAY be returned when the prompt parameter value in the Authentication Request is none, but the Authentication Request cannot be completed without displaying a user interface to prompt for a session to use.',
    'consent_required':
        'The Authorization Server requires End-User consent. This error MAY be returned when the prompt parameter value in the Authentication Request is none, but the Authentication Request cannot be completed without displaying a user interface for End-User consent.',
    'invalid_request_uri':
        'The request_uri in the Authorization Request returns an error or contains invalid data.',
    'invalid_request_object':
        'The request parameter contains an invalid Request Object.',
    'request_not_supported':
        'The OP does not support use of the request parameter',
    'request_uri_not_supported':
        'The OP does not support use of the request_uri parameter',
    'registration_not_supported':
        'The OP does not support use of the registration parameter',
    'invalid_redirect_uri':
        'The value of one or more redirect_uris is invalid.',
    'invalid_client_metadata':
        'The value of one of the Client Metadata fields is invalid and the server has rejected this request. Note that an Authorization Server MAY choose to substitute a valid value for any requested parameter of a Client\'s Metadata.',
  };

  /// Thrown when trying to get a token, but the token endpoint is missing from
  /// the issuer metadata
  const OpenIdException.missingTokenEndpoint()
      : this._(
          'missing_token_endpoint',
          'The issuer metadata does not contain a token endpoint.',
        );

  const OpenIdException._(this.code, this.message) : uri = null;

  OpenIdException(this.code, String? message, [this.uri])
      : message = message ?? _defaultMessages[code!];

  @override
  String toString() => 'OpenIdException($code): $message';
}
