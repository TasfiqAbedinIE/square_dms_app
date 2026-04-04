import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:square_dms_trial/five_s_audit/screens/five_s_audit_form_page.dart';
import 'package:square_dms_trial/five_s_audit/screens/five_s_audit_report_page.dart';

class FiveSAuditModulePage extends StatefulWidget {
  const FiveSAuditModulePage({super.key});

  @override
  State<FiveSAuditModulePage> createState() => _FiveSAuditModulePageState();
}

class _FiveSAuditModulePageState extends State<FiveSAuditModulePage> {
  static const Color _brand = Color(0xFF3B1C32);

  int _selectedIndex = 0;
  int _reportRefreshSignal = 0;
  int _syncTrigger = 0;
  bool _isSyncingMaster = false;
  String? _lastSyncAt;

  void _handleAuditSaved() {
    setState(() {
      _reportRefreshSignal++;
      _selectedIndex = 1;
    });
  }

  void _triggerMasterSync() {
    if (_selectedIndex != 0 || _isSyncingMaster) return;
    setState(() {
      _syncTrigger++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['5S Audit', '5S Report'];
    final syncLabel =
        _lastSyncAt == null
            ? 'Not synced'
            : DateFormat(
              'dd MMM, hh:mm a',
            ).format(DateTime.parse(_lastSyncAt!));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F4),
      appBar: AppBar(
        title: Text(
          titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _brand,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (_selectedIndex == 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  syncLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF786E68),
                  ),
                ),
                IconButton(
                  tooltip: 'Sync criteria',
                  onPressed: _isSyncingMaster ? null : _triggerMasterSync,
                  icon:
                      _isSyncingMaster
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.sync_outlined),
                ),
              ],
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE9E4E1)),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          FiveSAuditFormPage(
            onAuditSaved: _handleAuditSaved,
            syncTrigger: _syncTrigger,
            onSyncStateChanged: (isSyncing) {
              if (_isSyncingMaster == isSyncing) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _isSyncingMaster == isSyncing) return;
                setState(() => _isSyncingMaster = isSyncing);
              });
            },
            onLastSyncChanged: (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _lastSyncAt == value) return;
                setState(() => _lastSyncAt = value);
              });
            },
          ),
          FiveSAuditReportPage(refreshSignal: _reportRefreshSignal),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7E1DD)),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFF1ECE8),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                return TextStyle(
                  color:
                      states.contains(WidgetState.selected)
                          ? _brand
                          : const Color(0xFF756B64),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                return IconThemeData(
                  color:
                      states.contains(WidgetState.selected)
                          ? _brand
                          : const Color(0xFF756B64),
                );
              }),
            ),
            child: NavigationBar(
              height: 62,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: 'Audit',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assessment_outlined),
                  selectedIcon: Icon(Icons.assessment),
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
