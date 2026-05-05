import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class HistoryFilterSheet extends StatefulWidget {
  final String? initialStatus;
  final bool? initialIsTournament;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const HistoryFilterSheet({
    super.key,
    this.initialStatus,
    this.initialIsTournament,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<HistoryFilterSheet> {
  String? _status;
  bool? _isTournament;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _isTournament = widget.initialIsTournament;
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF070B14) : Colors.white;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black12,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header with Reset
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter Matches',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Refine your history view',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _status = null;
                      _isTournament = null;
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    backgroundColor: Colors.red.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Reset',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Match Status
                  _buildSectionLabel('MATCH STATUS', isDark),
                  const SizedBox(height: 16),
                  _buildStatusGrid(isDark),

                  const SizedBox(height: 32),

                  // 2. Date Range
                  _buildSectionLabel('DATE RANGE', isDark),
                  const SizedBox(height: 16),
                  _buildDateRangePicker(isDark),

                  const SizedBox(height: 40),

                  // Apply Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'status': _status,
                          'isTournament': _isTournament,
                          'startDate': _startDate,
                          'endDate': _endDate,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Apply Filters',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white54 : Colors.black54,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusGrid(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildStatusItem(null, 'All', isDark),
        _buildStatusItem(AppConstants.matchLive, 'Live', isDark),
        _buildStatusItem(AppConstants.matchCompleted, 'Finished', isDark),
        _buildStatusItem(AppConstants.matchUpcoming, 'Upcoming', isDark),
      ],
    );
  }

  Widget _buildStatusItem(String? value, String label, bool isDark) {
    final isSelected = _status == value;
    return InkWell(
      onTap: () => setState(() => _status = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.primaryGreen
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(12),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color:
                isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangePicker(bool isDark) {
    final hasDate = _startDate != null;
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A2A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                hasDate
                    ? AppTheme.primaryGreen.withOpacity(0.5)
                    : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05)),
            width: 1.5,
          ),
          boxShadow:
              hasDate
                  ? [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    hasDate
                        ? AppTheme.primaryGreen
                        : (isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color:
                    hasDate
                        ? Colors.white
                        : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FILTER BY DATE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryGreen,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasDate
                        ? DateFormat('EEEE, dd MMM yyyy').format(_startDate!)
                        : 'Select specific date',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color:
                          hasDate
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (hasDate)
              GestureDetector(
                onTap:
                    () => setState(() {
                      _startDate = null;
                      _endDate = null;
                    }),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.black.withOpacity(0.2),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => _buildCustomPickerTheme(context, child!),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _endDate = picked; // Set both to the same day for single date filter
      });
    }
  }

  Widget _buildCustomPickerTheme(BuildContext context, Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primaryGreen;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          onPrimary: Colors.white,
          surface: isDark ? const Color(0xFF1E293B) : Colors.white,
          onSurface: isDark ? Colors.white : Colors.black87,
          secondary: primaryColor,
        ).copyWith(brightness: isDark ? Brightness.dark : Brightness.light),
        dialogBackgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: child,
    );
  }
}
