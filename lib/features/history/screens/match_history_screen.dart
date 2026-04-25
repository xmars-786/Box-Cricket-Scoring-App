import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/models/match_model.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../match/screens/match_detail_screen.dart';
import '../../match/widgets/match_card_widget.dart';

/// Displays completed match history with results and stats using GetX.
class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  final MatchController matchController = Get.find<MatchController>();
  final AuthController authController = Get.find<AuthController>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DateTime? _selectedDate;
  String _searchQuery = '';

  Future<void> _confirmDelete(MatchModel match) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Delete Match',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to delete this match permanently?',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await matchController.deleteMatch(match.id);
    }
  }

  @override
  void initState() {
    super.initState();
    matchController.loadCompletedMatches(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      matchController.loadCompletedMatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Match History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Filter section
          _buildFilters(isDark),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => matchController.loadCompletedMatches(refresh: true),
              color: AppTheme.primaryGreen,
              child: Obx(() {
              if (matchController.error != null && matchController.completedMatches.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          matchController.error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => matchController.loadCompletedMatches(refresh: true),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (matchController.isLoading &&
                  matchController.completedMatches.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final filteredMatches = matchController.completedMatches.where((match) {
                final matchesName = match.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    match.teamAName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    match.teamBName.toLowerCase().contains(_searchQuery.toLowerCase());
                
                bool matchesDate = true;
                if (_selectedDate != null) {
                  final mDate = match.completedAt ?? match.createdAt;
                  matchesDate = mDate.year == _selectedDate!.year &&
                      mDate.month == _selectedDate!.month &&
                      mDate.day == _selectedDate!.day;
                }

                return matchesName && matchesDate;
              }).toList();

              if (filteredMatches.isEmpty) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          matchController.completedMatches.isEmpty 
                            ? Icons.history 
                            : Icons.search_off_rounded,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          matchController.completedMatches.isEmpty
                            ? 'No completed matches yet'
                            : 'No matches match your filters',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        if (matchController.completedMatches.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                                _selectedDate = null;
                              });
                            },
                            child: const Text('Clear Filters'),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull down to refresh',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount:
                    filteredMatches.length + (matchController.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < filteredMatches.length) {
                    return _buildHistoryCard(filteredMatches[index], isDark);
                  } else {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                },
              );
            }),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey[200]!,
          ),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by team or match name...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1B263B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1B263B)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _selectedDate != null
                                  ? AppTheme.primaryGreen
                                  : (isDark
                                      ? Colors.white10
                                      : Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color:
                                _selectedDate != null
                                    ? AppTheme.primaryGreen
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDate == null
                                ? 'Filter by Date'
                                : DateFormat(
                                  'dd MMM yyyy',
                                ).format(_selectedDate!),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight:
                                  _selectedDate != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                              color:
                                  _selectedDate != null
                                      ? AppTheme.primaryGreen
                                      : (isDark ? Colors.white70 : Colors.grey),
                            ),
                          ),
                          if (_selectedDate != null) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                setState(() => _selectedDate = null);
                              },
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildHistoryCard(MatchModel match, bool isDark) {
    return MatchCardWidget(
      match: match,
      isDark: isDark,
      isAdmin: authController.currentUser?.isAdmin ?? false,
      onDelete: () => _confirmDelete(match),
    );
  }
}
