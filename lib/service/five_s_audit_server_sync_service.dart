import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import 'package:square_dms_trial/database/five_s_audit_database.dart';
import 'package:square_dms_trial/five_s_audit/five_s_audit_server_config.dart';

class FiveSAuditUploadResult {
  final bool success;
  final String message;

  const FiveSAuditUploadResult({required this.success, required this.message});
}

class FiveSAuditServerSyncService {
  FiveSAuditServerSyncService._();

  static final FiveSAuditServerSyncService instance =
      FiveSAuditServerSyncService._();

  Future<bool> isWifiConnected() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }

  Future<FiveSAuditUploadResult> uploadAudit(String auditId) async {
    final isWifiAvailable = await isWifiConnected();
    if (!isWifiAvailable) {
      return const FiveSAuditUploadResult(
        success: false,
        message: 'Local Wi-Fi connection is required before upload.',
      );
    }

    final baseUrl = await FiveSAuditServerConfig.getApiBaseUrl();
    if (baseUrl.trim().isEmpty) {
      return const FiveSAuditUploadResult(
        success: false,
        message: '5S API base URL is empty.',
      );
    }

    final record = await FiveSAuditDatabase.instance.fetchAuditById(auditId);
    if (record == null) {
      return const FiveSAuditUploadResult(
        success: false,
        message: 'Local audit was not found.',
      );
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    final payload = {
      'audit_id': record.auditId,
      'department_id': record.departmentId,
      'department_name': record.departmentName,
      'area_line': record.areaLine,
      'audit_date': record.auditDate,
      'auditor_id': record.auditorId,
      'auditor_name': record.auditorName,
      'production_representative': record.productionRepresentative,
      'signature': {
        'signature_path': record.signaturePath,
        'signature_base64': record.signatureBase64,
      },
      'total_score': record.totalScore,
      'max_score': record.maxScore,
      'percentage': record.percentage,
      'rating_band': record.ratingBand,
      'remarks': record.remarks,
      'created_at': record.createdAt,
      'details': record.details.map((detail) => detail.toMap()).toList(),
      'photos':
          record.photos
              .map(
                (photo) => {
                  'local_path': photo.localPath,
                  'captured_at': photo.capturedAt,
                  'photo_data_base64': photo.photoDataBase64,
                  'photo_size_bytes': photo.photoSizeBytes,
                },
              )
              .toList(),
    };

    try {
      final response = await dio.post(fiveSUploadEndpoint, data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await FiveSAuditDatabase.instance.markAuditAsUploaded(auditId);
        return FiveSAuditUploadResult(
          success: true,
          message: 'Audit uploaded to $baseUrl successfully.',
        );
      }
      return FiveSAuditUploadResult(
        success: false,
        message:
            'Upload failed with status ${response.statusCode}: ${response.statusMessage ?? 'Unknown response'}',
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;
      final serverMessage =
          responseData is Map<String, dynamic>
              ? (responseData['detail']?.toString() ?? responseData.toString())
              : responseData?.toString();
      return FiveSAuditUploadResult(
        success: false,
        message:
            'Upload failed${statusCode != null ? ' ($statusCode)' : ''}: ${serverMessage ?? error.message ?? 'Unable to reach the local server.'}',
      );
    } catch (error) {
      return FiveSAuditUploadResult(
        success: false,
        message: 'Upload failed: $error',
      );
    }
  }
}
