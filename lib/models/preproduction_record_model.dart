class PreproductionArtworkSelection {
  final String artworkType;
  final String garmentPart;

  const PreproductionArtworkSelection({
    required this.artworkType,
    required this.garmentPart,
  });

  factory PreproductionArtworkSelection.fromMap(Map<String, dynamic> map) {
    return PreproductionArtworkSelection(
      artworkType: map['artwork_type']?.toString() ?? '',
      garmentPart: map['garment_part']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap(String recordId) {
    return {
      'record_id': recordId,
      'artwork_type': artworkType,
      'garment_part': garmentPart,
    };
  }
}

class PreproductionPhoto {
  final String localPath;
  final String capturedAt;
  final String syncStatus;
  final String photoDataBase64;
  final int photoSizeBytes;

  const PreproductionPhoto({
    required this.localPath,
    required this.capturedAt,
    required this.photoDataBase64,
    required this.photoSizeBytes,
    this.syncStatus = 'pending',
  });

  factory PreproductionPhoto.fromMap(Map<String, dynamic> map) {
    return PreproductionPhoto(
      localPath: map['local_path']?.toString() ?? '',
      capturedAt: map['captured_at']?.toString() ?? '',
      photoDataBase64: map['photo_data_base64']?.toString() ?? '',
      photoSizeBytes: (map['photo_size_bytes'] as num?)?.toInt() ?? 0,
      syncStatus: map['sync_status']?.toString() ?? 'pending',
    );
  }

  PreproductionPhoto copyWith({
    String? localPath,
    String? capturedAt,
    String? syncStatus,
    String? photoDataBase64,
    int? photoSizeBytes,
  }) {
    return PreproductionPhoto(
      localPath: localPath ?? this.localPath,
      capturedAt: capturedAt ?? this.capturedAt,
      photoDataBase64: photoDataBase64 ?? this.photoDataBase64,
      photoSizeBytes: photoSizeBytes ?? this.photoSizeBytes,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap(String recordId) {
    return {
      'record_id': recordId,
      'local_path': localPath,
      'captured_at': capturedAt,
      'photo_data_base64': photoDataBase64,
      'photo_size_bytes': photoSizeBytes,
      'sync_status': syncStatus,
    };
  }
}

class PreproductionRecord {
  final String recordId;
  final String salesOrder;
  final String buyerName;
  final String style;
  final String criticalToQuality;
  final String syncStatus;
  final String createdAt;
  final String updatedAt;
  final List<PreproductionArtworkSelection> artworkSelections;
  final List<PreproductionPhoto> photos;

  const PreproductionRecord({
    required this.recordId,
    required this.salesOrder,
    required this.buyerName,
    required this.style,
    required this.criticalToQuality,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.artworkSelections,
    required this.photos,
  });

  factory PreproductionRecord.fromMap({
    required Map<String, dynamic> map,
    List<PreproductionArtworkSelection> artworkSelections = const [],
    List<PreproductionPhoto> photos = const [],
  }) {
    return PreproductionRecord(
      recordId: map['record_id']?.toString() ?? '',
      salesOrder: map['sales_order']?.toString() ?? '',
      buyerName: map['buyer_name']?.toString() ?? '',
      style: map['style']?.toString() ?? '',
      criticalToQuality: map['critical_to_quality']?.toString() ?? '',
      syncStatus: map['sync_status']?.toString() ?? 'pending',
      createdAt: map['created_at']?.toString() ?? '',
      updatedAt: map['updated_at']?.toString() ?? '',
      artworkSelections: artworkSelections,
      photos: photos,
    );
  }

  Map<String, dynamic> toRecordMap() {
    return {
      'record_id': recordId,
      'sales_order': salesOrder,
      'buyer_name': buyerName,
      'style': style,
      'critical_to_quality': criticalToQuality,
      'sync_status': syncStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
