import 'dart:io';

import 'package:flutter/material.dart';

import 'package:square_dms_trial/database/preproduction_record_database.dart';
import 'package:square_dms_trial/preproduction_meeting/preproduction_server_config.dart';
import 'package:square_dms_trial/service/preproduction_server_sync_service.dart';

class PreproductionReportPage extends StatefulWidget {
  final int refreshSignal;

  const PreproductionReportPage({super.key, required this.refreshSignal});

  @override
  State<PreproductionReportPage> createState() =>
      _PreproductionReportPageState();
}

class _PreproductionReportPageState extends State<PreproductionReportPage> {
  static const Color _brand = Color(0xFF3B1C32);
  static const Color _brandSoft = Color(0xFFF4EDF1);
  static const Color _border = Color(0xFFD7C5CF);

  bool _isLoading = true;
  String _apiBaseUrl = defaultPreproductionApiBaseUrl;
  final Set<String> _uploadingRecordIds = <String>{};
  final Set<String> _deletingRecordIds = <String>{};
  final Set<String> _expandedRecordIds = <String>{};
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  @override
  void didUpdateWidget(covariant PreproductionReportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      loadRecords();
    }
  }

  Future<void> loadRecords() async {
    setState(() => _isLoading = true);
    final records =
        await PreproductionRecordDatabase.instance.fetchRecordSummaries();
    final apiBaseUrl = await PreproductionServerConfig.getApiBaseUrl();
    if (!mounted) return;
    setState(() {
      _records = records;
      _apiBaseUrl = apiBaseUrl;
      _isLoading = false;
    });
  }

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: _apiBaseUrl);
    final newUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Server URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'http://192.168.137.1:8000',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _brand),
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newUrl == null || newUrl.trim().isEmpty) return;
    await PreproductionServerConfig.setApiBaseUrl(newUrl);
    if (!mounted) return;
    setState(() {
      _apiBaseUrl = PreproductionServerConfig.normalizeBaseUrl(newUrl);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Server URL updated to $_apiBaseUrl')),
    );
  }

  Future<void> _uploadRecord(Map<String, dynamic> record) async {
    final recordId = record['record_id']?.toString() ?? '';
    final style = record['style']?.toString() ?? '-';
    if (recordId.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploadingRecordIds.add(recordId));
    final result = await PreproductionServerSyncService.instance.uploadRecord(
      recordId,
    );
    if (!mounted) return;

    setState(() => _uploadingRecordIds.remove(recordId));
    await loadRecords();
    if (!mounted) return;

    messenger.showSnackBar(SnackBar(content: Text(result.message)));

    if (result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text('Style $style synced to the Computer server.')),
      );
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final recordId = record['record_id']?.toString() ?? '';
    final style = record['style']?.toString() ?? '-';
    if (recordId.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Local Record'),
          content: Text('Delete $style from the device database?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deletingRecordIds.add(recordId));

    try {
      final existingRecord = await PreproductionRecordDatabase.instance
          .fetchRecordById(recordId);

      if (existingRecord != null) {
        for (final photo in existingRecord.photos) {
          final file = File(photo.localPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      await PreproductionRecordDatabase.instance.deleteRecord(recordId);
      await loadRecords();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted $style from the device database.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _deletingRecordIds.remove(recordId));
      }
    }
  }

  String _formatDate(String rawValue) {
    if (rawValue.isEmpty) return '-';
    final parts = rawValue.split('T');
    if (parts.length < 2) return rawValue;
    final time = parts[1].split('.').first;
    return '${parts.first} $time';
  }

  void _toggleExpansion(String recordId) {
    setState(() {
      if (_expandedRecordIds.contains(recordId)) {
        _expandedRecordIds.remove(recordId);
      } else {
        _expandedRecordIds.add(recordId);
      }
    });
  }

  Widget _buildServerCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _brandSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upload Server',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _brand,
                  ),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brand,
                  side: const BorderSide(color: _brand),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _editServerUrl,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            _apiBaseUrl,
            style: const TextStyle(fontWeight: FontWeight.w600, color: _brand),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final recordId = record['record_id']?.toString() ?? '';
    final style = record['style']?.toString() ?? '-';
    final buyer = record['buyer_name']?.toString() ?? '-';
    final salesOrder = record['sales_order']?.toString() ?? '-';
    final createdAt = _formatDate(record['created_at']?.toString() ?? '');
    final ctq = record['critical_to_quality']?.toString() ?? '';
    final artworkCount = record['artwork_count']?.toString() ?? '0';
    final photoCount = record['photo_count']?.toString() ?? '0';
    final syncStatus = record['sync_status']?.toString() ?? 'pending';
    final isUploading = _uploadingRecordIds.contains(recordId);
    final isDeleting = _deletingRecordIds.contains(recordId);
    final isUploaded = syncStatus == 'uploaded';
    final isExpanded = _expandedRecordIds.contains(recordId);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _toggleExpansion(recordId),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _brandSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _brand,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color:
                        isUploaded
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                  ),
                  child: Text(
                    isUploaded ? 'UPLOADED' : 'PENDING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isUploaded
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      (isUploaded || isUploading || isDeleting)
                          ? null
                          : () => _uploadRecord(record),
                  child:
                      isUploading
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Upload'),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      (!isUploaded || isDeleting || isUploading)
                          ? null
                          : () => _deleteRecord(record),
                  child:
                      isDeleting
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Delete'),
                ),
                IconButton(
                  onPressed: () => _toggleExpansion(recordId),
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: _brand,
                  ),
                ),
              ],
            ),
            if (isExpanded) ...[
              const Divider(height: 16, color: _border),
              _detailRow('Sales Order', salesOrder),
              _detailRow('Buyer', buyer),
              _detailRow('Saved At', createdAt),
              _detailRow('Artwork Selections', artworkCount),
              _detailRow('Photos', photoCount),
              if (ctq.trim().isNotEmpty) _detailRow('CTQ', ctq),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _brand,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return RefreshIndicator(
        color: _brand,
        onRefresh: loadRecords,
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            _buildServerCard(),
            const SizedBox(height: 48),
            const Icon(Icons.inventory_2_outlined, size: 52, color: _brand),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'No saved preproduction records yet.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _brand,
      onRefresh: loadRecords,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _records.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildServerCard();
          }
          return _buildRecordCard(_records[index - 1]);
        },
      ),
    );
  }
}
