import 'dart:convert';

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _readDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value.toInt() == 1;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

class FiveSCategory {
  final String code;
  final String name;
  final int sortOrder;

  const FiveSCategory({
    required this.code,
    required this.name,
    required this.sortOrder,
  });

  factory FiveSCategory.fromMap(Map<String, dynamic> map) {
    return FiveSCategory(
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sortOrder: _readInt(map['sort_order']),
    );
  }

  Map<String, dynamic> toMap() {
    return {'code': code, 'name': name, 'sort_order': sortOrder};
  }
}

class FiveSDepartment {
  final String departmentId;
  final String departmentName;
  final String? defaultAreaType;
  final bool lineRequired;
  final int sortOrder;

  const FiveSDepartment({
    required this.departmentId,
    required this.departmentName,
    required this.defaultAreaType,
    required this.lineRequired,
    required this.sortOrder,
  });

  factory FiveSDepartment.fromMap(Map<String, dynamic> map) {
    return FiveSDepartment(
      departmentId: map['department_id']?.toString() ?? '',
      departmentName: map['department_name']?.toString() ?? '',
      defaultAreaType: map['default_area_type']?.toString(),
      lineRequired: _readBool(map['line_required']),
      sortOrder: _readInt(map['sort_order']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'department_id': departmentId,
      'department_name': departmentName,
      'default_area_type': defaultAreaType,
      'line_required': lineRequired ? 1 : 0,
      'sort_order': sortOrder,
    };
  }
}

class FiveSCriterion {
  final String criterionId;
  final String departmentId;
  final String categoryCode;
  final String title;
  final String description;
  final int maxScore;
  final double weight;
  final int sortOrder;
  final bool isActive;

  const FiveSCriterion({
    required this.criterionId,
    required this.departmentId,
    required this.categoryCode,
    required this.title,
    required this.description,
    required this.maxScore,
    required this.weight,
    required this.sortOrder,
    required this.isActive,
  });

  factory FiveSCriterion.fromMap(Map<String, dynamic> map) {
    return FiveSCriterion(
      criterionId: map['criterion_id']?.toString() ?? '',
      departmentId: map['department_id']?.toString() ?? '',
      categoryCode: map['category_code']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      maxScore: _readInt(map['max_score']),
      weight: _readDouble(map['weight'], fallback: 1),
      sortOrder: _readInt(map['sort_order']),
      isActive: _readBool(map['is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'criterion_id': criterionId,
      'department_id': departmentId,
      'category_code': categoryCode,
      'title': title,
      'description': description,
      'max_score': maxScore,
      'weight': weight,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
    };
  }
}

class FiveSAuditPhoto {
  final String localPath;
  final String capturedAt;
  final String photoDataBase64;
  final int photoSizeBytes;
  final String syncStatus;

  const FiveSAuditPhoto({
    required this.localPath,
    required this.capturedAt,
    required this.photoDataBase64,
    required this.photoSizeBytes,
    this.syncStatus = 'pending',
  });

  factory FiveSAuditPhoto.fromMap(Map<String, dynamic> map) {
    return FiveSAuditPhoto(
      localPath: map['local_path']?.toString() ?? '',
      capturedAt: map['captured_at']?.toString() ?? '',
      photoDataBase64: map['photo_data_base64']?.toString() ?? '',
      photoSizeBytes: _readInt(map['photo_size_bytes']),
      syncStatus: map['sync_status']?.toString() ?? 'pending',
    );
  }

  Map<String, dynamic> toMap(String auditId) {
    return {
      'audit_id': auditId,
      'local_path': localPath,
      'captured_at': capturedAt,
      'photo_data_base64': photoDataBase64,
      'photo_size_bytes': photoSizeBytes,
      'sync_status': syncStatus,
    };
  }
}

class FiveSAuditDetail {
  final String auditId;
  final String criterionId;
  final String categoryCode;
  final String criterionTitle;
  final int maxScore;
  final double weight;
  final int score;
  final bool issueFlag;

  const FiveSAuditDetail({
    required this.auditId,
    required this.criterionId,
    required this.categoryCode,
    required this.criterionTitle,
    required this.maxScore,
    required this.weight,
    required this.score,
    required this.issueFlag,
  });

  factory FiveSAuditDetail.fromMap(Map<String, dynamic> map) {
    return FiveSAuditDetail(
      auditId: map['audit_id']?.toString() ?? '',
      criterionId: map['criterion_id']?.toString() ?? '',
      categoryCode: map['category_code']?.toString() ?? '',
      criterionTitle: map['criterion_title']?.toString() ?? '',
      maxScore: _readInt(map['max_score']),
      weight: _readDouble(map['weight'], fallback: 1),
      score: _readInt(map['score']),
      issueFlag: _readBool(map['issue_flag']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'audit_id': auditId,
      'criterion_id': criterionId,
      'category_code': categoryCode,
      'criterion_title': criterionTitle,
      'max_score': maxScore,
      'weight': weight,
      'score': score,
      'issue_flag': issueFlag ? 1 : 0,
    };
  }
}

class FiveSAuditRecord {
  final String auditId;
  final String departmentId;
  final String departmentName;
  final String areaLine;
  final String auditDate;
  final String auditorId;
  final String auditorName;
  final String productionRepresentative;
  final String signaturePath;
  final String signatureBase64;
  final int totalScore;
  final int maxScore;
  final double percentage;
  final String ratingBand;
  final String syncStatus;
  final String createdAt;
  final String updatedAt;
  final String? uploadedAt;
  final String? remarks;
  final bool isReaudit;
  final List<FiveSAuditDetail> details;
  final List<FiveSAuditPhoto> photos;

  const FiveSAuditRecord({
    required this.auditId,
    required this.departmentId,
    required this.departmentName,
    required this.areaLine,
    required this.auditDate,
    required this.auditorId,
    required this.auditorName,
    required this.productionRepresentative,
    required this.signaturePath,
    required this.signatureBase64,
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.ratingBand,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.uploadedAt,
    required this.remarks,
    required this.isReaudit,
    required this.details,
    required this.photos,
  });

  factory FiveSAuditRecord.fromMap({
    required Map<String, dynamic> map,
    List<FiveSAuditDetail> details = const [],
    List<FiveSAuditPhoto> photos = const [],
  }) {
    return FiveSAuditRecord(
      auditId: map['audit_id']?.toString() ?? '',
      departmentId: map['department_id']?.toString() ?? '',
      departmentName: map['department_name']?.toString() ?? '',
      areaLine: map['area_line']?.toString() ?? '',
      auditDate: map['audit_date']?.toString() ?? '',
      auditorId: map['auditor_id']?.toString() ?? '',
      auditorName: map['auditor_name']?.toString() ?? '',
      productionRepresentative:
          map['production_representative']?.toString() ?? '',
      signaturePath: map['signature_path']?.toString() ?? '',
      signatureBase64: map['signature_base64']?.toString() ?? '',
      totalScore: _readInt(map['total_score']),
      maxScore: _readInt(map['max_score']),
      percentage: _readDouble(map['percentage']),
      ratingBand: map['rating_band']?.toString() ?? '',
      syncStatus: map['sync_status']?.toString() ?? 'pending',
      createdAt: map['created_at']?.toString() ?? '',
      updatedAt: map['updated_at']?.toString() ?? '',
      uploadedAt: map['uploaded_at']?.toString(),
      remarks: map['remarks']?.toString(),
      isReaudit: _readBool(map['is_reaudit']),
      details: details,
      photos: photos,
    );
  }

  Map<String, dynamic> toHeaderMap() {
    return {
      'audit_id': auditId,
      'department_id': departmentId,
      'department_name': departmentName,
      'area_line': areaLine,
      'audit_date': auditDate,
      'auditor_id': auditorId,
      'auditor_name': auditorName,
      'production_representative': productionRepresentative,
      'signature_path': signaturePath,
      'signature_base64': signatureBase64,
      'total_score': totalScore,
      'max_score': maxScore,
      'percentage': percentage,
      'rating_band': ratingBand,
      'sync_status': syncStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'uploaded_at': uploadedAt,
      'remarks': remarks,
      'is_reaudit': isReaudit ? 1 : 0,
    };
  }
}

class FiveSAuditSummary {
  final String auditId;
  final String departmentName;
  final String areaLine;
  final String auditDate;
  final String auditorName;
  final String productionRepresentative;
  final int totalScore;
  final int maxScore;
  final double percentage;
  final String ratingBand;
  final String syncStatus;
  final String createdAt;
  final int issueCount;
  final int photoCount;
  final bool isReaudit;

  const FiveSAuditSummary({
    required this.auditId,
    required this.departmentName,
    required this.areaLine,
    required this.auditDate,
    required this.auditorName,
    required this.productionRepresentative,
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.ratingBand,
    required this.syncStatus,
    required this.createdAt,
    required this.issueCount,
    required this.photoCount,
    required this.isReaudit,
  });

  factory FiveSAuditSummary.fromMap(Map<String, dynamic> map) {
    return FiveSAuditSummary(
      auditId: map['audit_id']?.toString() ?? '',
      departmentName: map['department_name']?.toString() ?? '',
      areaLine: map['area_line']?.toString() ?? '',
      auditDate: map['audit_date']?.toString() ?? '',
      auditorName: map['auditor_name']?.toString() ?? '',
      productionRepresentative:
          map['production_representative']?.toString() ?? '',
      totalScore: _readInt(map['total_score']),
      maxScore: _readInt(map['max_score']),
      percentage: _readDouble(map['percentage']),
      ratingBand: map['rating_band']?.toString() ?? '',
      syncStatus: map['sync_status']?.toString() ?? 'pending',
      createdAt: map['created_at']?.toString() ?? '',
      issueCount: _readInt(map['issue_count']),
      photoCount: _readInt(map['photo_count']),
      isReaudit: _readBool(map['is_reaudit']),
    );
  }
}

class FiveSAuditMetrics {
  final int totalScore;
  final int maxScore;
  final double percentage;
  final String ratingBand;

  const FiveSAuditMetrics({
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.ratingBand,
  });
}

class FiveSMasterSyncResult {
  final int departmentCount;
  final int criteriaCount;
  final int categoryCount;
  final String syncedAt;

  const FiveSMasterSyncResult({
    required this.departmentCount,
    required this.criteriaCount,
    required this.categoryCount,
    required this.syncedAt,
  });
}

class FiveSUserContext {
  final String auditorId;
  final String auditorName;
  final List<String> workingAreas;
  final bool isMasterUser;

  const FiveSUserContext({
    required this.auditorId,
    required this.auditorName,
    required this.workingAreas,
    required this.isMasterUser,
  });

  factory FiveSUserContext.empty() {
    return const FiveSUserContext(
      auditorId: '',
      auditorName: '',
      workingAreas: <String>[],
      isMasterUser: false,
    );
  }

  factory FiveSUserContext.fromUserRow(
    String auditorId,
    Map<String, dynamic>? row,
  ) {
    final rawWorkingArea = row?['working_area'];
    final areas = _parseWorkingAreas(rawWorkingArea);
    return FiveSUserContext(
      auditorId: auditorId,
      auditorName: auditorId,
      workingAreas: areas,
      isMasterUser: areas.contains('MASTER'),
    );
  }

  static List<String> _parseWorkingAreas(dynamic rawValue) {
    if (rawValue == null) {
      return <String>[];
    }
    if (rawValue is List) {
      return rawValue
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (rawValue is String && rawValue.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawValue);
        if (decoded is List) {
          return decoded
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return rawValue
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return <String>[];
  }
}
