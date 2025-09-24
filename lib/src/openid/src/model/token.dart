part of '../model.dart';

class IdToken extends JsonWebToken {
  // ignore: use_super_parameters
  IdToken.unverified(String serialization) : super.unverified(serialization);

  @override
  OpenIdClaims get claims => OpenIdClaims.fromJson(super.claims.toJson());
}
