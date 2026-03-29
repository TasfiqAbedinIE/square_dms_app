import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:square_dms_trial/database/preproduction_record_database.dart';
import 'package:square_dms_trial/models/preproduction_record_model.dart';
import 'package:square_dms_trial/preproduction_meeting/preproduction_report_page.dart';

class PreproductionMeetingPage extends StatefulWidget {
  const PreproductionMeetingPage({super.key});

  @override
  State<PreproductionMeetingPage> createState() =>
      _PreproductionMeetingPageState();
}

class _PreproductionMeetingPageState extends State<PreproductionMeetingPage> {
  static const Color _brand = Color(0xFF3B1C32);
  static const Color _brandSoft = Color(0xFFF4EDF1);

  int _selectedIndex = 0;
  int _reportRefreshSignal = 0;

  void _handleRecordSaved() {
    setState(() {
      _reportRefreshSignal++;
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Preproduction Record', 'Preproduction Report'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          PreproductionMeetingFormTab(onRecordSaved: _handleRecordSaved),
          PreproductionReportPage(refreshSignal: _reportRefreshSignal),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: const BoxDecoration(color: Colors.white),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: _brand,
              indicatorColor: _brandSoft,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                return TextStyle(
                  color:
                      states.contains(WidgetState.selected)
                          ? _brand
                          : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                return IconThemeData(
                  color:
                      states.contains(WidgetState.selected)
                          ? _brand
                          : Colors.white,
                );
              }),
            ),
            child: NavigationBar(
              height: 68,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note),
                  label: 'Record',
                ),
                NavigationDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: 'Report',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

class _PreproductionMeetingFormTabState
    extends State<PreproductionMeetingFormTab> {
  static const Color _brand = Color(0xFF3B1C32);
  static const Color _brandSoft = Color(0xFFF4EDF1);
  static const Color _border = Color(0xFFD7C5CF);
  static const int _maxPhotoBytes = 1024 * 1024;
  static const List<String> _artworkTypes = [
    'Print',
    'Embroidery',
    'Heat Press',
  ];
  static const List<String> _garmentParts = [
    'Front',
    'Back',
    'Sleeve',
    'Moon',
    'Pocket',
    'Cut & Sew',
    'Colar',
    'Cuff',
  ];

  final _formKey = GlobalKey<FormState>();
  final _ctqController = TextEditingController();
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  final Map<String, Set<String>> _selectedPartsByArtwork = {
    for (final artworkType in _artworkTypes) artworkType: <String>{},
  };

  List<Map<String, dynamic>> _salesOrderRows = [];
  List<String> _salesOrders = [];
  List<String> _buyers = [];
  List<String> _styles = [];
  List<_CapturedPhotoDraft> _photos = [];

  String? _selectedSalesOrder;
  String? _selectedBuyer;
  String? _selectedStyle;
  String? _salesOrderError;

  bool _isLoadingSalesOrders = true;
  bool _isSaving = false;
  bool _canStartNewRecord = false;

  @override
  void initState() {
    super.initState();
    _loadSalesOrderData();
  }

  @override
  void dispose() {
    _ctqController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brand, width: 1.4),
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _brandSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Future<void> _loadSalesOrderData() async {
    setState(() {
      _isLoadingSalesOrders = true;
      _salesOrderError = null;
    });

    try {
      final dbPath = await getDatabasesPath();
      final salesOrderPath = path.join(dbPath, 'Sales_Order.db');

      if (!await databaseExists(salesOrderPath)) {
        setState(() {
          _salesOrderRows = [];
          _salesOrders = [];
          _salesOrderError =
              'Sales_Order.db was not found on this device. Please sync sales order data first.';
          _isLoadingSalesOrders = false;
        });
        return;
      }

      final db = await openDatabase(salesOrderPath, readOnly: true);
      final data = await db.query('sales_order_data');
      await db.close();

      final salesOrders =
          data
              .map((row) => row['salesDocument']?.toString() ?? '')
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      setState(() {
        _salesOrderRows = data;
        _salesOrders = salesOrders;
        _salesOrderError =
            data.isEmpty ? 'Sales order data is empty on this device.' : null;
        _isLoadingSalesOrders = false;
      });
    } catch (error) {
      setState(() {
        _salesOrderRows = [];
        _salesOrders = [];
        _salesOrderError = 'Unable to read Sales_Order.db: $error';
        _isLoadingSalesOrders = false;
      });
    }
  }

  void _onSalesOrderChanged(String? value) {
    if (value == null) return;

    final matchingRows =
        _salesOrderRows
            .where((row) => row['salesDocument']?.toString() == value)
            .toList();

    final buyers =
        matchingRows
            .map((row) => row['buyerName']?.toString() ?? '')
            .where((buyer) => buyer.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final styles =
        matchingRows
            .map((row) => row['style']?.toString() ?? '')
            .where((style) => style.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    setState(() {
      _selectedSalesOrder = value;
      _buyers = buyers;
      _styles = styles;
      _selectedBuyer = buyers.length == 1 ? buyers.first : null;
      _selectedStyle = null;
    });
  }


  Future<_CapturedPhotoDraft> _compressPhoto(String sourcePath) async {
    final originalBytes = await File(sourcePath).readAsBytes();
    final originalImage = img.decodeImage(originalBytes);

    if (originalImage == null) {
      throw Exception('Unable to process the selected photo.');
    }

    img.Image workingImage = originalImage;
    Uint8List? compressedBytes;

    while (true) {
      for (final quality in [88, 80, 72, 64, 56, 48, 40, 32, 24, 18, 12]) {
        final jpgBytes = Uint8List.fromList(
          img.encodeJpg(workingImage, quality: quality),
        );
        if (jpgBytes.lengthInBytes <= _maxPhotoBytes) {
          compressedBytes = jpgBytes;
          break;
        }
      }

      if (compressedBytes != null) break;

      final nextWidth = (workingImage.width * 0.85).round();
      final nextHeight = (workingImage.height * 0.85).round();
      if (nextWidth < 320 || nextHeight < 320) {
        break;
      }

      workingImage = img.copyResize(
        originalImage,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.average,
      );
    }

    if (compressedBytes == null ||
        compressedBytes.lengthInBytes > _maxPhotoBytes) {
      throw Exception('Could not compress the photo below 1 MB.');
    }

    final base64Data = base64Encode(compressedBytes);
    return _CapturedPhotoDraft(
      localPath: sourcePath,
      photoDataBase64: base64Data,
      photoSizeBytes: compressedBytes.lengthInBytes,
    );
  }

  Future<void> _capturePhoto() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera permission is required to capture garment photos.',
          ),
        ),
      );
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );

    if (image == null) return;

    try {
      final compressedDraft = await _compressPhoto(image.path);
      final directory = await getApplicationDocumentsDirectory();
      final photoDirectory = Directory(
        path.join(directory.path, 'preproduction_photos'),
      );

      if (!await photoDirectory.exists()) {
        await photoDirectory.create(recursive: true);
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      final targetPath = path.join(photoDirectory.path, fileName);
      final savedPhoto = await File(image.path).copy(targetPath);

      if (!mounted) return;
      setState(() {
        _photos = [
          ..._photos,
          _CapturedPhotoDraft(
            localPath: savedPhoto.path,
            photoDataBase64: compressedDraft.photoDataBase64,
            photoSizeBytes: compressedDraft.photoSizeBytes,
          ),
        ];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo processing failed: $error')),
      );
    }
  }

  void _removePhoto(String photoPath) {
    setState(() {
      _photos = _photos.where((photo) => photo.localPath != photoPath).toList();
    });
  }

  Future<void> _saveRecord() async {
    final isValidForm = _formKey.currentState?.validate() ?? false;
    if (!isValidForm) return;


    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userID') ?? '';
      final now = DateTime.now().toIso8601String();
      final recordId = _uuid.v4();
      final artworkSelections =
          _selectedPartsByArtwork.entries
              .expand(
                (entry) => entry.value.map(
                  (part) => PreproductionArtworkSelection(
                    artworkType: entry.key,
                    garmentPart: part,
                  ),
                ),
              )
              .toList();

      final photos =
          _photos
              .map(
                (photo) => PreproductionPhoto(
                  localPath: photo.localPath,
                  capturedAt: now,
                  photoDataBase64: photo.photoDataBase64,
                  photoSizeBytes: photo.photoSizeBytes,
                ),
              )
              .toList();

      final record = PreproductionRecord(
        recordId: recordId,
        userId: userId,
        salesOrder: _selectedSalesOrder!,
        buyerName: _selectedBuyer!,
        style: _selectedStyle!,
        criticalToQuality: _ctqController.text.trim(),
        syncStatus: 'pending',
        createdAt: now,
        updatedAt: now,
        artworkSelections: artworkSelections,
        photos: photos,
      );

      await PreproductionRecordDatabase.instance.saveRecord(record);

      if (!mounted) return;
      setState(() => _canStartNewRecord = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preproduction record saved to local database.'),
        ),
      );
      widget.onRecordSaved?.call();
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

  void _startNewRecord() {
    setState(() {
      _selectedSalesOrder = null;
      _selectedBuyer = null;
      _selectedStyle = null;
      _buyers = [];
      _styles = [];
      _photos = [];
      for (final entry in _selectedPartsByArtwork.entries) {
        entry.value.clear();
      }
      _ctqController.clear();
      _canStartNewRecord = false;
    });
    _formKey.currentState?.reset();
  }

  Widget _buildSelectionCard() {
    return _sectionCard(
      children: [
        const Text(
          'Preproduction Record',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _brand,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedSalesOrder,
                decoration: _inputDecoration('Sales Order'),
                items:
                    _salesOrders
                        .map(
                          (salesOrder) => DropdownMenuItem(
                            value: salesOrder,
                            child: Text(salesOrder),
                          ),
                        )
                        .toList(),
                onChanged: _salesOrders.isEmpty ? null : _onSalesOrderChanged,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select sales order';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedBuyer,
                decoration: _inputDecoration('Buyer'),
                items:
                    _buyers
                        .map(
                          (buyer) => DropdownMenuItem(
                            value: buyer,
                            child: Text(buyer),
                          ),
                        )
                        .toList(),
                onChanged:
                    _buyers.isEmpty
                        ? null
                        : (value) => setState(() => _selectedBuyer = value),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select buyer';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedStyle,
          decoration: _inputDecoration('Style'),
          items:
              _styles
                  .map(
                    (style) =>
                        DropdownMenuItem(value: style, child: Text(style)),
                  )
                  .toList(),
          onChanged:
              _styles.isEmpty
                  ? null
                  : (value) => setState(() => _selectedStyle = value),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Select style';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildArtworkCard() {
    return _sectionCard(
      children: [
        const Text(
          'Artwork Type and Garment Parts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _brand,
          ),
        ),
        const SizedBox(height: 8),
        ..._artworkTypes.map((artworkType) {
          final selectedParts = _selectedPartsByArtwork[artworkType]!;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artworkType,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _brand,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      _garmentParts.map((garmentPart) {
                        final isSelected = selectedParts.contains(garmentPart);
                        return FilterChip(
                          label: Text(garmentPart),
                          selected: isSelected,
                          selectedColor: _brand.withValues(alpha: 0.16),
                          checkmarkColor: _brand,
                          side: const BorderSide(color: _border),
                          labelStyle: TextStyle(
                            color: isSelected ? _brand : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedParts.add(garmentPart);
                              } else {
                                selectedParts.remove(garmentPart);
                              }
                            });
                          },
                        );
                      }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCtqCard() {
    return _sectionCard(
      children: [
        const Text(
          'Critical to Quality',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _brand,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ctqController,
          minLines: 8,
          maxLines: 10,
          decoration: _inputDecoration(
            'Write CTQ notes, cautions or approval points',
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard() {
    return _sectionCard(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Garment Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _brand,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _capturePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Each photo is compressed below 1 MB before save and upload.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (_photos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              border: Border.all(color: _border),
            ),
            child: const Text('No photos added yet.'),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _photos.map((photo) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(photo.localPath),
                          width: 98,
                          height: 98,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 14,
                            color: Colors.white,
                            onPressed: () => _removePhoto(photo.localPath),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${(photo.photoSizeBytes / 1024).ceil()} KB',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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

  Widget _buildActionBar() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isSaving ? null : _saveRecord,
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
                    : const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _brand,
              side: const BorderSide(color: _brand),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _canStartNewRecord ? _startNewRecord : null,
            icon: const Icon(Icons.refresh),
            label: const Text('New'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSalesOrders) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: RefreshIndicator(
        color: _brand,
        onRefresh: _loadSalesOrderData,
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            if (_salesOrderError != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _salesOrderError!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
            ],
            _buildSelectionCard(),
            const SizedBox(height: 8),
            _buildArtworkCard(),
            const SizedBox(height: 8),
            _buildCtqCard(),
            const SizedBox(height: 8),
            _buildPhotoCard(),
            const SizedBox(height: 8),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }
}

class PreproductionMeetingFormTab extends StatefulWidget {
  final VoidCallback? onRecordSaved;

  const PreproductionMeetingFormTab({super.key, this.onRecordSaved});

  @override
  State<PreproductionMeetingFormTab> createState() =>
      _PreproductionMeetingFormTabState();
}





