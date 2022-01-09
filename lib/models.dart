import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

enum DomainStatus { available, error, blocked, nx }

extension DomainStatusExtension on DomainStatus {
  String get name {
    switch (this) {
      case DomainStatus.available:
        return "Domenas neužblokuotas";
      case DomainStatus.blocked:
        return "Domenas užblokuotas";
      case DomainStatus.nx:
        return "Domenas neegzistuoja";
      case DomainStatus.error:
        return "Klaida";
    }
  }

  String get pluralName {
    switch (this) {
      case DomainStatus.available:
        return "Neužblokuoti domenai";
      case DomainStatus.blocked:
        return "Užblokuoti domenai";
      case DomainStatus.nx:
        return "Neegzistuojantys domenai";
      case DomainStatus.error:
        return "Klaidos";
    }
  }
}

class ResolvedDomain {
  final BlockedDomain blockedDomain;
  final List<String> resolvedIps;
  final DomainStatus status;

  const ResolvedDomain({
    required this.blockedDomain,
    required this.resolvedIps,
    required this.status,
  });
}

@JsonSerializable(fieldRename: FieldRename.snake)
class InstitutionAndBlockedDomains {
  final Institution institution;
  final List<BlockedDomain> blockedDomains;

  const InstitutionAndBlockedDomains(this.institution, this.blockedDomains);

  factory InstitutionAndBlockedDomains.fromJson(Map<String, dynamic> json) =>
      _$InstitutionAndBlockedDomainsFromJson(json);

  Map<String, dynamic> toJson() => _$InstitutionAndBlockedDomainsToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class BlockedDomain {
  final String domain;
  final bool recordExists;

  const BlockedDomain(this.domain, this.recordExists);

  factory BlockedDomain.fromJson(Map<String, dynamic> json) =>
      _$BlockedDomainFromJson(json);

  Map<String, dynamic> toJson() => _$BlockedDomainToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Institution {
  final String name;
  final String sourceUrl;
  final List<String> blockIps;

  const Institution(this.name, this.sourceUrl, this.blockIps);

  factory Institution.fromJson(Map<String, dynamic> json) =>
      _$InstitutionFromJson(json);

  Map<String, dynamic> toJson() => _$InstitutionToJson(this);
}
