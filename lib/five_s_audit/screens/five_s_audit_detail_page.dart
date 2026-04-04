import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:square_dms_trial/database/five_s_audit_database.dart';
import 'package:square_dms_trial/five_s_audit/models/five_s_models.dart';

class FiveSAuditDetailPage extends StatefulWidget {
  final String auditId;

  const FiveSAuditDetailPage({super.key, required this.auditId});

  @override
  State<FiveSAuditDetailPage> createState() => _FiveSAuditDetailPageState();
}

class _FiveSAuditDetailPageState extends State<FiveSAuditDetailPage> {
  static const Color _brand = Color(0xFF3B1C32);
  static const Color _brandSoft = Color(0xFFF4EDF1);
  static const Color _border = Color(0xFFD7C5CF);

  bool _isLoading = true;
  FiveSAuditRecord? _record;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final record = await FiveSAuditDatabase.instance.fetchAuditById(
      widget.auditId,
    );
    if (!mounted) return;
    setState(() {
      _record = record;
      _isLoading = false;
    });
  }

  String _formatDate(String rawValue) {
    if (rawValue.isEmpty) return '-';
    final parsed = DateTime.tryParse(rawValue);
    if (parsed == null) return rawValue;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
  }

  Map<String, List<FiveSAuditDetail>> _groupedDetails(FiveSAuditRecord record) {
    final grouped = <String, List<FiveSAuditDetail>>{};
    for (final detail in record.details) {
      grouped
          .putIfAbsent(detail.categoryCode, () => <FiveSAuditDetail>[])
          .add(detail);
    }
    return grouped;
  }

  String _categoryLabel(String code) {
    switch (code) {
      case 'SORT':
        return 'Sort';
      case 'SET_IN_ORDER':
        return 'Set in Order';
      case 'SHINE':
        return 'Shine';
      case 'STANDARDIZE':
        return 'Standardize';
      case 'SUSTAIN':
        return 'Sustain';
      default:
        return code;
    }
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _brand,
              ),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final record = _record;
    if (record == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('5S Audit Detail'),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Audit not found.')),
      );
    }

    final groupedDetails = _groupedDetails(record);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(record.departmentName),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _brandSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoTile('Department', record.departmentName),
                _infoTile('Area / Line', record.areaLine),
                _infoTile('Audit Date', _formatDate(record.auditDate)),
                _infoTile('Auditor', record.auditorName),
                _infoTile('Responsible', record.productionRepresentative),
                _infoTile('Score', '${record.totalScore} / ${record.maxScore}'),
                _infoTile(
                  'Percentage',
                  '${record.percentage.toStringAsFixed(1)}%',
                ),
                _infoTile('Rating', record.ratingBand),
                _infoTile('Sync Status', record.syncStatus.toUpperCase()),
                if ((record.remarks ?? '').trim().isNotEmpty)
                  _infoTile('Remarks', record.remarks!.trim()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...groupedDetails.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _brandSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryLabel(entry.key),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _brand,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...entry.value.map((detail) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              detail.criterionTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${detail.score} / ${detail.maxScore}'),
                          const SizedBox(width: 12),
                          if (detail.issueFlag)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Issue',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _brandSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Issue Photos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _brand,
                  ),
                ),
                const SizedBox(height: 8),
                if (record.photos.isEmpty)
                  const Text('No issue photos were captured for this audit.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        record.photos.map((photo) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(photo.localPath),
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  width: 110,
                                  height: 110,
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _brandSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Signature',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _brand,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(record.signaturePath),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.draw_outlined, size: 40),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
