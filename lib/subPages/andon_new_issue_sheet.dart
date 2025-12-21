import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/andon_issue_model.dart';
import '../service/andon_service.dart';
import 'package:dropdown_search/dropdown_search.dart';

class AndonNewIssueSheet extends StatefulWidget {
  final String currentUserId;

  const AndonNewIssueSheet({super.key, required this.currentUserId});

  @override
  State<AndonNewIssueSheet> createState() => _AndonNewIssueSheetState();
}

class _AndonNewIssueSheetState extends State<AndonNewIssueSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _descCtrl = TextEditingController();

  // Department / line
  String? _selectedDept; // Sewing / Cutting / Finishing
  int? _selectedLine; // 1–124

  // Sales order-related
  List<String> _salesDocs = [];
  String? _selectedSalesDoc;

  String _buyerName = '';
  List<String> _styles = [];
  String? _selectedStyle;

  // Other dropdowns
  String? _responsibleDept;
  String? _problemType;
  String _priority = 'MEDIUM';

  bool _isSaving = false;
  bool _isLoadingSalesDocs = true;

  // Local SQLite handle (sales_order_data.db)
  Database? _db;

  final _deptOptions = const [
    'Sewing',
    'Cutting',
    'Finishing',
    'Embroidery',
    'Printing',
    'Washing',
    'Maintenance',
    'Quality',
    'Store',
  ];
  final _responsibleDeptOptions = const [
    'Cutting',
    'Printing',
    'Embroidery',
    'Washing',
    'Maintenance',
    'Quality',
    'Planning',
    'IE',
    'Store',
    'TPD',
    'Marketing',
  ];
  final _problemTypeOptions = const [
    'Feeding Issues',
    'Machine Breakdown',
    'Quality Problem',
    'Machine Not Available',
    'Measurement Problem',
    'Accessories Issue',
    'Capacity Low',
    'Shading Issue',
    'Plan not available',
  ];

  final _priorityOptions = const ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

  List<int> _lineNumbers = List.generate(124, (i) => i + 1); // 1–124

  @override
  void initState() {
    super.initState();
    _initDbAndLoadSalesDocs();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _db?.close();
    super.dispose();
  }

  Future<void> _initDbAndLoadSalesDocs() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'Sales_Order.db'); // adjust name if needed
      _db = await openDatabase(path);

      await _loadUniqueSalesDocs();
    } catch (e) {
      debugPrint('Error opening sales_order_data.db: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sales orders: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSalesDocs = false);
    }
  }

  Future<void> _loadUniqueSalesDocs() async {
    if (_db == null) return;
    // Get unique salesDocument + buyerName
    final result = await _db!.rawQuery('''
      SELECT DISTINCT salesDocument, buyerName
      FROM sales_order_data
      ORDER BY salesDocument;
    ''');

    final docs = <String>[];
    // Map salesDocument -> buyerName
    for (final row in result) {
      final so = row['salesDocument']?.toString();
      if (so != null && so.isNotEmpty) {
        docs.add(so);
      }
    }

    setState(() {
      _salesDocs = docs;
    });
  }

  Future<void> _onSalesDocChanged(String? salesDoc) async {
    if (salesDoc == null || _db == null) return;

    setState(() {
      _selectedSalesDoc = salesDoc;
      _buyerName = '';
      _styles = [];
      _selectedStyle = null;
    });

    // Get buyer name + styles for this salesDocument
    final rows = await _db!.rawQuery(
      '''
      SELECT DISTINCT buyerName, style
      FROM sales_order_data
      WHERE salesDocument = ?;
      ''',
      [salesDoc],
    );

    String buyer = '';
    final styles = <String>[];

    for (final row in rows) {
      buyer = row['buyerName']?.toString() ?? buyer;
      final style = row['style']?.toString();
      if (style != null && style.isNotEmpty) {
        styles.add(style);
      }
    }

    setState(() {
      _buyerName = buyer;
      _styles = styles;
    });
  }

  bool get _needsLineSelection =>
      _selectedDept == 'Sewing' || _selectedDept == 'Finishing';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // Build a short auto title based on selections
      final titleParts = <String>[];
      if (_problemType != null) titleParts.add(_problemType!);
      if (_selectedStyle != null) titleParts.add(_selectedStyle!);
      if (_selectedSalesDoc != null) titleParts.add('SO: $_selectedSalesDoc');
      final autoTitle =
          titleParts.isEmpty ? 'Production issue' : titleParts.join(' - ');

      final issue = AndonIssue(
        id: 'dummy', // ignored on insert
        createdById: widget.currentUserId,
        createdByName: null,
        createdByDept: null,
        block: null, // you can map block later if needed
        lineNo:
            _needsLineSelection && _selectedLine != null
                ? _selectedLine.toString()
                : null,
        section: _selectedDept, // Sewing / Cutting / Finishing
        machineNo: null,
        category: _problemType, // using category as problem type
        title: autoTitle,
        description: _descCtrl.text.trim(),
        imageUrl: null,
        responsibleDept: _responsibleDept,
        assignedToId: null,
        assignedToName: null,
        status: 'OPEN',
        priority: _priority,
        createdAt: DateTime.now(),
        noticedAt: null,
        inProgressAt: null,
        solvedAt: null,
        closedAt: null,
        noticedById: null,
        inProgressById: null,
        solvedById: null,
        closedById: null,
        slaTargetMinutes: null,
        isActive: true,
        sales_document: _selectedSalesDoc.toString(),
        buyer_name: _buyerName,
        style_name: _selectedStyle.toString(),
      );

      await AndonService.instance.createIssue(issue);

      if (mounted) {
        Navigator.of(context).pop(true); // indicate success
      }
    } catch (e) {
      debugPrint('Error saving issue: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to register issue: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Register Production Issue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Department
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Department'),
                    value: _selectedDept,
                    items:
                        _deptOptions
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedDept = v;
                        if (!_needsLineSelection) {
                          _selectedLine = null;
                        }
                      });
                    },
                    validator: (v) => v == null ? 'Select department' : null,
                  ),
                  const SizedBox(height: 8),

                  // Line (only for Sewing / Finishing)
                  if (_needsLineSelection)
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Line No'),
                      value: _selectedLine,
                      items:
                          _lineNumbers
                              .map(
                                (n) => DropdownMenuItem(
                                  value: n,
                                  child: Text(n.toString()),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        setState(() => _selectedLine = v);
                      },
                      validator: (v) {
                        if (_needsLineSelection && v == null) {
                          return 'Select line no';
                        }
                        return null;
                      },
                    ),
                  if (_needsLineSelection) const SizedBox(height: 8),

                  // Sales Order dropdown (searchable)
                  _isLoadingSalesDocs
                      ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                      : DropdownSearch<String>(
                        items: (filter, _) => _salesDocs,
                        selectedItem: _selectedSalesDoc,
                        popupProps: const PopupProps.menu(showSearchBox: true),
                        decoratorProps: const DropDownDecoratorProps(
                          decoration: InputDecoration(
                            labelText: 'Sales Order (SO)',
                          ),
                        ),
                        // popupProps: const PopupProps.menu(
                        //   showSearchBox: true,
                        //   searchFieldProps: TextFieldProps(
                        //     decoration: InputDecoration(
                        //       labelText: 'Search SO…',
                        //       prefixIcon: Icon(Icons.search),
                        //     ),
                        //   ),
                        // ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Select sales order';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          // keep your existing logic
                          _onSalesDocChanged(value);
                        },
                      ),

                  const SizedBox(height: 8),

                  // Buyer name (auto filled, read only)
                  TextFormField(
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Buyer'),
                    controller: TextEditingController(text: _buyerName),
                  ),
                  const SizedBox(height: 8),

                  // Style dropdown (based on SO)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Style'),
                    value: _selectedStyle,
                    items:
                        _styles
                            .map(
                              (st) =>
                                  DropdownMenuItem(value: st, child: Text(st)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _selectedStyle = v),
                    validator: (v) => v == null ? 'Select style' : null,
                  ),
                  const SizedBox(height: 8),

                  // Responsible department
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Responsible Department',
                    ),
                    value: _responsibleDept,
                    items:
                        _responsibleDeptOptions
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _responsibleDept = v),
                    validator:
                        (v) =>
                            v == null ? 'Select responsible department' : null,
                  ),
                  const SizedBox(height: 8),

                  // Problem type
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Problem Type',
                    ),
                    value: _problemType,
                    items:
                        _problemTypeOptions
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _problemType = v),
                    validator: (v) => v == null ? 'Select problem type' : null,
                  ),
                  const SizedBox(height: 8),

                  // Priority
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Priority'),
                    value: _priority,
                    items:
                        _priorityOptions
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _priority = v ?? 'MEDIUM'),
                  ),
                  const SizedBox(height: 8),

                  // Problem description
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Problem Description',
                    ),
                    validator:
                        (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Enter problem description'
                                : null,
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child:
                          _isSaving
                              ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Save Issue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
