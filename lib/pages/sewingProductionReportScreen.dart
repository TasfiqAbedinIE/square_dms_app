import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SewingProductionReportScreen extends StatefulWidget {
  const SewingProductionReportScreen({super.key});

  @override
  State<SewingProductionReportScreen> createState() =>
      _SewingProductionReportScreenState();
}

class _SewingProductionReportScreenState
    extends State<SewingProductionReportScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  final Map<String, List<int>> _blockLines = const {
    '1-6': [1, 2, 3, 4, 5, 6],
    '7-15': [7, 8, 9, 10, 11, 12, 13, 14, 15],
    '16-21': [16, 17, 18, 19, 20, 21],
    '22-30': [22, 23, 24, 25, 26, 27, 28, 29, 30],
    '31-36': [31, 32, 33, 34, 35, 36],
    '37-45': [37, 38, 39, 40, 41, 42, 43, 44, 45],
    '46-49': [46, 47, 48, 49],
    '50-55': [50, 51, 52, 53, 54, 55],
    '56-62': [56, 57, 58, 59, 60, 61, 62],
    '63-69': [63, 64, 65, 66, 67, 68, 69],
    '70-76': [70, 71, 72, 73, 74, 75, 76],
    '77-81': [77, 78, 79, 80, 81],
    '82-86': [82, 83, 84, 85, 86],
    '87-91': [87, 88, 89, 90, 91],
    '92-96': [92, 93, 94, 95, 96],
    '97-105': [97, 98, 99, 100, 101, 102, 103, 104, 105],
    '106-114': [106, 107, 108, 109, 110, 111, 112, 113, 114],
    '115-124': [115, 116, 117, 118, 119, 120, 121, 122, 123, 124],
  };

  bool _isLoading = true;
  bool _isRefreshing = false;
  List<String> _blockOptions = [];
  String? _selectedBlock;
  DateTimeRange? _selectedRange;
  DateTime? _latestAvailableDate;
  _KpiMetrics _blockMetrics = const _KpiMetrics.empty();
  List<_LineMetricsRow> _lineMetrics = [];
  List<_WithoutDueBalanceRow> _withoutDueBalances = [];
  int? _withoutDueSortColumnIndex;
  bool _withoutDueSortAscending = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadWorkingAreas();
      if (_selectedBlock == null) {
        setState(() => _isLoading = false);
        return;
      }

      await _loadLatestDateForSelectedBlock();
      if (_selectedRange != null) {
        await _fetchReportData();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sewing production report.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWorkingAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString('userID') ?? '';

    if (storedUserId.isEmpty) {
      setState(() {
        _blockOptions = [];
        _selectedBlock = null;
      });
      return;
    }

    final response =
        await _client
            .from('USERS')
            .select('working_area')
            .eq('org_id', storedUserId)
            .maybeSingle();

    final rawArea = response?['working_area'];
    if (rawArea == null) {
      setState(() {
        _blockOptions = [];
        _selectedBlock = null;
      });
      return;
    }

    List<dynamic> parsedArea = [];
    if (rawArea is String) {
      parsedArea = jsonDecode(rawArea);
    } else if (rawArea is List) {
      parsedArea = rawArea;
    }

    final areaList = parsedArea.map((e) => e.toString()).toList();
    final isMasterUser = areaList.contains('MASTER');
    final blockOptions =
        isMasterUser ? _blockLines.keys.toList() : areaList.toList();

    setState(() {
      _blockOptions = blockOptions.where(_blockLines.containsKey).toList();
      _selectedBlock =
          _blockOptions.contains(_selectedBlock)
              ? _selectedBlock
              : (_blockOptions.isNotEmpty ? _blockOptions.first : null);
    });
  }

  Future<void> _loadLatestDateForSelectedBlock() async {
    final selectedBlock = _selectedBlock;
    if (selectedBlock == null) return;

    final lines = _blockLines[selectedBlock] ?? [];
    if (lines.isEmpty) return;

    final response =
        await _client
            .from('sewing_production_data')
            .select('date')
            .inFilter('lineNumber', lines)
            .order('date', ascending: false)
            .limit(1)
            .maybeSingle();

    if (response == null || response['date'] == null) {
      setState(() {
        _latestAvailableDate = null;
        _selectedRange = null;
        _lineMetrics = [];
        _withoutDueBalances = [];
        _blockMetrics = const _KpiMetrics.empty();
        _isLoading = false;
      });
      return;
    }

    final latestDate = _normalizeDate(response['date']);
    setState(() {
      _latestAvailableDate = latestDate;
      _selectedRange = DateTimeRange(start: latestDate, end: latestDate);
    });
  }

  Future<void> _fetchReportData() async {
    final selectedBlock = _selectedBlock;
    final selectedRange = _selectedRange;
    if (selectedBlock == null || selectedRange == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lines = _blockLines[selectedBlock] ?? [];
      final rangeStart = DateTime(
        selectedRange.start.year,
        selectedRange.start.month,
        selectedRange.start.day,
      );
      final rangeEnd = DateTime(
        selectedRange.end.year,
        selectedRange.end.month,
        selectedRange.end.day,
        23,
        59,
        59,
        999,
      );

      final response = await _client
          .from('sewing_production_data')
          .select(
            'lineNumber,buyerName,SO,styleName,itemName,SMV,hour,date,hourTNC,production,due,target10,manpower,rejection,without,remarks,hourMinusTNC',
          )
          .inFilter('lineNumber', lines)
          .gte('date', rangeStart.toIso8601String())
          .lte('date', rangeEnd.toIso8601String())
          .order('lineNumber')
          .order('date');

      final rows =
          response
              .map<_SewingProductionRow>(
                (row) => _SewingProductionRow.fromMap(row),
              )
              .toList();

      final blockWideResponse = await _client
          .from('sewing_production_data')
          .select('lineNumber,SO,styleName,date,due,without')
          .inFilter('lineNumber', lines)
          .order('date');

      final blockWideRows =
          blockWideResponse
              .map<_SewingProductionRow>(
                (row) => _SewingProductionRow.fromMap(row),
              )
              .toList();

      final lineMetricsByLine = <int, List<_SewingProductionRow>>{};
      for (final row in rows) {
        lineMetricsByLine.putIfAbsent(row.lineNumber, () => []).add(row);
      }

      final lineMetrics =
          lineMetricsByLine.entries
              .where(
                (entry) =>
                    entry.value.any((row) => row.smv > 0 && row.manpower > 0),
              )
              .map((entry) {
                final visibleStyles = entry.value
                    .where((e) => e.production > 0 || e.without > 0)
                    .map((e) => e.styleName.trim())
                    .where((style) => style.isNotEmpty)
                    .toSet()
                    .join(', ');

                return _LineMetricsRow(
                  lineNumber: entry.key,
                  buyerName: entry.value
                      .map((e) => e.buyerName)
                      .toSet()
                      .join(', '),
                  styleName: visibleStyles,
                  metrics: _KpiMetrics.fromRows(entry.value),
                );
              })
              .toList()
            ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));

      final withoutDueBalances = _buildWithoutDueBalances(blockWideRows);

      setState(() {
        _blockMetrics = _KpiMetrics.fromRows(rows);
        _lineMetrics = lineMetrics;
        _withoutDueBalances = withoutDueBalances;
        _withoutDueSortColumnIndex = null;
        _withoutDueSortAscending = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch sewing production data.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshLatestData() async {
    setState(() => _isRefreshing = true);
    try {
      await _loadLatestDateForSelectedBlock();
      if (_selectedRange != null) {
        await _fetchReportData();
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  DateTime _normalizeDate(dynamic rawDate) {
    final parsed = DateTime.parse(rawDate.toString()).toLocal();
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _formatNumber(num value, {int decimals = 0}) {
    return NumberFormat.decimalPattern().format(
      decimals == 0
          ? value.round()
          : double.parse(value.toStringAsFixed(decimals)),
    );
  }

  String _formatPercent(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  List<_WithoutDueBalanceRow> _buildWithoutDueBalances(
    List<_SewingProductionRow> rows,
  ) {
    final grouped = <String, _WithoutDueBalanceAccumulator>{};

    for (final row in rows) {
      final so = row.salesOrder.trim();
      final style = row.styleName.trim();
      final key = '$so|||$style';
      final accumulator = grouped.putIfAbsent(
        key,
        () => _WithoutDueBalanceAccumulator(salesOrder: so, styleName: style),
      );

      accumulator.totalWithout += row.without;
      accumulator.totalDue += row.due;

      if (row.without > 0) {
        final normalizedDate = _normalizeDate(row.date);
        if (accumulator.lastWithoutDate == null ||
            normalizedDate.isAfter(accumulator.lastWithoutDate!)) {
          accumulator.lastWithoutDate = normalizedDate;
        }
      }

      if (row.due > 0) {
        final normalizedDate = _normalizeDate(row.date);
        if (accumulator.lastDueDate == null ||
            normalizedDate.isAfter(accumulator.lastDueDate!)) {
          accumulator.lastDueDate = normalizedDate;
        }
      }
    }

    final balances =
        grouped.values
            .map((item) => item.toRow())
            .where((item) => item.balance > 0)
            .toList();

    balances.sort((a, b) {
      final salesOrderCompare = a.salesOrder.compareTo(b.salesOrder);
      if (salesOrderCompare != 0) return salesOrderCompare;
      return a.styleName.compareTo(b.styleName);
    });

    return balances;
  }

  void _sortWithoutDueTable<T>(
    int columnIndex,
    bool ascending,
    Comparable<T> Function(_WithoutDueBalanceRow row) selector,
  ) {
    setState(() {
      _withoutDueSortColumnIndex = columnIndex;
      _withoutDueSortAscending = ascending;
      _withoutDueBalances.sort((a, b) {
        final aValue = selector(a);
        final bValue = selector(b);
        return ascending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
    });
  }

  Future<void> _pickDateRange() async {
    final initialRange = _selectedRange;
    final latestDate = _latestAvailableDate;
    if (initialRange == null || latestDate == null) return;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: latestDate,
      initialDateRange: initialRange,
    );

    if (picked == null) return;

    setState(() {
      _selectedRange = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
    });
    await _fetchReportData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sewing Production Report'),
        backgroundColor: const Color.fromARGB(255, 36, 64, 142),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refreshLatestData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh latest data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLatestData,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildFilterCard(),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      _buildMessageCard(_errorMessage!),
                    if (_selectedRange == null && _errorMessage == null)
                      _buildMessageCard(
                        'No sewing production data found for your assigned block.',
                      ),
                    if (_selectedRange != null && _errorMessage == null) ...[
                      _buildSummarySection(),
                      const SizedBox(height: 16),
                      _buildLineTableSection(),
                      const SizedBox(height: 16),
                      _buildWithoutDueTableSection(),
                    ],
                  ],
                ),
      ),
    );
  }

  Widget _buildFilterCard() {
    final selectedRangeLabel =
        _selectedRange == null
            ? 'Select range'
            : '${_dateFormat.format(_selectedRange!.start)} to ${_dateFormat.format(_selectedRange!.end)}';

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
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBlock,
                    decoration: const InputDecoration(
                      labelText: 'Select Block',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items:
                        _blockOptions
                            .map(
                              (block) => DropdownMenuItem<String>(
                                value: block,
                                child: Text('Block $block'),
                              ),
                            )
                            .toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() {
                        _selectedBlock = value;
                        _selectedRange = null;
                        _latestAvailableDate = null;
                        _lineMetrics = [];
                        _withoutDueBalances = [];
                        _blockMetrics = const _KpiMetrics.empty();
                      });
                      await _loadLatestDateForSelectedBlock();
                      if (_selectedRange != null) {
                        await _fetchReportData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedRange == null ? null : _pickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      selectedRangeLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      alignment: Alignment.centerLeft,
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

  Widget _buildMessageCard(String message) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }

  Widget _buildSummarySection() {
    final cards = [
      _KpiCardData(
        title: 'Total Production',
        value: _formatNumber(_blockMetrics.actualProduction),
        color: const Color(0xFFE8F1FF),
      ),
      _KpiCardData(
        title: 'Total Target',
        value: _formatNumber(_blockMetrics.actualTarget),
        color: const Color(0xFFEAFBF0),
      ),
      _KpiCardData(
        title: 'Avg. SMV',
        value: _blockMetrics.avgSmv.toStringAsFixed(2),
        color: const Color(0xFFFFF4E5),
      ),
      _KpiCardData(
        title: 'Achievement %',
        value: _formatPercent(_blockMetrics.achievementPercent),
        color: const Color(0xFFFFEDEE),
      ),
      _KpiCardData(
        title: 'Efficiency %',
        value: _formatPercent(_blockMetrics.efficiencyPercent),
        color: const Color(0xFFEEF3FF),
      ),
      _KpiCardData(
        title: 'Avg. SAM Earners',
        value: _blockMetrics.avgSamEarners.toStringAsFixed(1),
        color: const Color(0xFFF4ECFF),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Block Wise Performance Analysis',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => _buildKpiCard(cards[index]),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: cards.length,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(_KpiCardData card) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            card.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            card.value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLineTableSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Line Wise Performance Analysis',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_lineMetrics.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No line-wise data available for the selected range.',
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFEFF4FF),
                  ),
                  columnSpacing: 24,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 120,
                  columns: const [
                    DataColumn(label: Text('Line')),
                    DataColumn(label: Text('Buyer')),
                    DataColumn(label: Text('Style')),
                    DataColumn(label: Text('Production'), numeric: true),
                    DataColumn(label: Text('Target'), numeric: true),
                    DataColumn(label: Text('Avg. SMV'), numeric: true),
                    DataColumn(label: Text('Achievement %'), numeric: true),
                    DataColumn(label: Text('Efficiency %'), numeric: true),
                    DataColumn(label: Text('Avg. SAM Earners'), numeric: true),
                  ],
                  rows:
                      _lineMetrics.map((line) {
                        final metrics = line.metrics;
                        return DataRow(
                          cells: [
                            DataCell(Text(line.lineNumber.toString())),
                            DataCell(
                              SizedBox(
                                width: 140,
                                child: Text(
                                  line.buyerName.isEmpty ? '-' : line.buyerName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 260,
                                child: Text(
                                  line.styleName.isEmpty ? '-' : line.styleName,
                                  softWrap: true,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(_formatNumber(metrics.actualProduction)),
                            ),
                            DataCell(Text(_formatNumber(metrics.actualTarget))),
                            DataCell(Text(metrics.avgSmv.toStringAsFixed(2))),
                            DataCell(
                              Text(_formatPercent(metrics.achievementPercent)),
                            ),
                            DataCell(
                              Text(_formatPercent(metrics.efficiencyPercent)),
                            ),
                            DataCell(
                              Text(metrics.avgSamEarners.toStringAsFixed(1)),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithoutDueTableSection() {
    final totalWithout = _withoutDueBalances.fold<int>(
      0,
      (sum, row) => sum + row.totalWithout,
    );
    final totalDue = _withoutDueBalances.fold<int>(
      0,
      (sum, row) => sum + row.totalDue,
    );
    final totalBalance = _withoutDueBalances.fold<int>(
      0,
      (sum, row) => sum + row.balance,
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Outstanding Without And Due By SO & Style',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_withoutDueBalances.isNotEmpty) ...[
              SizedBox(
                height: 108,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildOutstandingSummaryCard(
                      'Total Without',
                      _formatNumber(totalWithout),
                      const Color(0xFFFFF0E2),
                    ),
                    const SizedBox(width: 12),
                    _buildOutstandingSummaryCard(
                      'Total Due',
                      _formatNumber(totalDue),
                      const Color(0xFFE9F7EF),
                    ),
                    const SizedBox(width: 12),
                    _buildOutstandingSummaryCard(
                      'Balance',
                      _formatNumber(totalBalance),
                      const Color(0xFFFFE8E8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_withoutDueBalances.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No outstanding without balance found for this block.',
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: _withoutDueSortColumnIndex,
                  sortAscending: _withoutDueSortAscending,
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFFFF6E8),
                  ),
                  columnSpacing: 24,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 72,
                  columns: [
                    DataColumn(
                      label: const Text('SO'),
                      onSort:
                          (columnIndex, ascending) => _sortWithoutDueTable(
                            columnIndex,
                            ascending,
                            (row) => row.salesOrder,
                          ),
                    ),
                    DataColumn(
                      label: const Text('Style'),
                      onSort:
                          (columnIndex, ascending) => _sortWithoutDueTable(
                            columnIndex,
                            ascending,
                            (row) => row.styleName,
                          ),
                    ),
                    DataColumn(
                      label: const Text('Total Without'),
                      numeric: true,
                      onSort:
                          (columnIndex, ascending) => _sortWithoutDueTable(
                            columnIndex,
                            ascending,
                            (row) => row.totalWithout,
                          ),
                    ),
                    DataColumn(
                      label: const Text('Last Without Date'),
                      onSort:
                          (columnIndex, ascending) => _sortWithoutDueTable(
                            columnIndex,
                            ascending,
                            (row) => row.lastWithoutDate ?? DateTime(1900),
                          ),
                    ),
                    DataColumn(
                      label: const Text('Total Due'),
                      numeric: true,
                      onSort:
                          (columnIndex, ascending) => _sortWithoutDueTable(
                            columnIndex,
                            ascending,
                            (row) => row.totalDue,
                          ),
                    ),
                    DataColumn(
                      label: const Text('Last Due Date'),
                      onSort:
                          (columnIndex, ascending) => _sortWithoutDueTable(
                            columnIndex,
                            ascending,
                            (row) => row.lastDueDate ?? DateTime(1900),
                          ),
                    ),
                    DataColumn(
                      label: const Text('Balance'),
                      numeric: true,
                      onSort:
                          (columnIndex, ascending) => _sortWithoutDueTable(
                            columnIndex,
                            ascending,
                            (row) => row.balance,
                          ),
                    ),
                  ],
                  rows:
                      _withoutDueBalances.map((row) {
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 120,
                                child: Text(
                                  row.salesOrder.isEmpty ? '-' : row.salesOrder,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  row.styleName.isEmpty ? '-' : row.styleName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(_formatNumber(row.totalWithout))),
                            DataCell(
                              Text(
                                row.lastWithoutDate == null
                                    ? '-'
                                    : _dateFormat.format(row.lastWithoutDate!),
                              ),
                            ),
                            DataCell(Text(_formatNumber(row.totalDue))),
                            DataCell(
                              Text(
                                row.lastDueDate == null
                                    ? '-'
                                    : _dateFormat.format(row.lastDueDate!),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatNumber(row.balance),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutstandingSummaryCard(String title, String value, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SewingProductionRow {
  final int lineNumber;
  final String buyerName;
  final String salesOrder;
  final String styleName;
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

  const _SewingProductionRow({
    required this.lineNumber,
    required this.buyerName,
    required this.salesOrder,
    required this.styleName,
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

  factory _SewingProductionRow.fromMap(Map<String, dynamic> map) {
    return _SewingProductionRow(
      lineNumber: (map['lineNumber'] as num?)?.toInt() ?? 0,
      buyerName: (map['buyerName'] ?? '').toString(),
      salesOrder: (map['SO'] ?? map['so'] ?? '').toString(),
      styleName: (map['styleName'] ?? '').toString(),
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
  double get availableMinutes => (hourTnc / 10) * hour * manpower * 60;
  double get earnedMinutes => actualProduction * smv;
}

class _KpiMetrics {
  final int actualProduction;
  final double actualTarget;
  final double availableMinutes;
  final double earnedMinutes;
  final double avgSmv;
  final double achievementPercent;
  final double efficiencyPercent;
  final double avgSamEarners;

  const _KpiMetrics({
    required this.actualProduction,
    required this.actualTarget,
    required this.availableMinutes,
    required this.earnedMinutes,
    required this.avgSmv,
    required this.achievementPercent,
    required this.efficiencyPercent,
    required this.avgSamEarners,
  });

  const _KpiMetrics.empty()
    : actualProduction = 0,
      actualTarget = 0,
      availableMinutes = 0,
      earnedMinutes = 0,
      avgSmv = 0,
      achievementPercent = 0,
      efficiencyPercent = 0,
      avgSamEarners = 0;

  factory _KpiMetrics.fromRows(List<_SewingProductionRow> rows) {
    if (rows.isEmpty) {
      return const _KpiMetrics.empty();
    }

    int actualProduction = 0;
    double actualTarget = 0;
    double availableMinutes = 0;
    double earnedMinutes = 0;
    double manpowerSum = 0;

    for (final row in rows) {
      actualProduction += row.actualProduction;
      actualTarget += row.actualTarget;
      availableMinutes += row.availableMinutes;
      earnedMinutes += row.earnedMinutes;
      manpowerSum += row.manpower;
    }

    final avgSmv =
        actualProduction > 0 ? earnedMinutes / actualProduction : 0.0;
    final achievementPercent =
        actualTarget > 0 ? (actualProduction / actualTarget) * 100 : 0.0;
    final efficiencyPercent =
        availableMinutes > 0 ? (earnedMinutes / availableMinutes) * 100 : 0.0;
    final avgSamEarners = rows.isNotEmpty ? manpowerSum / rows.length : 0.0;

    return _KpiMetrics(
      actualProduction: actualProduction,
      actualTarget: actualTarget,
      availableMinutes: availableMinutes,
      earnedMinutes: earnedMinutes,
      avgSmv: avgSmv,
      achievementPercent: achievementPercent,
      efficiencyPercent: efficiencyPercent,
      avgSamEarners: avgSamEarners,
    );
  }
}

class _LineMetricsRow {
  final int lineNumber;
  final String buyerName;
  final String styleName;
  final _KpiMetrics metrics;

  const _LineMetricsRow({
    required this.lineNumber,
    required this.buyerName,
    required this.styleName,
    required this.metrics,
  });
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

class _WithoutDueBalanceAccumulator {
  final String salesOrder;
  final String styleName;
  int totalWithout = 0;
  int totalDue = 0;
  DateTime? lastWithoutDate;
  DateTime? lastDueDate;

  _WithoutDueBalanceAccumulator({
    required this.salesOrder,
    required this.styleName,
  });

  _WithoutDueBalanceRow toRow() {
    return _WithoutDueBalanceRow(
      salesOrder: salesOrder,
      styleName: styleName,
      totalWithout: totalWithout,
      lastWithoutDate: lastWithoutDate,
      totalDue: totalDue,
      lastDueDate: lastDueDate,
      balance: totalWithout - totalDue,
    );
  }
}

class _WithoutDueBalanceRow {
  final String salesOrder;
  final String styleName;
  final int totalWithout;
  final DateTime? lastWithoutDate;
  final int totalDue;
  final DateTime? lastDueDate;
  final int balance;

  const _WithoutDueBalanceRow({
    required this.salesOrder,
    required this.styleName,
    required this.totalWithout,
    required this.lastWithoutDate,
    required this.totalDue,
    required this.lastDueDate,
    required this.balance,
  });
}
