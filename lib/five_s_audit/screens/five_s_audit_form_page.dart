import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import 'package:square_dms_trial/database/five_s_audit_database.dart';
import 'package:square_dms_trial/five_s_audit/models/five_s_models.dart';
import 'package:square_dms_trial/five_s_audit/screens/five_s_audit_detail_page.dart';
import 'package:square_dms_trial/five_s_audit/widgets/five_s_criterion_score_row.dart';
import 'package:square_dms_trial/five_s_audit/widgets/five_s_signature_pad_section.dart';
import 'package:square_dms_trial/service/five_s_audit_supabase_service.dart';

Map<String, dynamic> _compressFiveSPhotoInBackground(
  Map<String, dynamic> args,
) {
  final sourcePath = args['sourcePath'] as String;
  final maxPhotoBytes = args['maxPhotoBytes'] as int;
  final originalBytes = File(sourcePath).readAsBytesSync();
  final originalImage = img.decodeImage(originalBytes);

  if (originalImage == null) {
    throw Exception('Unable to process selected image.');
  }

  img.Image workingImage = originalImage;
  Uint8List? compressedBytes;

  while (true) {
    for (final quality in [88, 80, 72, 64, 56, 48, 40, 32, 24, 18, 12]) {
      final jpgBytes = Uint8List.fromList(
        img.encodeJpg(workingImage, quality: quality),
      );
      if (jpgBytes.lengthInBytes <= maxPhotoBytes) {
        compressedBytes = jpgBytes;
        break;
      }
    }

    if (compressedBytes != null) break;

    final nextWidth = (workingImage.width * 0.85).round();
    final nextHeight = (workingImage.height * 0.85).round();
    if (nextWidth < 320 || nextHeight < 320) break;

    workingImage = img.copyResize(
      originalImage,
      width: nextWidth,
      height: nextHeight,
      interpolation: img.Interpolation.average,
    );
  }

  if (compressedBytes == null ||
      compressedBytes.lengthInBytes > maxPhotoBytes) {
    throw Exception('Could not compress the photo below 1 MB.');
  }

  return {
    'compressedBytes': compressedBytes,
    'photoDataBase64': base64Encode(compressedBytes),
    'photoSizeBytes': compressedBytes.lengthInBytes,
  };
}

class FiveSAuditFormPage extends StatefulWidget {
  final VoidCallback? onAuditSaved;
  final int syncTrigger;
  final ValueChanged<bool>? onSyncStateChanged;
  final ValueChanged<String?>? onLastSyncChanged;

  const FiveSAuditFormPage({
    super.key,
    this.onAuditSaved,
    this.syncTrigger = 0,
    this.onSyncStateChanged,
    this.onLastSyncChanged,
  });

  @override
  State<FiveSAuditFormPage> createState() => _FiveSAuditFormPageState();
}

class _CapturedPhotoDraft {
  final String localPath;
  final String photoDataBase64;
  final int photoSizeBytes;

  const _CapturedPhotoDraft({
    required this.localPath,
    required this.photoDataBase64,
    required this.photoSizeBytes,
  });
}

class _FiveSAuditFormPageState extends State<FiveSAuditFormPage> {
  static const Color _brand = Color(0xFF3B1C32);
  static const Color _fieldFill = Color(0xFFF4F1EF);
  static const Color _border = Color(0xFFE4DEDA);
  static const Color _muted = Color(0xFF786E68);
  static const int _maxPhotoBytes = 1024 * 1024;
  static const int _maxPhotoCount = 3;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2.6,
    penColor: const Color(0xFF3B1C32),
    exportBackgroundColor: Colors.white,
  );
  final TextEditingController _areaLineController = TextEditingController();
  final TextEditingController _productionRepresentativeController =
      TextEditingController();
  final Uuid _uuid = const Uuid();

  FiveSUserContext _userContext = FiveSUserContext.empty();
  List<FiveSDepartment> _departments = [];
  List<FiveSCategory> _categories = [];
  List<FiveSCriterion> _criteria = [];
  List<String> _lineOptions = [];
  final Map<String, int?> _selectedScores = <String, int?>{};
  final Map<String, bool> _issueFlags = <String, bool>{};
  List<_CapturedPhotoDraft> _photos = [];
  final Set<String> _expandedCategoryCodes = <String>{};

  FiveSDepartment? _selectedDepartment;
  String? _selectedLine;
  bool _isReaudit = false;
  bool _isBootstrapping = true;
  bool _isLoadingCriteria = false;
  bool _isSyncingMaster = false;
  bool _isSaving = false;
  bool _isProcessingPhotos = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant FiveSAuditFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncTrigger != oldWidget.syncTrigger) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncMasterData();
        }
      });
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _areaLineController.dispose();
    _productionRepresentativeController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _isBootstrapping = true);
    try {
      final userContext =
          await FiveSAuditSupabaseService.instance.fetchCurrentUserContext();
      final departments = await FiveSAuditDatabase.instance.fetchDepartments();
      final categories = await FiveSAuditDatabase.instance.fetchCategories();
      final lastSyncAt =
          await FiveSAuditDatabase.instance.getLastMasterSyncAt();

      if (!mounted) return;
      setState(() {
        _userContext = userContext;
        _departments = departments;
        _categories = categories;
        _isBootstrapping = false;
      });
      widget.onLastSyncChanged?.call(lastSyncAt);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBootstrapping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load 5S master data: $error')),
      );
    }
  }

  Future<void> _syncMasterData() async {
    if (_isSyncingMaster) return;
    setState(() => _isSyncingMaster = true);
    widget.onSyncStateChanged?.call(true);
    try {
      final result = await FiveSAuditSupabaseService.instance.syncMasterData();
      await _bootstrap();
      widget.onLastSyncChanged?.call(
        await FiveSAuditDatabase.instance.getLastMasterSyncAt(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Criteria synced: ${result.departmentCount} departments, ${result.criteriaCount} criteria.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Master sync failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSyncingMaster = false);
      }
      widget.onSyncStateChanged?.call(false);
    }
  }

  Future<void> _onDepartmentChanged(FiveSDepartment? department) async {
    setState(() {
      _selectedDepartment = department;
      _criteria = [];
      _selectedScores.clear();
      _issueFlags.clear();
      _selectedLine = null;
      _lineOptions = [];
      _areaLineController.clear();
      _isLoadingCriteria = true;
    });

    if (department == null) {
      setState(() => _isLoadingCriteria = false);
      return;
    }

    final criteria = await FiveSAuditDatabase.instance
        .fetchCriteriaByDepartment(department.departmentId);
    final lineOptions = await FiveSAuditSupabaseService.instance
        .fetchDepartmentLineOptions(department);

    if (!mounted) return;
    setState(() {
      _criteria = criteria;
      _lineOptions = lineOptions;
      for (final criterion in criteria) {
        _selectedScores[criterion.criterionId] = null;
        _issueFlags[criterion.criterionId] = false;
      }
      _isLoadingCriteria = false;
    });
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brand, width: 1.1),
      ),
      labelStyle: const TextStyle(color: _muted),
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _brand,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _sectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Divider(height: 1, color: Colors.grey.shade300),
    );
  }

  Map<String, List<FiveSCriterion>> _criteriaByCategory() {
    final grouped = <String, List<FiveSCriterion>>{};
    for (final criterion in _criteria) {
      grouped
          .putIfAbsent(criterion.categoryCode, () => <FiveSCriterion>[])
          .add(criterion);
    }

    final ordered = <String, List<FiveSCriterion>>{};
    for (final category in _categories) {
      final items = grouped.remove(category.code);
      if (items != null && items.isNotEmpty) {
        ordered[category.code] = items;
      }
    }

    final remainingCodes = grouped.keys.toList()..sort();
    for (final code in remainingCodes) {
      ordered[code] = grouped[code]!;
    }

    return ordered;
  }

  String _friendlyCategory(String code) {
    for (final category in _categories) {
      if (category.code == code) {
        return category.name;
      }
    }
    return code == 'SET_IN_ORDER' ? 'Set in Order' : code;
  }

  Future<_CapturedPhotoDraft> _storeCompressedPhoto(String sourcePath) async {
    final result = await compute<Map<String, dynamic>, Map<String, dynamic>>(
      _compressFiveSPhotoInBackground,
      {'sourcePath': sourcePath, 'maxPhotoBytes': _maxPhotoBytes},
    );

    final compressedBytes = result['compressedBytes'] as Uint8List;
    final directory = await getApplicationDocumentsDirectory();
    final photoDirectory = Directory(
      p.join(directory.path, 'five_s_audit_photos'),
    );
    if (!await photoDirectory.exists()) {
      await photoDirectory.create(recursive: true);
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(sourcePath)}_${_uuid.v4().substring(0, 8)}.jpg';
    final targetPath = p.join(photoDirectory.path, fileName);
    await File(targetPath).writeAsBytes(compressedBytes, flush: true);

    return _CapturedPhotoDraft(
      localPath: targetPath,
      photoDataBase64: result['photoDataBase64'] as String,
      photoSizeBytes: result['photoSizeBytes'] as int,
    );
  }

  Future<void> _addPhotosFromPaths(List<String> sourcePaths) async {
    if (sourcePaths.isEmpty || _isProcessingPhotos) return;

    final remaining = _maxPhotoCount - _photos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 issue photos are allowed.')),
      );
      return;
    }

    final limitedPaths = sourcePaths.take(remaining).toList();
    if (mounted) {
      setState(() => _isProcessingPhotos = true);
    }

    final addedPhotos = <_CapturedPhotoDraft>[];
    var failedCount = 0;

    try {
      for (final sourcePath in limitedPaths) {
        try {
          final storedPhoto = await _storeCompressedPhoto(sourcePath);
          addedPhotos.add(storedPhoto);
        } catch (_) {
          failedCount++;
        }
      }

      if (!mounted) return;
      setState(() {
        _photos = [..._photos, ...addedPhotos];
      });

      if (sourcePaths.length > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $remaining more photo${remaining == 1 ? '' : 's'} can be added.',
            ),
          ),
        );
      } else if (failedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failedCount == 1
                  ? '1 photo could not be processed.'
                  : '$failedCount photos could not be processed.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPhotos = false);
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_isProcessingPhotos) return;

    if (_photos.length >= _maxPhotoCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 issue photos are allowed.')),
      );
      return;
    }

    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required.')),
      );
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
      requestFullMetadata: false,
    );
    if (image == null) return;

    await _addPhotosFromPaths([image.path]);
  }

  Future<void> _pickGalleryPhotos() async {
    if (_isProcessingPhotos) return;

    final remaining = _maxPhotoCount - _photos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 issue photos are allowed.')),
      );
      return;
    }

    final images = await _picker.pickMultiImage(
      imageQuality: 100,
      requestFullMetadata: false,
    );
    if (images.isEmpty) return;

    await _addPhotosFromPaths(images.map((image) => image.path).toList());
  }

  Future<void> _choosePhotoSource() async {
    if (_isProcessingPhotos) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Capture from Camera'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _capturePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickGalleryPhotos();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  FiveSAuditMetrics _calculateMetrics() {
    final totalScore = _criteria.fold<int>(
      0,
      (sum, criterion) => sum + (_selectedScores[criterion.criterionId] ?? 0),
    );
    final maxScore = _criteria.fold<int>(
      0,
      (sum, criterion) => sum + criterion.maxScore,
    );
    final double percentage =
        maxScore == 0 ? 0 : (totalScore / maxScore) * 100.0;
    final ratingBand =
        percentage >= 85
            ? 'Excellent'
            : percentage >= 70
            ? 'Good'
            : 'Needs Improvement';
    return FiveSAuditMetrics(
      totalScore: totalScore,
      maxScore: maxScore,
      percentage: percentage,
      ratingBand: ratingBand,
    );
  }

  Future<Map<String, String>> _persistSignature(String auditId) async {
    final signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null || signatureBytes.isEmpty) {
      throw Exception('Production signature is required.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final signatureDirectory = Directory(
      p.join(directory.path, 'five_s_audit_signatures'),
    );
    if (!await signatureDirectory.exists()) {
      await signatureDirectory.create(recursive: true);
    }

    final signaturePath = p.join(signatureDirectory.path, '$auditId.png');
    await File(signaturePath).writeAsBytes(signatureBytes, flush: true);

    return {
      'signature_path': signaturePath,
      'signature_base64': base64Encode(signatureBytes),
    };
  }

  bool _validateCriteriaScoring() {
    if (_criteria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No criteria found for the selected department. Sync master data first.',
          ),
        ),
      );
      return false;
    }

    final unscored = _criteria.any(
      (criterion) => _selectedScores[criterion.criterionId] == null,
    );
    if (unscored) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Score all visible criteria before submission.'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _submitAudit() async {
    if (_isSaving) return;

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a department before submission.')),
      );
      return;
    }
    if (!_validateCriteriaScoring()) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Production signature is required before submission.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final auditId = _uuid.v4();
      final now = DateTime.now().toIso8601String();
      final metrics = _calculateMetrics();
      final signature = await _persistSignature(auditId);
      final areaLineValue =
          _lineOptions.isNotEmpty
              ? ((_selectedLine ?? _areaLineController.text).trim())
              : _areaLineController.text.trim();

      final details =
          _criteria.map((criterion) {
            return FiveSAuditDetail(
              auditId: auditId,
              criterionId: criterion.criterionId,
              categoryCode: criterion.categoryCode,
              criterionTitle: criterion.title,
              maxScore: criterion.maxScore,
              weight: criterion.weight,
              score: _selectedScores[criterion.criterionId] ?? 0,
              issueFlag: _issueFlags[criterion.criterionId] ?? false,
            );
          }).toList();

      final photos =
          _photos.map((photo) {
            return FiveSAuditPhoto(
              localPath: photo.localPath,
              capturedAt: now,
              photoDataBase64: photo.photoDataBase64,
              photoSizeBytes: photo.photoSizeBytes,
            );
          }).toList();

      final record = FiveSAuditRecord(
        auditId: auditId,
        departmentId: _selectedDepartment!.departmentId,
        departmentName: _selectedDepartment!.departmentName,
        areaLine: areaLineValue,
        auditDate: now,
        auditorId: _userContext.auditorId,
        auditorName: _userContext.auditorName,
        productionRepresentative:
            _productionRepresentativeController.text.trim(),
        signaturePath: signature['signature_path']!,
        signatureBase64: signature['signature_base64']!,
        totalScore: metrics.totalScore,
        maxScore: metrics.maxScore,
        percentage: metrics.percentage,
        ratingBand: metrics.ratingBand,
        syncStatus: 'pending',
        createdAt: now,
        updatedAt: now,
        uploadedAt: null,
        remarks: null,
        isReaudit: _isReaudit,
        details: details,
        photos: photos,
      );

      await FiveSAuditDatabase.instance.saveAuditRecord(record);

      if (!mounted) return;
      widget.onAuditSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('5S audit saved to local database.')),
      );
      _resetForm();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FiveSAuditDetailPage(auditId: auditId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedDepartment = null;
      _selectedLine = null;
      _isReaudit = false;
      _criteria = [];
      _lineOptions = [];
      _selectedScores.clear();
      _issueFlags.clear();
      _photos = [];
      _areaLineController.clear();
      _productionRepresentativeController.clear();
      _signatureController.clear();
    });
    _formKey.currentState?.reset();
  }

  Widget _buildHeaderSummary() {
    return const Text(
      'Department wise 5S Audit',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: _brand,
      ),
    );
  }

  Widget _buildAuditHeaderSection() {
    final currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());
    final areaLabel = _selectedDepartment?.defaultAreaType ?? 'Area';
    final usesPresetAreaOptions = _lineOptions.isNotEmpty;
    final selectionLabel =
        areaLabel.toLowerCase() == 'line' ? 'Line' : areaLabel;

    return _buildSection(
      title: 'Audit Setup',
      subtitle:
          'Select department, area or line, audit type, and responsible production person.',
      children: [
        DropdownButtonFormField<FiveSDepartment>(
          initialValue: _selectedDepartment,
          decoration: _inputDecoration('Department'),
          items:
              _departments.map((department) {
                return DropdownMenuItem<FiveSDepartment>(
                  value: department,
                  child: Text(department.departmentName),
                );
              }).toList(),
          onChanged: _onDepartmentChanged,
          validator: (value) => value == null ? 'Select department' : null,
        ),
        const SizedBox(height: 10),
        if (usesPresetAreaOptions)
          DropdownButtonFormField<String>(
            initialValue: _selectedLine,
            decoration: _inputDecoration(selectionLabel),
            items:
                _lineOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
            onChanged: (value) => setState(() => _selectedLine = value),
            validator:
                (value) =>
                    usesPresetAreaOptions && (value == null || value.isEmpty)
                        ? 'Select ${selectionLabel.toLowerCase()}'
                        : null,
          )
        else
          TextFormField(
            controller: _areaLineController,
            decoration: _inputDecoration(selectionLabel),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter ${selectionLabel.toLowerCase()}';
              }
              return null;
            },
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: currentDate,
                readOnly: true,
                decoration: _inputDecoration('Current Date'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: _userContext.auditorId,
                readOnly: true,
                decoration: _inputDecoration('Auditor'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Re-audit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _brand,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _isReaudit,
                activeTrackColor: _brand,
                onChanged: (value) => setState(() => _isReaudit = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _productionRepresentativeController,
          decoration: _inputDecoration('Production Representative'),
          validator:
              (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Enter responsible production person'
                      : null,
        ),
      ],
    );
  }

  Widget _buildCriteriaSection() {
    if (_selectedDepartment == null) {
      return _buildSection(
        title: 'Criteria',
        subtitle: 'Choose a department to load the matching 5S checklist.',
        children: const [
          Text('Department-specific criteria will appear here.'),
        ],
      );
    }

    if (_isLoadingCriteria) {
      return const Center(child: CircularProgressIndicator());
    }

    final grouped = _criteriaByCategory();
    final metrics = _calculateMetrics();

    return _buildSection(
      title: 'Criteria',
      subtitle: 'Expand each 5S category and complete every visible criterion.',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _border),
        ),
        child: Text(
          '${metrics.totalScore}/${metrics.maxScore}',
          style: const TextStyle(fontWeight: FontWeight.w700, color: _brand),
        ),
      ),
      children: [
        ...grouped.entries.map((entry) {
          final categoryCode = entry.key;
          final items = entry.value;
          final isExpanded = _expandedCategoryCodes.contains(categoryCode);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2EEEB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey<String>('five_s_'),
                initiallyExpanded: isExpanded,
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                title: Text(
                  _friendlyCategory(categoryCode),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _brand,
                  ),
                ),
                subtitle: Text(
                  '${items.length} criteria',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                onExpansionChanged: (expanded) {
                  setState(() {
                    if (expanded) {
                      _expandedCategoryCodes.add(categoryCode);
                    } else {
                      _expandedCategoryCodes.remove(categoryCode);
                    }
                  });
                },
                children: [
                  ...List.generate(items.length, (index) {
                    final criterion = items[index];
                    return Column(
                      children: [
                        FiveSCriterionScoreRow(
                          criterion: criterion,
                          selectedScore: _selectedScores[criterion.criterionId],
                          issueFlag:
                              _issueFlags[criterion.criterionId] ?? false,
                          onScoreChanged: (value) {
                            setState(() {
                              _selectedScores[criterion.criterionId] = value;
                            });
                          },
                          onIssueChanged: (value) {
                            setState(() {
                              _issueFlags[criterion.criterionId] = value;
                            });
                          },
                        ),
                        if (index != items.length - 1)
                          Divider(height: 1, color: Colors.grey.shade300),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        }),
        if (_criteria.isEmpty)
          const Text(
            'No active criteria found for this department in local master data.',
          ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return _buildSection(
      title: 'Photo Evidence',
      subtitle:
          _isProcessingPhotos
              ? 'Processing photos... keep this screen open until compression finishes.'
              : 'Add up to 3 issue photos. Images stay compressed below 1 MB.',
      trailing: TextButton.icon(
        onPressed:
            _isProcessingPhotos || _photos.length >= _maxPhotoCount
                ? null
                : _choosePhotoSource,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text('${_photos.length}/$_maxPhotoCount'),
      ),
      children: [
        if (_photos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: const Text('No issue photos added yet.'),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                _photos.map((photo) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(photo.localPath),
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: InkWell(
                          onTap:
                              _isProcessingPhotos
                                  ? null
                                  : () async {
                                    final file = File(photo.localPath);
                                    if (await file.exists()) {
                                      await file.delete();
                                    }
                                    setState(() {
                                      _photos =
                                          _photos
                                              .where(
                                                (item) =>
                                                    item.localPath !=
                                                    photo.localPath,
                                              )
                                              .toList();
                                    });
                                  },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    final metrics = _calculateMetrics();
    return _buildSection(
      title: 'Submission Preview',
      subtitle: 'Live score and rating update as criteria are completed.',
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricChip(
              'Total Score',
              '${metrics.totalScore} / ${metrics.maxScore}',
            ),
            _metricChip(
              'Percentage',
              '${metrics.percentage.toStringAsFixed(1)}%',
            ),
            _metricChip('Rating', metrics.ratingBand),
          ],
        ),
      ],
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _brand),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isSaving || _isProcessingPhotos ? null : _submitAudit,
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.check_circle_outline),
            label: const Text('Submit Audit'),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: _brand,
            side: const BorderSide(color: _border),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _isSaving || _isProcessingPhotos ? null : _resetForm,
          child: const Text('Reset'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: RefreshIndicator(
        color: _brand,
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _buildHeaderSummary(),
            _sectionDivider(),
            _buildAuditHeaderSection(),
            _sectionDivider(),
            _buildCriteriaSection(),
            _sectionDivider(),
            _buildPhotoSection(),
            _sectionDivider(),
            _buildSection(
              title: 'Signature',
              subtitle:
                  'Collect the digital sign-off from the responsible production person.',
              children: [
                FiveSSignaturePadSection(
                  controller: _signatureController,
                  onClear: _signatureController.clear,
                ),
              ],
            ),
            _sectionDivider(),
            _buildPreviewSection(),
            const SizedBox(height: 20),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }
}
