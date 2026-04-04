import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:square_dms_trial/database/five_s_audit_database.dart';
import 'package:square_dms_trial/five_s_audit/five_s_audit_server_config.dart';
import 'package:square_dms_trial/five_s_audit/models/five_s_models.dart';
import 'package:square_dms_trial/five_s_audit/screens/five_s_audit_detail_page.dart';
import 'package:square_dms_trial/service/five_s_audit_server_sync_service.dart';

class FiveSAuditReportPage extends StatefulWidget {
  final int refreshSignal;

  const FiveSAuditReportPage({super.key, required this.refreshSignal});

  @override
  State<FiveSAuditReportPage> createState() => _FiveSAuditReportPageState();
}

class _FiveSAuditReportPageState extends State<FiveSAuditReportPage> {
  static const Color _brand = Color(0xFF3B1C32);
  static const Color _border = Color(0xFFE4DEDA);
  static const Color _muted = Color(0xFF786E68);

  bool _isLoading = true;
  String _apiBaseUrl = defaultFiveSApiBaseUrl;
  final Set<String> _expandedGroups = <String>{};
  final Set<String> _expandedAudits = <String>{};
  final Set<String> _uploadingAuditIds = <String>{};
  final Set<String> _deletingAuditIds = <String>{};
  List<FiveSAuditSummary> _summaries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FiveSAuditReportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final summaries = await FiveSAuditDatabase.instance.fetchAuditSummaries();
    final apiBaseUrl = await FiveSAuditServerConfig.getApiBaseUrl();
    if (!mounted) return;
    setState(() {
      _summaries = summaries;
      _apiBaseUrl = apiBaseUrl;
      _isLoading = false;
    });
  }

  Map<String, List<FiveSAuditSummary>> _groupedSummaries() {
    final grouped = <String, List<FiveSAuditSummary>>{};
    for (final summary in _summaries) {
      final key =
          summary.departmentName.toLowerCase() == 'sewing' &&
                  summary.areaLine.trim().isNotEmpty
              ? summary.areaLine.trim()
              : summary.departmentName;
      grouped.putIfAbsent(key, () => <FiveSAuditSummary>[]).add(summary);
    }
    return grouped;
  }

  String _formatDate(String rawValue) {
    final parsed = DateTime.tryParse(rawValue);
    if (parsed == null) return rawValue;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
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
              onPressed:
                  () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newUrl == null || newUrl.trim().isEmpty) return;
    await FiveSAuditServerConfig.setApiBaseUrl(newUrl);
    if (!mounted) return;
    setState(() {
      _apiBaseUrl = FiveSAuditServerConfig.normalizeBaseUrl(newUrl);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Server URL updated to $_apiBaseUrl')),
    );
  }

  Future<void> _uploadAudit(FiveSAuditSummary summary) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploadingAuditIds.add(summary.auditId));
    final result = await FiveSAuditServerSyncService.instance.uploadAudit(
      summary.auditId,
    );
    if (!mounted) return;

    setState(() => _uploadingAuditIds.remove(summary.auditId));
    await _load();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _deleteAudit(FiveSAuditSummary summary) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Local Audit'),
          content: Text(
            'Delete ${summary.departmentName} audit from this device?',
          ),
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

    setState(() => _deletingAuditIds.add(summary.auditId));
    try {
      final record = await FiveSAuditDatabase.instance.fetchAuditById(
        summary.auditId,
      );
      if (record != null) {
        for (final photo in record.photos) {
          final file = File(photo.localPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        final signatureFile = File(record.signaturePath);
        if (await signatureFile.exists()) {
          await signatureFile.delete();
        }
      }
      await FiveSAuditDatabase.instance.deleteAudit(summary.auditId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${summary.departmentName} audit deleted from this device.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _deletingAuditIds.remove(summary.auditId));
      }
    }
  }

  Widget _serverStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering_outlined, color: _brand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Local upload server',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _brand),
                ),
                const SizedBox(height: 2),
                Text(
                  _apiBaseUrl,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _editServerUrl, child: const Text('Change')),
        ],
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
            width: 98,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _brand,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: _muted))),
        ],
      ),
    );
  }

  Widget _buildAuditRow(FiveSAuditSummary summary) {
    final isExpanded = _expandedAudits.contains(summary.auditId);
    final isUploading = _uploadingAuditIds.contains(summary.auditId);
    final isDeleting = _deletingAuditIds.contains(summary.auditId);
    final isUploaded = summary.syncStatus == 'uploaded';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.areaLine.trim().isEmpty
                          ? summary.departmentName
                          : summary.areaLine,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _brand,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(summary.createdAt),
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      isUploaded ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(999),
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
              IconButton(
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedAudits.remove(summary.auditId);
                    } else {
                      _expandedAudits.add(summary.auditId);
                    }
                  });
                },
                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              ),
            ],
          ),
          if (isExpanded) ...[
            const Divider(height: 20),
            _detailRow('Audit Date', _formatDate(summary.auditDate)),
            _detailRow('Auditor', summary.auditorName),
            _detailRow('Responsible', summary.productionRepresentative),
            _detailRow('Score', '${summary.totalScore} / ${summary.maxScore}'),
            _detailRow(
              'Percentage',
              '${summary.percentage.toStringAsFixed(1)}%',
            ),
            _detailRow('Rating', summary.ratingBand),
            _detailRow('Issues', '${summary.issueCount}'),
            _detailRow('Photos', '${summary.photoCount}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _brand),
                    onPressed:
                        isUploaded || isUploading || isDeleting
                            ? null
                            : () => _uploadAudit(summary),
                    icon:
                        isUploading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.cloud_upload_outlined),
                    label: Text(isUploaded ? 'Uploaded' : 'Upload'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    onPressed:
                        !isUploaded || isDeleting || isUploading
                            ? null
                            : () => _deleteAudit(summary),
                    icon:
                        isDeleting
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => FiveSAuditDetailPage(auditId: summary.auditId),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View details'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupCard(String groupName, List<FiveSAuditSummary> groupItems) {
    final isExpanded = _expandedGroups.contains(groupName);
    final average =
        groupItems.isEmpty
            ? 0
            : groupItems
                    .map((item) => item.percentage)
                    .reduce((a, b) => a + b) /
                groupItems.length;
    final pendingCount =
        groupItems.where((item) => item.syncStatus != 'uploaded').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedGroups.remove(groupName);
                } else {
                  _expandedGroups.add(groupName);
                }
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _brand,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${groupItems.length} audit(s) | Avg ${average.toStringAsFixed(1)}% | Pending $pendingCount',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: _brand,
                ),
              ],
            ),
          ),
          if (isExpanded) ...groupItems.map(_buildAuditRow),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final grouped = _groupedSummaries();

    if (_summaries.isEmpty) {
      return RefreshIndicator(
        color: _brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _serverStrip(),
            const SizedBox(height: 48),
            const Icon(Icons.fact_check_outlined, size: 50, color: _brand),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'No saved 5S audits yet.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _brand,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: grouped.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _serverStrip();
          }
          final entry = grouped.entries.elementAt(index - 1);
          return _buildGroupCard(entry.key, entry.value);
        },
      ),
    );
  }
}
