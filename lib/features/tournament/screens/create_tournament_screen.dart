import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/controllers/tournament_controller.dart';
import '../../../core/controllers/team_controller.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/team_model.dart';
import '../../../core/widgets/modern_app_bar.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _nameController = TextEditingController();
  final TeamController _teamController = Get.find<TeamController>();
  final TournamentController _tournamentController =
      Get.find<TournamentController>();
  final AuthController _authController = Get.find<AuthController>();

  String _selectedType = 'league';
  final List<String> _selectedTeamIds = [];
  int _defaultOvers = 10;
  int _ballsPerOver = 6;
  bool _customRulesEnabled = false;
  bool _lastPlayerCanPlay = false;
  int _maxBattingOvers = 2;
  int _maxBowlingOvers = 3;

  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1, hours: 1));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: ModernAppBar(
        title: 'SETUP TOURNAMENT',
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernHeader(),
              const SizedBox(height: 32),
              
              _buildModernCard(
                isDark,
                '1',
                'TOURNAMENT IDENTITY',
                _buildNameField(isDark),
              ),
              
              const SizedBox(height: 20),
              _buildModernCard(
                isDark,
                '2',
                'CHOOSE FORMAT',
                Row(
                  children: [
                    _buildTypeOption('league', 'League', Icons.workspace_premium_rounded, 'Round Robin'),
                    const SizedBox(width: 12),
                    _buildTypeOption('knockout', 'Knockout', Icons.account_tree_rounded, 'Elimination'),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              _buildModernCard(
                isDark,
                '3',
                'TIMELINE',
                _buildScheduleGrid(isDark),
              ),
              
              const SizedBox(height: 20),
              _buildModernCard(
                isDark,
                '4',
                'PARTICIPATING TEAMS',
                _buildTeamSelectionList(isDark),
              ),
              
              const SizedBox(height: 20),
              _buildModernCard(
                isDark,
                '5',
                'MATCH RULES',
                _buildMatchRulesSection(isDark),
              ),
              
              const SizedBox(height: 40),
              _buildCreateButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tournament Setup',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Follow the steps to launch your competition',
          style: GoogleFonts.inter(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModernCard(bool isDark, String step, String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIndicator(step, title),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildStepIndicator(String step, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryGreen, Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              step,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryGreen,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _nameController,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Tournament Name...',
          hintStyle: GoogleFonts.inter(
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
          icon: Icon(
            Icons.emoji_events_rounded,
            color: AppTheme.primaryGreen.withOpacity(0.8),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleGrid(bool isDark) {
    return Column(
      children: [
        _buildDateTimePicker(
          'START DATE',
          _startDate,
          (dt) {
            setState(() {
              _startDate = dt;
              _endDate = dt.add(const Duration(days: 1));
            });
          },
          isDark,
        ),
        const SizedBox(height: 12),
        _buildDateTimePicker(
          'END DATE',
          _endDate,
          (dt) => setState(() => _endDate = dt),
          isDark,
        ),
      ],
    );
  }

  Widget _buildTeamSelectionList(bool isDark) {
    return Obx(() {
      if (_teamController.teams.isEmpty) {
        return _buildEmptyTeamsState(isDark);
      }
      return Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _teamController.teams.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 70,
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final team = _teamController.teams[index];
              final isSelected = _selectedTeamIds.contains(team.id);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTeamIds.remove(team.id);
                    } else {
                      _selectedTeamIds.add(team.id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppTheme.primaryGreen.withOpacity(0.1) 
                              : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryGreen.withOpacity(0.3) : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          color: isSelected ? AppTheme.primaryGreen : Colors.grey,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isSelected ? AppTheme.primaryGreen : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            Text(
                              '${team.playerIds.length} Squad Members',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.scale(
                        scale: 0.9,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (val) => setState(() {
                            if (val == true) {
                              _selectedTeamIds.add(team.id);
                            } else {
                              _selectedTeamIds.remove(team.id);
                            }
                          }),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          activeColor: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Widget _buildEmptyTeamsState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.group_off_rounded, size: 48, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No teams found',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'Create at least 2 teams to continue',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return Obx(() {
      final isLoading = _tournamentController.isLoading;
      return Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : _handleCreate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LAUNCH TOURNAMENT',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.rocket_launch_rounded, size: 20),
                  ],
                ),
        ),
      );
    });
  }

  Widget _buildDateTimePicker(
    String label,
    DateTime value,
    Function(DateTime) onSelected,
    bool isDark,
  ) {
    return InkWell(
      onTap: () async {
        DateTime firstSelectableDate =
            label.contains('END')
                ? DateTime(_startDate.year, _startDate.month, _startDate.day)
                : DateTime.now().subtract(const Duration(days: 365));

        final date = await showDatePicker(
          context: context,
          initialDate:
              value.isBefore(firstSelectableDate) ? firstSelectableDate : value,
          firstDate: firstSelectableDate,
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppTheme.primaryGreen,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          if (!mounted) return;
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(value),
          );
          if (time != null) {
            onSelected(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: Colors.grey,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppTheme.primaryGreen.withOpacity(0.8),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    DateFormat('MMM d, hh:mm a').format(value),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String value, String label, IconData icon, String description) {
    final isSelected = _selectedType == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = value),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryGreen,
                      AppTheme.primaryGreen.withOpacity(0.8),
                    ],
                  )
                : null,
            color: isSelected
                ? null
                : (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryGreen
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade200),
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]
                : [],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade100),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isSelected ? Colors.white : null,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? Colors.white.withOpacity(0.8) : Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCreate() async {
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter tournament name');
      return;
    }
    if (_selectedTeamIds.length < 2) {
      Get.snackbar('Error', 'Select at least 2 teams');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      Get.snackbar('Error', 'End date cannot be before start date');
      return;
    }

    final teamNames = _teamController.teams
        .where((t) => _selectedTeamIds.contains(t.id))
        .map((t) => t.name)
        .toList();

    final id = await _tournamentController.createTournament(
      name: _nameController.text.trim(),
      createdBy: _authController.userId!,
      teamIds: _selectedTeamIds,
      teamNames: teamNames,
      type: _selectedType,
      startDate: _startDate,
      endDate: _endDate,
      defaultOvers: _defaultOvers,
      ballsPerOver: _ballsPerOver,
      customRulesEnabled: _customRulesEnabled,
      lastPlayerCanPlay: _lastPlayerCanPlay,
      maxBattingOvers: _customRulesEnabled ? _maxBattingOvers : null,
      maxBowlingOvers: _customRulesEnabled ? _maxBowlingOvers : null,
    );

    if (id != null) {
      Get.back();
      // UIUtils.showSuccess is suppressed as per rules, so using snackbar or just back
      Get.snackbar('Success', 'Tournament created successfully');
    }
  }

  Widget _buildMatchRulesSection(bool isDark) {
    return Column(
      children: [
        _buildRuleRow(
          'Match Overs',
          'Number of overs per innings',
          _defaultOvers,
          (val) => setState(() => _defaultOvers = val),
          1,
          50,
        ),
        const SizedBox(height: 12),
        _buildRuleRow(
          'Balls per Over',
          'Standard is 6 balls',
          _ballsPerOver,
          (val) => setState(() => _ballsPerOver = val),
          1,
          12,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            ),
          ),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: Text(
                  'Custom Player Rules',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Limit overs per batsman/bowler',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                ),
                value: _customRulesEnabled,
                onChanged: (val) => setState(() => _customRulesEnabled = val),
                activeColor: AppTheme.primaryGreen,
                contentPadding: EdgeInsets.zero,
              ),
              if (_customRulesEnabled) ...[
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildRuleRow(
                  'Max Batsman Overs',
                  'Overs a batsman can play',
                  _maxBattingOvers,
                  (val) => setState(() => _maxBattingOvers = val),
                  1,
                  10,
                ),
                const SizedBox(height: 12),
                _buildRuleRow(
                  'Max Bowler Overs',
                  'Overs a bowler can bowl',
                  _maxBowlingOvers,
                  (val) => setState(() => _maxBowlingOvers = val),
                  1,
                  10,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            ),
          ),
          child: SwitchListTile.adaptive(
            title: Text(
              'Last Player Standing',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Last batsman can play alone',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
            ),
            value: _lastPlayerCanPlay,
            onChanged: (val) => setState(() => _lastPlayerCanPlay = val),
            activeColor: AppTheme.primaryGreen,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildRuleRow(
    String title,
    String subtitle,
    int value,
    Function(int) onChanged,
    int min,
    int max,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16, color: AppTheme.primaryGreen),
                onPressed: value > min ? () => onChanged(value - 1) : null,
              ),
              Text(
                value.toString(),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.primaryGreen,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16, color: AppTheme.primaryGreen),
                onPressed: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
