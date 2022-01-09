// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InstitutionAndBlockedDomains _$InstitutionAndBlockedDomainsFromJson(
        Map<String, dynamic> json) =>
    InstitutionAndBlockedDomains(
      Institution.fromJson(json['institution'] as Map<String, dynamic>),
      (json['blocked_domains'] as List<dynamic>)
          .map((e) => BlockedDomain.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$InstitutionAndBlockedDomainsToJson(
        InstitutionAndBlockedDomains instance) =>
    <String, dynamic>{
      'institution': instance.institution,
      'blocked_domains': instance.blockedDomains,
    };

BlockedDomain _$BlockedDomainFromJson(Map<String, dynamic> json) =>
    BlockedDomain(
      json['domain'] as String,
      json['record_exists'] as bool,
    );

Map<String, dynamic> _$BlockedDomainToJson(BlockedDomain instance) =>
    <String, dynamic>{
      'domain': instance.domain,
      'record_exists': instance.recordExists,
    };

Institution _$InstitutionFromJson(Map<String, dynamic> json) => Institution(
      json['name'] as String,
      json['source_url'] as String,
      (json['block_ips'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$InstitutionToJson(Institution instance) =>
    <String, dynamic>{
      'name': instance.name,
      'source_url': instance.sourceUrl,
      'block_ips': instance.blockIps,
    };
