import 'package:dio/dio.dart';

import 'package:square_dms_trial/database/preproduction_record_database.dart';
import 'package:square_dms_trial/preproduction_meeting/preproduction_server_config.dart';

class PreproductionUploadResult {
  final bool success;
  final String message;

  const PreproductionUploadResult({
    required this.success,
    required this.message,
  });
}

class PreproductionServerSyncService {
  static final PreproductionServerSyncService instance =
      PreproductionServerSyncService._init();

  PreproductionServerSyncService._init();

  Future<PreproductionUploadResult> uploadRecord(String recordId) async {
    final baseUrl = await PreproductionServerConfig.getApiBaseUrl();
    if (baseUrl.trim().isEmpty) {
      return const PreproductionUploadResult(
        success: false,
        message: 'Preproduction API base URL is empty.',
      );
    }

    final localRecord = await PreproductionRecordDatabase.instance
        .fetchRecordById(recordId);
    if (localRecord == null) {
      return const PreproductionUploadResult(
        success: false,
        message: 'Local record was not found.',
      );
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    final payload = {
      'user_id': localRecord.userId,
      'sales_order': localRecord.salesOrder,
      'buyer_name': localRecord.buyerName,
      'style': localRecord.style,
      'critical_to_quality': localRecord.criticalToQuality,
      'photos':
          localRecord.photos
              .map(
                (photo) => {
                  'local_path': photo.localPath,
                  'captured_at': photo.capturedAt,
                  'photo_data_base64': photo.photoDataBase64,
                  'photo_size_bytes': photo.photoSizeBytes,
                },
              )
              .toList(),
      'artwork_parts':
          localRecord.artworkSelections
              .map(
                (selection) => {
                  'artwork_type': selection.artworkType,
                  'garment_part': selection.garmentPart,
                },
              )
              .toList(),
    };

    try {
      final response = await dio.post(
        preproductionUploadEndpoint,
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await PreproductionRecordDatabase.instance.markRecordAsUploaded(
          recordId,
        );
        return PreproductionUploadResult(
          success: true,
          message: 'Record uploaded to $baseUrl successfully.',
        );
      }

      return PreproductionUploadResult(
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

      return PreproductionUploadResult(
        success: false,
        message:
            'Upload failed${statusCode != null ? ' ($statusCode)' : ''}: ${serverMessage ?? error.message ?? 'Unable to reach the Python server.'}',
      );
    } catch (error) {
      return PreproductionUploadResult(
        success: false,
        message: 'Upload failed: $error',
      );
    }
  }
}

