import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StyleRecordScreen extends StatefulWidget {
  const StyleRecordScreen({super.key});

  @override
  State<StyleRecordScreen> createState() => _StyleRecordScreenState();
}

class _StyleRecordScreenState extends State<StyleRecordScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _styleController = TextEditingController();
  final FocusNode _styleFocusNode = FocusNode();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  Timer? _debounce;
  List<String> _styleSuggestions = [];
  List<_StyleProductionRow> _rows = [];
  _StyleMetrics _summary = const _StyleMetrics.empty();
  _PivotMode _pivotMode = _PivotMode.date;
  bool _isLoading = false;
  bool _isSuggesting = false;
  String? _searchedStyle;
  String? _errorMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    _styleController.dispose();
    _styleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStyleSuggestions(String query) async {
    final trimmedQuery = query.trim();
    _debounce?.cancel();

    if (trimmedQuery.isEmpty) {
      setState(() => _styleSuggestions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isSuggesting = true);

      try {
        final response = await _client
            .from('sewing_production_data')
            .select('styleName')
            .ilike('styleName', '%$trimmedQuery%')
            .order('styleName')
            .limit(25);

        final suggestions =
            response
                .map((row) => (row['styleName'] ?? '').toString().trim())
                .where((style) => style.isNotEmpty)
                .toSet()
                .take(12)
                .toList();

        if (mounted) {
          setState(() => _styleSuggestions = suggestions);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _styleSuggestions = []);
        }
      } finally {
        if (mounted) {
          setState(() => _isSuggesting = false);
        }
      }
    });
  }

  Future<void> _searchStyle() async {
    final style = _styleController.text.trim();
    if (style.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a style name.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchedStyle = style;
      _rows = [];
      _summary = const _StyleMetrics.empty();
    });

    try {
      final response = await _client
          .from('sewing_production_data')
          .select(
            'lineNumber,buyerName,SO,styleName,itemName,SMV,hour,date,hourTNC,production,due,target10,manpower,rejection,without,hourMinusTNC',
          )
          .ilike('styleName', '%$style%')
          .order('date')
          .order('lineNumber');

      final rows =
          response
              .map<_StyleProductionRow>(
                (row) => _StyleProductionRow.fromMap(row),
              )
              .toList();

      setState(() {
        _rows = rows;
        _summary = _StyleMetrics.fromRows(rows);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Failed to fetch style production history.';
        _isLoading = false;
      });
    }
  }

  String _formatNumber(num value, {int decimals = 0}) {
    if (decimals == 0) {
      return NumberFormat.decimalPattern().format(value.round());
    }
    return NumberFormat.decimalPattern().format(
      double.parse(value.toStringAsFixed(decimals)),
    );
  }

  String _formatPercent(double value) => '${value.toStringAsFixed(1)}%';

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return _dateFormat.format(DateTime(local.year, local.month, local.day));
  }

  Map<String, List<_StyleProductionRow>> _groupRows() {
    final grouped = <String, List<_StyleProductionRow>>{};
    for (final row in _rows) {
      final key =
          _pivotMode == _PivotMode.date
              ? _formatDate(row.date)
              : row.lineNumber.toString();
      grouped.putIfAbsent(key, () => []).add(row);
    }
    return grouped;
  }

  List<DataRow> _buildPivotRows() {
    final grouped = _groupRows();
    final dataRows = <DataRow>[];

    for (final entry in grouped.entries) {
      final groupRows = entry.value;
      final metrics = _StyleMetrics.fromRows(groupRows);

      for (var index = 0; index < groupRows.length; index++) {
        final row = groupRows[index];
        dataRows.add(
          DataRow(
            cells: [
              DataCell(Text(index == 0 ? entry.key : '')),
              DataCell(
                Text(
                  _pivotMode == _PivotMode.date
                      ? row.lineNumber.toString()
                      : _formatDate(row.date),
                ),
              ),
              DataCell(_wideText(row.buyerName)),
              DataCell(Text(row.salesOrder.isEmpty ? '-' : row.salesOrder)),
              DataCell(_wideText(row.itemName)),
              DataCell(Text(_formatNumber(row.actualProduction))),
              DataCell(Text(_formatNumber(row.actualTarget))),
              DataCell(Text(_formatNumber(row.without))),
              DataCell(Text(_formatNumber(row.manpower))),
              DataCell(Text(row.smv.toStringAsFixed(2))),
              DataCell(Text(row.workingHour.toStringAsFixed(1))),
              DataCell(Text(_formatPercent(row.achievementPercent))),
              DataCell(Text(_formatPercent(row.efficiencyPercent))),
            ],
          ),
        );
      }

      dataRows.add(
        DataRow(
          color: WidgetStateProperty.all(const Color(0xFFEFF4FF)),
          cells: [
            DataCell(
              Text(
                '${entry.key} Total',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            DataCell(_boldText(_formatNumber(metrics.actualProduction))),
            DataCell(_boldText(_formatNumber(metrics.actualTarget))),
            DataCell(_boldText(_formatNumber(metrics.withoutQuantity))),
            DataCell(_boldText(metrics.avgManpower.toStringAsFixed(1))),
            DataCell(_boldText(metrics.avgSmv.toStringAsFixed(2))),
            DataCell(_boldText(metrics.workingHour.toStringAsFixed(1))),
            DataCell(_boldText(_formatPercent(metrics.achievementPercent))),
            DataCell(_boldText(_formatPercent(metrics.efficiencyPercent))),
          ],
        ),
      );
    }

    return dataRows;
  }

  Widget _wideText(String value) {
    return SizedBox(
      width: 160,
      child: Text(
        value.trim().isEmpty ? '-' : value.trim(),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _boldText(String value) {
    return Text(value, style: const TextStyle(fontWeight: FontWeight.w700));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Style Record'),
        backgroundColor: const Color.fromARGB(255, 36, 64, 142),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSearchPanel(),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            _buildMessageCard(_errorMessage!)
          else if (_rows.isEmpty)
            _buildMessageCard(
              _searchedStyle == null
                  ? 'Search a style to view date-wise production history.'
                  : 'No production history found for "$_searchedStyle".',
            )
          else ...[
            _buildSummarySection(),
            const SizedBox(height: 16),
            _buildPivotSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Style',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RawAutocomplete<String>(
                    textEditingController: _styleController,
                    focusNode: _styleFocusNode,
                    optionsBuilder: (textEditingValue) {
                      _loadStyleSuggestions(textEditingValue.text);
                      return _styleSuggestions.where(
                        (style) => style.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                      );
                    },
                    onSelected: (value) {
                      _styleController.text = value;
                    },
                    fieldViewBuilder: (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchStyle(),
                        decoration: InputDecoration(
                          labelText: 'Style name',
                          hintText: 'Type style name',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _isSuggesting
                                  ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                  : null,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 280,
                              maxWidth: 520,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _searchStyle,
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Search'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final cards = [
      _KpiCardData(
        title: 'Production',
        value: _formatNumber(_summary.actualProduction),
        color: const Color(0xFFE8F1FF),
      ),
      _KpiCardData(
        title: 'Target',
        value: _formatNumber(_summary.actualTarget),
        color: const Color(0xFFEAFBF0),
      ),
      _KpiCardData(
        title: 'Without Qty',
        value: _formatNumber(_summary.withoutQuantity),
        color: const Color(0xFFFFF4E5),
      ),
      _KpiCardData(
        title: 'Avg. SMV',
        value: _summary.avgSmv.toStringAsFixed(2),
        color: const Color(0xFFF4ECFF),
      ),
      _KpiCardData(
        title: 'Achievement',
        value: _formatPercent(_summary.achievementPercent),
        color: const Color(0xFFFFEDEE),
      ),
      _KpiCardData(
        title: 'Efficiency',
        value: _formatPercent(_summary.efficiencyPercent),
        color: const Color(0xFFEEF3FF),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Style Summary${_searchedStyle == null ? '' : ' - $_searchedStyle'}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _buildKpiCard(cards[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(_KpiCardData card) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            card.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            card.value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPivotSection() {
    final firstColumn = _pivotMode == _PivotMode.date ? 'Date' : 'Line';
    final secondColumn = _pivotMode == _PivotMode.date ? 'Line' : 'Date';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Production History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SegmentedButton<_PivotMode>(
                  segments: const [
                    ButtonSegment(
                      value: _PivotMode.date,
                      icon: Icon(Icons.calendar_month),
                      label: Text('Date'),
                    ),
                    ButtonSegment(
                      value: _PivotMode.line,
                      icon: Icon(Icons.view_week),
                      label: Text('Line'),
                    ),
                  ],
                  selected: {_pivotMode},
                  onSelectionChanged: (selection) {
                    setState(() => _pivotMode = selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFEFF4FF),
                ),
                columnSpacing: 22,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 72,
                columns: [
                  DataColumn(label: Text(firstColumn)),
                  DataColumn(label: Text(secondColumn)),
                  const DataColumn(label: Text('Buyer')),
                  const DataColumn(label: Text('SO')),
                  const DataColumn(label: Text('Item')),
                  const DataColumn(label: Text('Production'), numeric: true),
                  const DataColumn(label: Text('Target'), numeric: true),
                  const DataColumn(label: Text('Without Qty'), numeric: true),
                  const DataColumn(label: Text('Manpower'), numeric: true),
                  const DataColumn(label: Text('SMV'), numeric: true),
                  const DataColumn(label: Text('Working Hr'), numeric: true),
                  const DataColumn(label: Text('Ach %'), numeric: true),
                  const DataColumn(label: Text('Efficiency %'), numeric: true),
                ],
                rows: _buildPivotRows(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(String message) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}

enum _PivotMode { date, line }

class _StyleProductionRow {
  final int lineNumber;
  final String buyerName;
  final String salesOrder;
  final String styleName;
  final String itemName;
  final double smv;
  final double hour;
  final DateTime date;
  final double hourTnc;
  final int production;
  final int due;
  final double target10;
  final int manpower;
  final int rejection;
  final int without;
  final double hourMinusTnc;

  const _StyleProductionRow({
    required this.lineNumber,
    required this.buyerName,
    required this.salesOrder,
    required this.styleName,
    required this.itemName,
    required this.smv,
    required this.hour,
    required this.date,
    required this.hourTnc,
    required this.production,
    required this.due,
    required this.target10,
    required this.manpower,
    required this.rejection,
    required this.without,
    required this.hourMinusTnc,
  });

  factory _StyleProductionRow.fromMap(Map<String, dynamic> map) {
    return _StyleProductionRow(
      lineNumber: (map['lineNumber'] as num?)?.toInt() ?? 0,
      buyerName: (map['buyerName'] ?? '').toString(),
      salesOrder: (map['SO'] ?? map['so'] ?? '').toString(),
      styleName: (map['styleName'] ?? '').toString(),
      itemName: (map['itemName'] ?? '').toString(),
      smv: ((map['SMV'] ?? map['smv']) as num?)?.toDouble() ?? 0,
      hour: (map['hour'] as num?)?.toDouble() ?? 0,
      date: DateTime.parse(map['date'].toString()),
      hourTnc: ((map['hourTNC'] ?? map['hourTnc']) as num?)?.toDouble() ?? 0,
      production: (map['production'] as num?)?.toInt() ?? 0,
      due: (map['due'] as num?)?.toInt() ?? 0,
      target10: (map['target10'] as num?)?.toDouble() ?? 0,
      manpower: (map['manpower'] as num?)?.toInt() ?? 0,
      rejection: (map['rejection'] as num?)?.toInt() ?? 0,
      without: (map['without'] as num?)?.toInt() ?? 0,
      hourMinusTnc:
          ((map['hourMinusTNC'] ?? map['hourMinusTnc']) as num?)?.toDouble() ??
          0,
    );
  }

  int get actualProduction => without + production + rejection - due;
  double get actualTarget => (target10 / 10) * hourMinusTnc;
  double get workingHour => hourMinusTnc;
  double get availableMinutes => (hourTnc / 10) * hour * manpower * 60;
  double get earnedMinutes => actualProduction * smv;
  double get achievementPercent =>
      actualTarget > 0 ? actualProduction / actualTarget * 100 : 0;
  double get efficiencyPercent =>
      availableMinutes > 0 ? earnedMinutes / availableMinutes * 100 : 0;
}

class _StyleMetrics {
  final int actualProduction;
  final double actualTarget;
  final int withoutQuantity;
  final double avgManpower;
  final double avgSmv;
  final double workingHour;
  final double achievementPercent;
  final double efficiencyPercent;

  const _StyleMetrics({
    required this.actualProduction,
    required this.actualTarget,
    required this.withoutQuantity,
    required this.avgManpower,
    required this.avgSmv,
    required this.workingHour,
    required this.achievementPercent,
    required this.efficiencyPercent,
  });

  const _StyleMetrics.empty()
    : actualProduction = 0,
      actualTarget = 0,
      withoutQuantity = 0,
      avgManpower = 0,
      avgSmv = 0,
      workingHour = 0,
      achievementPercent = 0,
      efficiencyPercent = 0;

  factory _StyleMetrics.fromRows(List<_StyleProductionRow> rows) {
    if (rows.isEmpty) return const _StyleMetrics.empty();

    int production = 0;
    int withoutQuantity = 0;
    double target = 0;
    double earnedMinutes = 0;
    double availableMinutes = 0;
    double manpower = 0;
    double workingHour = 0;

    for (final row in rows) {
      production += row.actualProduction;
      withoutQuantity += row.without;
      target += row.actualTarget;
      earnedMinutes += row.earnedMinutes;
      availableMinutes += row.availableMinutes;
      manpower += row.manpower;
      workingHour += row.workingHour;
    }

    return _StyleMetrics(
      actualProduction: production,
      actualTarget: target,
      withoutQuantity: withoutQuantity,
      avgManpower: manpower / rows.length,
      avgSmv: production > 0 ? earnedMinutes / production : 0,
      workingHour: workingHour,
      achievementPercent: target > 0 ? production / target * 100 : 0,
      efficiencyPercent:
          availableMinutes > 0 ? earnedMinutes / availableMinutes * 100 : 0,
    );
  }
}

class _KpiCardData {
  final String title;
  final String value;
  final Color color;

  const _KpiCardData({
    required this.title,
    required this.value,
    required this.color,
  });
}
