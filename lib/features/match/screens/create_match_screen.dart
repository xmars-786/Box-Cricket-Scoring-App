import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:x_cricket/core/models/team_model.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/player_model.dart';
import '../../../core/models/match_model.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/controllers/rules_controller.dart';
import '../../../core/controllers/team_controller.dart';
import '../../../core/controllers/tournament_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../core/widgets/modern_app_bar.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final AuthController authController = Get.find<AuthController>();
  final MatchController matchController = Get.find<MatchController>();
  final RulesController rulesController = Get.find<RulesController>();
  final TeamController teamController = Get.find<TeamController>();
  final TournamentController tournamentController =
      Get.find<TournamentController>();

  // Form fields
  final _titleController = TextEditingController();
  final _teamANameController = TextEditingController();
  final _teamBNameController = TextEditingController();
  String? _teamAId;
  String? _teamBId;
  int _totalOvers = 10;
  int _ballsPerOver = 6;
  String? _teamACaptainId;
  String? _teamBCaptainId;
  String _tossWonBy = 'A';
  String _tossDecision = 'bat';
  bool _customRulesEnabled = false;
  bool _lastPlayerCanPlay = false;
  int _maxBattingOvers = 2;
  int _maxBowlingOvers = 3;

  String? _tournamentId;
  bool _isTournamentFixed = false;
  String? _round = 'League';

  // Manual Fixture State
  bool _isAddingManualFixture = false;
  String? _manualTeamAId;
  String? _manualTeamBId;
  final TextEditingController _manualTitleController = TextEditingController();

  String? _scheduledMatchId;

  // Players
  final List<PlayerModel> _teamAPlayers = [];
  final List<PlayerModel> _teamBPlayers = [];

  // Registered users from DB
  List<AppUser> _registeredUsers = [];
  bool _isLoadingUsers = true;

  // Scorers
  final List<String> _selectedScorerIds = [];

  int _currentStep = 0;
  bool _isCreatingMatch = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _customRulesEnabled = rulesController.customRulesEnabled.value;
    _lastPlayerCanPlay = rulesController.lastPlayerCanPlay.value;
    _maxBattingOvers = rulesController.maxBattingOvers.value;
    _maxBowlingOvers = rulesController.maxBowlingOvers.value;

    // Set current user as default scorer
    if (authController.userId != null) {
      _selectedScorerIds.add(authController.userId!);
    }

    // Handle arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.arguments is Map) {
        final args = Get.arguments as Map;
        if (args.containsKey('tournamentId')) {
          _tournamentId = args['tournamentId'];
          if (_tournamentId != null) {
            _isTournamentFixed = true;
            tournamentController.listenToTournament(_tournamentId!);

            // Reactive listener for tournament data to ensure rules are applied once loaded
            ever(tournamentController.selectedTournamentRx, (tournament) {
              if (tournament != null &&
                  tournament.id == _tournamentId &&
                  mounted) {
                _applyTournamentRules(tournament);
              }
            });

            // Also listen to matches to auto-number
            ever(tournamentController.tournamentMatchesRx, (matches) {
              if (mounted &&
                  (_titleController.text.isEmpty ||
                      _titleController.text.startsWith('Match '))) {
                _titleController.text = 'Match ${matches.length + 1}';
              }
            });

            // Initial attempt (might be null)
            _applyPreviousMatchSettings(_tournamentId!);
          }
        }
        if (args.containsKey('existingMatchId')) {
          final matchId = args['existingMatchId'];
          if (matchId != null) {
            // Wait for users to load first to enable fast local squad population
            _fetchUsers().then((_) => _loadAndStartScheduledMatch(matchId));
          }
        }
      }
    });
  }

  Future<void> _fetchUsers() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection(AppConstants.usersCollection)
              .get();
      if (mounted) {
        setState(() {
          _registeredUsers =
              snapshot.docs
                  .map((d) => AppUser.fromFirestore(d))
                  .where((u) => u.isApproved)
                  .toList();
          _isLoadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _teamANameController.dispose();
    _teamBNameController.dispose();
    super.dispose();
  }

  AppUser? _userForPlayer(PlayerModel p) {
    try {
      return _registeredUsers.firstWhere((u) => u.uid == p.id);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.primaryDark : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const ModernSliverAppBar(title: 'NEW MATCH'),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProgressHeader(isDark),
                const SizedBox(height: 32),
                Form(key: _formKey, child: _buildCurrentStep(isDark)),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomControls(isDark),
    );
  }

  Widget _buildProgressHeader(bool isDark) {
    return Row(
      children: [
        _buildStepIndicator(0, 'DETAILS', isDark),
        _buildStepLine(0),
        _buildStepIndicator(1, 'SQUADS', isDark),
        _buildStepLine(1),
        _buildStepIndicator(2, 'TOSS', isDark),
      ],
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isDark) {
    final isActive = _currentStep >= step;
    final isCompleted = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isCompleted
                    ? AppTheme.primaryGreen
                    : (isActive
                        ? AppTheme.primaryGreen.withOpacity(0.2)
                        : (isDark ? Colors.white10 : Colors.black12)),
            border: Border.all(
              color: isActive ? AppTheme.primaryGreen : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child:
                isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                      '${step + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color:
                            isActive
                                ? AppTheme.primaryGreen
                                : (isDark ? Colors.white24 : Colors.black26),
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color:
                isActive
                    ? AppTheme.primaryGreen
                    : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isCompleted = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
        decoration: BoxDecoration(
          color:
              isCompleted
                  ? AppTheme.primaryGreen
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white10
                      : Colors.black12),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildMatchDetailsStep(isDark);
      case 1:
        return _buildPlayersStep(isDark);
      case 2:
        return _buildTossStep(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomControls(bool isDark) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.primaryDark : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
          ),
        ),
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Text(
                    'BACK',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (!(_currentStep == 0 && _tournamentId != null))
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child:
                        _isCreatingMatch
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                              _currentStep == 2 ? 'CREATE MATCH' : 'CONTINUE',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchDetailsStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(() {
          if (!rulesController.isTournamentEnabled.value) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'TOURNAMENT CONTEXT',
                Icons.emoji_events_rounded,
                isDark,
              ),
              const SizedBox(height: 16),
              if (_isTournamentFixed) ...[
                _buildTournamentInfo(isDark),
              ] else ...[
                _buildTournamentSelector(isDark),
              ],
              if (_tournamentId != null) ...[
                const SizedBox(height: 16),
                Obx(() {
                  final tournament = tournamentController.selectedTournament;
                  if (tournament == null) return const SizedBox.shrink();

                  if (_isAddingManualFixture) {
                    return _buildAddTournamentMatchForm(isDark, tournament);
                  }

                  return _buildTournamentScheduleView(isDark, tournament);
                }),
              ],
              const SizedBox(height: 32),
            ],
          );
        }),
        if (_tournamentId == null) ...[
          const SizedBox(height: 32),
          _buildSectionHeader('MATCH INFORMATION', Icons.info_rounded, isDark),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Match Title (e.g. Semi Final 1)',
              prefixIcon: const Icon(Icons.title_rounded),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color:
                      isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                ),
              ),
            ),
            validator:
                (v) => v == null || v.isEmpty ? 'Enter match title' : null,
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTeamSelector(
                      _teamANameController,
                      _teamAPlayers,
                      'TEAM A',
                      'A',
                      _teamBNameController.text,
                      AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: _buildTeamSelector(
                      _teamBNameController,
                      _teamBPlayers,
                      'TEAM B',
                      'B',
                      _teamANameController.text,
                      AppTheme.vibrantOrange,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1B2A) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  'VS',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),
        _buildSectionHeader('QUOTA & RULES', Icons.gavel_rounded, isDark),
        const SizedBox(height: 16),
        _buildAdvancedSettings(isDark),
        const SizedBox(height: 24),
        if (!_customRulesEnabled)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL OVERS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    Text(
                      'Match Duration',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppTheme.primaryDark : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, size: 20),
                        onPressed:
                            _totalOvers > 1
                                ? () => setState(() => _totalOvers--)
                                : null,
                      ),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '$_totalOvers',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 20),
                        onPressed:
                            _totalOvers < 50
                                ? () => setState(() => _totalOvers++)
                                : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String label, IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              'Single Batsman Mode',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Overs calculated based on player quotas',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
            value: _customRulesEnabled,
            activeColor: Colors.white,
            activeTrackColor: AppTheme.primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (val) => setState(() => _customRulesEnabled = val),
          ),
          if (_customRulesEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.vibrantOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.vibrantOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total match overs will be based on players and quotas.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.vibrantOrange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Max Batting Overs',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$_maxBattingOvers Overs',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _maxBattingOvers.toDouble(),
                    min: 1,
                    max: 6,
                    divisions: 5,
                    activeColor: AppTheme.primaryGreen,
                    onChanged:
                        (v) => setState(() => _maxBattingOvers = v.toInt()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Max Bowling Overs',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$_maxBowlingOvers Overs',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _maxBowlingOvers.toDouble(),
                    min: 1,
                    max: 6,
                    divisions: 5,
                    activeColor: AppTheme.primaryGreen,
                    onChanged:
                        (v) => setState(() => _maxBowlingOvers = v.toInt()),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
          SwitchListTile(
            title: Text(
              'Last Player Can Play',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Allows last batsman to play alone',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
            value: _lastPlayerCanPlay,
            activeColor: Colors.white,
            activeTrackColor: AppTheme.primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (val) => setState(() => _lastPlayerCanPlay = val),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSelector(
    TextEditingController nameController,
    List<PlayerModel> teamPlayers,
    String label,
    String teamId,
    String excludeTeamName,
    Color themeColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap:
          () => _showSelectMasterTeamDialog(
            nameController,
            teamPlayers,
            teamId,
            excludeTeamName,
          ),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                nameController.text.isNotEmpty
                    ? themeColor.withOpacity(0.5)
                    : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05)),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  nameController.text.isNotEmpty
                      ? themeColor.withOpacity(0.1)
                      : Colors.transparent,
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_rounded, color: themeColor, size: 24),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                nameController.text.isEmpty ||
                        nameController.text == 'Team A' ||
                        nameController.text == 'Team B'
                    ? 'Select $label'
                    : nameController.text.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color:
                      nameController.text.isEmpty ||
                              nameController.text == 'Team A' ||
                              nameController.text == 'Team B'
                          ? (isDark ? Colors.white24 : Colors.black26)
                          : (isDark ? Colors.white : Colors.black87),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectMasterTeamDialog(
    TextEditingController nameController,
    List<PlayerModel> teamPlayers,
    String teamId,
    String excludeTeamName,
  ) {
    List<TeamModel> availableTeams;

    if (_tournamentId != null) {
      final tournament = tournamentController.tournaments.firstWhere(
        (t) => t.id == _tournamentId,
      );
      availableTeams =
          teamController.teams
              .where(
                (t) =>
                    tournament.teamIds.contains(t.id) &&
                    t.name != excludeTeamName,
              )
              .toList();
    } else {
      availableTeams =
          teamController.teams.where((t) => t.name != excludeTeamName).toList();
    }

    if (availableTeams.isEmpty) {
      Get.snackbar('No Teams', 'No other teams available to select.');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            final searchController = TextEditingController();
            List<TeamModel> filteredTeams = availableTeams;

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SELECT TEAM',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Choose a team to compete',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color:
                                        isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.group_add_rounded,
                              color: AppTheme.primaryGreen,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setInnerState(() {
                            filteredTeams =
                                availableTeams
                                    .where(
                                      (t) => t.name.toLowerCase().contains(
                                        value.toLowerCase(),
                                      ),
                                    )
                                    .toList();
                          });
                        },
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search teams...',
                          hintStyle: GoogleFonts.inter(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                            size: 20,
                          ),
                          filled: true,
                          fillColor:
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: filteredTeams.length,
                        itemBuilder: (context, index) {
                          final team = filteredTeams[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.05),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryGreen,
                                      AppTheme.primaryGreen.withOpacity(0.7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    team.name[0].toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                team.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 14,
                                    color:
                                        isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${team.playerIds.length} players',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color:
                                          isDark
                                              ? Colors.white38
                                              : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              onTap: () {
                                setState(() {
                                  nameController.text = team.name;
                                  if (teamId == 'A') {
                                    _teamAId = team.id;
                                  } else {
                                    _teamBId = team.id;
                                  }
                                  teamPlayers.clear();
                                  for (var uid in team.playerIds) {
                                    try {
                                      final u = _registeredUsers.firstWhere(
                                        (user) => user.uid == uid,
                                      );
                                      teamPlayers.add(
                                        PlayerModel(
                                          id: u.uid,
                                          name: u.name,
                                          role: 'player',
                                          teamId: teamId,
                                          profileImageUrl: u.profileImageUrl,
                                        ),
                                      );
                                    } catch (_) {}
                                  }
                                });
                                Get.back();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Step 2 ────────────────────────────────────────
  Widget _buildPlayersStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SQUAD SELECTION', Icons.groups_rounded, isDark),
        const SizedBox(height: 16),
        _buildTeamSquadCard(
          _teamANameController.text,
          _teamAPlayers,
          _teamBPlayers,
          'A',
          isDark,
        ),
        const SizedBox(height: 16),
        _buildTeamSquadCard(
          _teamBNameController.text,
          _teamBPlayers,
          _teamAPlayers,
          'B',
          isDark,
        ),
        const SizedBox(height: 32),
        _buildSectionHeader('ROLE ASSIGNMENTS', Icons.star_rounded, isDark),
        const SizedBox(height: 16),
        _buildRoleSelector(
          label: 'TEAM A CAPTAIN',
          icon: Icons.person_rounded,
          color: AppTheme.primaryGreen,
          players: _teamAPlayers,
          selectedId: _teamACaptainId,
          onChanged: (id) => setState(() => _teamACaptainId = id),
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildRoleSelector(
          label: 'TEAM B CAPTAIN',
          icon: Icons.person_rounded,
          color: AppTheme.vibrantOrange,
          players: _teamBPlayers,
          selectedId: _teamBCaptainId,
          onChanged: (id) => setState(() => _teamBCaptainId = id),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTeamSquadCard(
    String teamName,
    List<PlayerModel> teamPlayers,
    List<PlayerModel> otherTeamPlayers,
    String teamId,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppTheme.primaryGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  teamName,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${teamPlayers.length} PLAYERS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTeamPickerButton(
            teamName: teamName,
            teamPlayers: teamPlayers,
            otherTeamPlayers: otherTeamPlayers,
            color: AppTheme.primaryGreen,
            isDark: isDark,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ─── Team Player Picker Button ─────────────────────
  Widget _buildTeamPickerButton({
    required String teamName,
    required List<PlayerModel> teamPlayers,
    required List<PlayerModel> otherTeamPlayers,
    required Color color,
    required bool isDark,
    required VoidCallback onChanged,
  }) {
    return GestureDetector(
      onTap:
          () => _showTeamPlayerPicker(
            teamName: teamName,
            teamPlayers: teamPlayers,
            otherTeamPlayers: otherTeamPlayers,
            color: color,
            isDark: isDark,
            onChanged: onChanged,
          ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B263B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(Icons.group, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  teamPlayers.isEmpty
                      ? Text(
                        'Tap to select $teamName players',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$teamName — ${teamPlayers.length} selected',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 28,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: teamPlayers.length,
                              physics: const ClampingScrollPhysics(),
                              separatorBuilder:
                                  (_, __) => const SizedBox(width: 4),
                              itemBuilder: (_, i) {
                                final u = _userForPlayer(teamPlayers[i]);
                                return _buildAvatar(
                                  u,
                                  14,
                                  isSelected: true,
                                  selectedColor: color,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: isDark ? Colors.white38 : Colors.grey[500],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Scorer Picker Button ──────────────────────────
  Widget _buildScorerPickerButton(List<PlayerModel> allPlayers, bool isDark) {
    return GestureDetector(
      onTap: () => _showScorerPicker(allPlayers, isDark),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.scoreboard_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT SCORERS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      Text(
                        'Who will record the scores?',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
            if (_selectedScorerIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _selectedScorerIds.map((id) {
                      final player = allPlayers.firstWhere(
                        (p) => p.id == id,
                        orElse: () => allPlayers.first,
                      );
                      final isMe = id == authController.userId;
                      final user = _userForPlayer(player);

                      return Container(
                        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                        decoration: BoxDecoration(
                          color:
                              isMe
                                  ? AppTheme.primaryGreen.withOpacity(0.15)
                                  : (isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color:
                                isMe
                                    ? AppTheme.primaryGreen.withOpacity(0.3)
                                    : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildAvatar(user, 12, isSelected: isMe),
                            const SizedBox(width: 8),
                            Text(
                              isMe
                                  ? 'You (Scorer)'
                                  : player.name.split(' ').first,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    isMe
                                        ? AppTheme.primaryGreen
                                        : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Bottom Sheet: Team Player Picker ─────────────
  void _showTeamPlayerPicker({
    required String teamName,
    required List<PlayerModel> teamPlayers,
    required List<PlayerModel> otherTeamPlayers,
    required Color color,
    required bool isDark,
    required VoidCallback onChanged,
  }) {
    final otherIds = otherTeamPlayers.map((p) => p.id).toSet();
    final searchCtrl = TextEditingController();
    String query = "";

    FocusScope.of(context).unfocus();

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setInner) {
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder:
                  (_, controller) => Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.group_rounded,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                teamName,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "${teamPlayers.length} selected",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextField(
                              controller: searchCtrl,
                              style: GoogleFonts.inter(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: "Search player...",
                                hintStyle: GoogleFonts.inter(
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                  size: 20,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onChanged:
                                  (v) =>
                                      setInner(() => query = v.toLowerCase()),
                            ),
                          ),
                        ),
                        const Divider(
                          height: 24,
                          thickness: 1,
                          indent: 20,
                          endIndent: 20,
                        ),
                        Expanded(
                          child:
                              _isLoadingUsers
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : ListView.builder(
                                    controller: controller,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    itemCount:
                                        _registeredUsers
                                            .where(
                                              (u) => u.name
                                                  .toLowerCase()
                                                  .contains(query),
                                            )
                                            .length,
                                    itemBuilder: (_, i) {
                                      final filtered =
                                          _registeredUsers
                                              .where(
                                                (u) => u.name
                                                    .toLowerCase()
                                                    .contains(query),
                                              )
                                              .toList();
                                      final u = filtered[i];
                                      final isInOther = otherIds.contains(
                                        u.uid,
                                      );
                                      final isSelected = teamPlayers.any(
                                        (p) => p.id == u.uid,
                                      );

                                      return GestureDetector(
                                        onTap:
                                            isInOther
                                                ? null
                                                : () {
                                                  setInner(() {
                                                    setState(() {
                                                      if (!isSelected) {
                                                        teamPlayers.add(
                                                          PlayerModel(
                                                            id: u.uid,
                                                            name: u.name,
                                                            role: "player",
                                                            teamId: "",
                                                            profileImageUrl:
                                                                u.profileImageUrl,
                                                          ),
                                                        );
                                                      } else {
                                                        teamPlayers.removeWhere(
                                                          (p) => p.id == u.uid,
                                                        );
                                                        _clearRolesForPlayer(
                                                          u.uid,
                                                          teamPlayers,
                                                        );
                                                      }
                                                    });
                                                  });
                                                  onChanged();
                                                },
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? color.withOpacity(
                                                      isDark ? 0.1 : 0.05,
                                                    )
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isSelected
                                                      ? color.withOpacity(0.3)
                                                      : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Stack(
                                                children: [
                                                  _buildAvatar(
                                                    u,
                                                    24,
                                                    isSelected: isSelected,
                                                    selectedColor: color,
                                                  ),
                                                  if (isInOther)
                                                    Positioned(
                                                      right: -2,
                                                      bottom: -2,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color:
                                                                isDark
                                                                    ? const Color(
                                                                      0xFF0F172A,
                                                                    )
                                                                    : Colors
                                                                        .white,
                                                            width: 2,
                                                          ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.block_rounded,
                                                          size: 10,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      u.name,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            isSelected
                                                                ? FontWeight
                                                                    .w700
                                                                : FontWeight
                                                                    .w600,
                                                        color:
                                                            isInOther
                                                                ? (isDark
                                                                    ? Colors
                                                                        .white24
                                                                    : Colors
                                                                        .black26)
                                                                : (isDark
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .black87),
                                                      ),
                                                    ),
                                                    if (isInOther)
                                                      Text(
                                                        "In other team",
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              Colors.redAccent,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                width: 26,
                                                height: 26,
                                                decoration: BoxDecoration(
                                                  color:
                                                      isSelected
                                                          ? AppTheme
                                                              .primaryGreen
                                                          : Colors.transparent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        isSelected
                                                            ? AppTheme
                                                                .primaryGreen
                                                            : (isDark
                                                                ? Colors.white12
                                                                : Colors
                                                                    .black12),
                                                    width: 2,
                                                  ),
                                                ),
                                                child:
                                                    isSelected
                                                        ? const Icon(
                                                          Icons.check,
                                                          color: Colors.white,
                                                          size: 16,
                                                        )
                                                        : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Get.back(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                "Done (${teamPlayers.length} selected)",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          );
        },
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 400),
      exitBottomSheetDuration: const Duration(milliseconds: 300),
    );
  }

  void _clearRolesForPlayer(String uid, List<PlayerModel> teamPlayers) {
    // Clear captain if player removed
    if (_teamACaptainId == uid) _teamACaptainId = null;
    if (_teamBCaptainId == uid) _teamBCaptainId = null;
    _selectedScorerIds.remove(uid);
  }

  // ─── Bottom Sheet: Scorer Picker ───────────────────
  void _showScorerPicker(List<PlayerModel> players, bool isDark) {
    final searchCtrl = TextEditingController();

    FocusScope.of(context).unfocus();

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setInner) {
          final query = searchCtrl.text.toLowerCase();
          final filtered =
              players
                  .where((p) => p.name.toLowerCase().contains(query))
                  .toList();
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder:
                  (_, controller) => Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.scoreboard_rounded,
                                  color: AppTheme.primaryGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "SELECT SCORERS",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "${_selectedScorerIds.length} assigned",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextField(
                              controller: searchCtrl,
                              style: GoogleFonts.inter(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: "Search for a scorer...",
                                hintStyle: GoogleFonts.inter(
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                  size: 20,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (v) => setInner(() {}),
                            ),
                          ),
                        ),
                        const Divider(
                          height: 24,
                          thickness: 1,
                          indent: 20,
                          endIndent: 20,
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: controller,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final p = filtered[i];
                              final user = _userForPlayer(p);
                              final isSelected = _selectedScorerIds.contains(
                                p.id,
                              );
                              final isMe = p.id == authController.userId;

                              return GestureDetector(
                                onTap: () {
                                  setInner(() {
                                    setState(() {
                                      if (isSelected) {
                                        if (_selectedScorerIds.length > 1) {
                                          _selectedScorerIds.remove(p.id);
                                        } else {
                                          UIUtils.showError(
                                            "At least one scorer required",
                                          );
                                        }
                                      } else {
                                        _selectedScorerIds.add(p.id);
                                      }
                                    });
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? AppTheme.primaryGreen.withOpacity(
                                              isDark ? 0.1 : 0.05,
                                            )
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? AppTheme.primaryGreen
                                                  .withOpacity(0.3)
                                              : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          _buildAvatar(
                                            user,
                                            24,
                                            isSelected: isSelected,
                                          ),
                                          if (isMe)
                                            Positioned(
                                              right: -2,
                                              bottom: -2,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryGreen,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        isDark
                                                            ? const Color(
                                                              0xFF0F172A,
                                                            )
                                                            : Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  size: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isMe ? "You (Scorer)" : p.name,
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight:
                                                    isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w600,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color:
                                              isSelected
                                                  ? AppTheme.primaryGreen
                                                  : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                isSelected
                                                    ? AppTheme.primaryGreen
                                                    : (isDark
                                                        ? Colors.white12
                                                        : Colors.black12),
                                            width: 2,
                                          ),
                                        ),
                                        child:
                                            isSelected
                                                ? const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 16,
                                                )
                                                : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Get.back(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                "Done (${_selectedScorerIds.length} selected)",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          );
        },
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 400),
      exitBottomSheetDuration: const Duration(milliseconds: 300),
    );
  }

  void _showRolePicker({
    required String label,
    required IconData icon,
    required Color color,
    required List<PlayerModel> players,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    FocusScope.of(context).unfocus();

    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: AppTheme.primaryGreen, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      'Select $label',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 24,
                thickness: 1,
                indent: 20,
                endIndent: 20,
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    _buildRoleItem(
                      title: 'None (Optional)',
                      isSelected: selectedId == null,
                      isNone: true,
                      isDark: isDark,
                      onTap: () {
                        onChanged(null);
                        Get.back();
                        setState(() {});
                      },
                    ),
                    ...players.map((p) {
                      final user = _userForPlayer(p);
                      final isSelected = selectedId == p.id;
                      return _buildRoleItem(
                        title: p.name,
                        isSelected: isSelected,
                        user: user,
                        isDark: isDark,
                        onTap: () {
                          onChanged(p.id);
                          Get.back();
                          setState(() {});
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 400),
      exitBottomSheetDuration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildRoleItem({
    required String title,
    required bool isSelected,
    bool isNone = false,
    AppUser? user,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.primaryGreen.withOpacity(isDark ? 0.1 : 0.05)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected
                    ? AppTheme.primaryGreen.withOpacity(0.3)
                    : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            if (isNone)
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    isDark
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF1F5F9),
                child: Icon(
                  Icons.person_off_rounded,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              )
            else
              _buildAvatar(user, 24, isSelected: isSelected),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color:
                      isNone
                          ? (isDark ? Colors.white38 : Colors.black38)
                          : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Role Selector Row ─────────────────────────────
  Widget _buildRoleSelector({
    required String label,
    required IconData icon,
    required Color color,
    required List<PlayerModel> players,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final selected =
        selectedId != null
            ? players.firstWhere(
              (p) => p.id == selectedId,
              orElse: () => players.first,
            )
            : null;
    final selectedUser = selected != null ? _userForPlayer(selected) : null;

    return GestureDetector(
      onTap:
          () => _showRolePicker(
            label: label,
            icon: icon,
            color: color,
            players: players,
            selectedId: selectedId,
            onChanged: onChanged,
            isDark: isDark,
          ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B263B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const Spacer(),
            if (selected != null) ...[
              _buildAvatar(
                selectedUser,
                16,
                isSelected: true,
                selectedColor: color,
              ),
              const SizedBox(width: 6),
              Text(
                selected.name.split(' ').first,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
            ] else
              Text(
                'Optional',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
              ),
            Icon(
              Icons.keyboard_arrow_down,
              color: isDark ? Colors.white38 : Colors.grey[500],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentSelector(bool isDark) {
    final selectedTournament = tournamentController.tournaments
        .firstWhereOrNull((t) => t.id == _tournamentId);

    return GestureDetector(
      onTap: () => _showTournamentSelectionSheet(isDark),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                _tournamentId != null
                    ? AppTheme.primaryGreen.withOpacity(0.5)
                    : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05)),
            width: 2,
          ),
          boxShadow: [
            if (_tournamentId != null)
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color:
                    _tournamentId != null ? AppTheme.primaryGreen : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TOURNAMENT",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedTournament?.name ?? "Select Tournament",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: selectedTournament != null ? null : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  void _showTournamentSelectionSheet(bool isDark) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "SELECT TOURNAMENT",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: Obx(() {
                final tournaments = tournamentController.tournaments;

                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    _buildSelectionItem(
                      icon: Icons.not_interested_rounded,
                      title: "None (Single Match)",
                      subtitle: "Simple friendly or local match",
                      isSelected: _tournamentId == null,
                      onTap: () {
                        setState(() {
                          _tournamentId = null;
                          _titleController.text = "";
                          _teamANameController.clear();
                          _teamBNameController.clear();
                        });
                        Get.back();
                      },
                      isDark: isDark,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    ...tournaments.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSelectionItem(
                          icon: Icons.emoji_events_rounded,
                          title: t.name,
                          subtitle:
                              "${t.type.capitalizeFirst} 267 ${t.teamIds.length} Teams",
                          isSelected: _tournamentId == t.id,
                          onTap: () {
                            setState(() {
                              _tournamentId = t.id;
                              tournamentController.listenToTournament(t.id);
                              final matchCount =
                                  tournamentController.tournamentMatches.length;
                              _titleController.text = "Match ${matchCount + 1}";
                            });
                            Get.back();
                          },
                          isDark: isDark,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildTournamentInfo(bool isDark) {
    final tournament = tournamentController.tournaments.firstWhereOrNull(
      (t) => t.id == _tournamentId,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [
                    AppTheme.primaryGreen.withOpacity(0.15),
                    AppTheme.primaryGreen.withOpacity(0.05),
                  ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : AppTheme.primaryGreen.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppTheme.primaryGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament?.name ?? "Tournament",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  tournament?.type.toUpperCase() ?? "FORMAT",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? color.withOpacity(0.1)
                  : (isDark
                      ? Colors.white.withOpacity(0.02)
                      : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? color.withOpacity(0.5)
                    : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade200),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isSelected ? color : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentScheduleView(bool isDark, TournamentModel tournament) {
    final matches = tournamentController.tournamentMatches.toList();
    matches.sort((a, b) => (a.matchNumber ?? 0).compareTo(b.matchNumber ?? 0));

    final liveMatch = matches.firstWhereOrNull((m) => m.status == 'live');
    final nextMatch = tournamentController.nextMatchToPlay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(
              'FIXTURES',
              Icons.calendar_month_rounded,
              isDark,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${matches.where((m) => m.isCompleted).length}/${matches.length} COMPLETED',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (liveMatch == null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isAddingManualFixture = true),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: Text(
                'CREATE NEW FIXTURE',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark
                        ? AppTheme.primaryGreen.withOpacity(0.1)
                        : AppTheme.primaryGreen,
                foregroundColor: isDark ? AppTheme.primaryGreen : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side:
                      isDark
                          ? BorderSide(
                            color: AppTheme.primaryGreen.withOpacity(0.3),
                          )
                          : BorderSide.none,
                ),
                elevation: isDark ? 0 : 4,
                shadowColor: AppTheme.primaryGreen.withOpacity(0.4),
              ),
            ),
          ),

        if (matches.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 48,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No fixtures created yet',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final match = matches[index];
              final isUnlocked =
                  match.status == 'live' || match.id == nextMatch?.id;
              final isCompleted = match.isCompleted;
              final isLive = match.status == 'live';

              return _buildFixtureCard(
                match,
                index,
                isUnlocked,
                isLive,
                isCompleted,
                isDark,
              );
            },
          ),
      ],
    );
  }

  Widget _buildAddTournamentMatchForm(bool isDark, TournamentModel tournament) {
    final teamIds = tournament.teamIds;
    final teamNames = tournament.teamNames;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CREATE NEW FIXTURE',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Container(
                    height: 3,
                    width: 40,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => setState(() => _isAddingManualFixture = false),
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Match Title
          TextFormField(
            controller: _manualTitleController,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Match Title',
              labelStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
              hintText: 'e.g. Qualifier 1, Semi Final',
              hintStyle: GoogleFonts.inter(
                color: Colors.grey.withOpacity(0.5),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.title_rounded,
                color: AppTheme.primaryGreen.withOpacity(0.7),
              ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Team Selection Row
          Row(
            children: [
              Expanded(
                child: _buildFixturesDropdown(
                  value: _manualTeamAId,
                  label: 'TEAM A',
                  teamEntries: teamIds.asMap().entries.toList(),
                  otherTeamId: _manualTeamBId,
                  allTeamIds: teamNames,
                  onChanged: (v) {
                    setState(() => _manualTeamAId = v);
                    if (v != null && _manualTeamBId != null) {
                      _autoPopulateSquadsForTeams(v, _manualTeamBId!);
                    }
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFixturesDropdown(
                  value: _manualTeamBId,
                  label: 'TEAM B',
                  teamEntries: teamIds.asMap().entries.toList(),
                  otherTeamId: _manualTeamAId,
                  allTeamIds: teamNames,
                  onChanged: (v) {
                    setState(() => _manualTeamBId = v);
                    if (v != null && _manualTeamAId != null) {
                      _autoPopulateSquadsForTeams(_manualTeamAId!, v);
                    }
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _saveManualFixture(tournament),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'SAVE FIXTURE',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixturesDropdown({
    required String? value,
    required String label,
    required List<MapEntry<int, String>> teamEntries,
    required String? otherTeamId,
    required List<String> allTeamIds,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items:
          teamEntries
              .where((e) => e.value != otherTeamId)
              .map(
                (e) => DropdownMenuItem(
                  value: e.value,
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryGreen.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            allTeamIds[e.key].substring(0, 1).toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          allTeamIds[e.key], // Display name
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
      onChanged: onChanged,
      selectedItemBuilder: (context) {
        return teamEntries.where((e) => e.value != otherTeamId).map((e) {
          return Row(
            children: [
              Icon(
                Icons.group_rounded,
                size: 14,
                color: AppTheme.primaryGreen.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  allTeamIds[e.key],
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          );
        }).toList();
      },
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black87,
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppTheme.primaryGreen,
        size: 20,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      isExpanded: true,
      menuMaxHeight: 300,
    );
  }

  Widget _buildDateTimePickerCard({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.02),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: AppTheme.primaryGreen),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveManualFixture(TournamentModel tournament) async {
    if (_manualTeamAId == null || _manualTeamBId == null) {
      UIUtils.showError('Please select both teams');
      return;
    }
    if (_manualTeamAId == _manualTeamBId) {
      UIUtils.showError('Team A and Team B cannot be the same');
      return;
    }

    final teamAIdx = tournament.teamIds.indexOf(_manualTeamAId!);
    final teamBIdx = tournament.teamIds.indexOf(_manualTeamBId!);

    final matchDate = DateTime.now();

    // Create fixture as an upcoming match
    final matchId = _uuid.v4();
    final match = MatchModel(
      id: matchId,
      title: 'Match ${tournamentController.tournamentMatches.length + 1}',
      createdBy: authController.userId!,
      tournamentId: tournament.id,
      tournamentName: tournament.name,
      teamAId: _manualTeamAId,
      teamBId: _manualTeamBId,
      teamAName: tournament.teamNames[teamAIdx],
      teamBName: tournament.teamNames[teamBIdx],
      status: 'upcoming',
      totalOvers: _totalOvers,
      scorerIds: [authController.userId!],
      matchNumber: tournamentController.tournamentMatches.length + 1,
      round: _round,
      createdAt: DateTime.now(),
      teamAPlayers: [],
      teamBPlayers: [],
    );

    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.matchesCollection)
          .doc(matchId)
          .set(match.toFirestore());

      UIUtils.showSuccess('Fixture created successfully!');
      setState(() {
        _isAddingManualFixture = false;
        _manualTeamAId = null;
        _manualTeamBId = null;
        _manualTitleController.clear();
      });
    } catch (e) {
      UIUtils.showError('Error saving fixture: $e');
    }
  }

  Widget _buildFixtureCard(
    MatchModel match,
    int index,
    bool isUnlocked,
    bool isLive,
    bool isCompleted,
    bool isDark,
  ) {
    final Color borderColor =
        isLive
            ? AppTheme.primaryGreen
            : (isUnlocked
                ? AppTheme.primaryGreen.withOpacity(0.3)
                : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isLive ? 2 : 1),
        boxShadow:
            isLive
                ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
                : [],
      ),
      child: Opacity(
        opacity: isUnlocked || isCompleted ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isLive
                              ? AppTheme.primaryGreen
                              : (isCompleted
                                  ? Colors.grey
                                  : AppTheme.accentPurple))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'MATCH ${match.matchNumber ?? (index + 1)} • ${match.round?.toUpperCase() ?? "LEAGUE"}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color:
                            isLive
                                ? AppTheme.primaryGreen
                                : (isCompleted
                                    ? Colors.grey
                                    : AppTheme.accentPurple),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (isLive)
                    _buildLiveBadge()
                  else if (isCompleted)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryGreen,
                      size: 18,
                    )
                  else if (!isUnlocked)
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.grey,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildFixtureTeam(match.teamAName, isDark)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'VS',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildFixtureTeam(
                      match.teamBName,
                      isDark,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Sequential Flow Message
              if (!tournamentController.canStartMatch(match) &&
                  !isCompleted &&
                  !isLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_clock_rounded,
                        size: 14,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tournamentController.hasLiveMatch(_tournamentId ?? '')
                              ? 'Another match is currently live'
                              : 'Complete previous match to unlock',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (tournamentController.canStartMatch(match) &&
                  !isLive &&
                  !isCompleted) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _startScheduledMatch(match),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('START MATCH'),
                  ),
                ),
              ],
              if (isLive) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed:
                        () =>
                            Get.toNamed(AppRoutes.scoring, arguments: match.id),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'CONTINUE SCORING',
                      style: TextStyle(color: AppTheme.primaryGreen),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.wicketRed,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixtureTeam(
    String name,
    bool isDark, {
    TextAlign textAlign = TextAlign.start,
  }) {
    return Text(
      name,
      textAlign: textAlign,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black87,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _startScheduledMatch(MatchModel match) {
    setState(() {
      _scheduledMatchId = match.id;
      _titleController.text = match.title;
      _teamANameController.text = match.teamAName;
      _teamBNameController.text = match.teamBName;
      _teamAId = match.teamAId;
      _teamBId = match.teamBId;
      _round = match.round;

      // Carry forward rules if they exist in the scheduled match
      if (match.totalOvers > 0) _totalOvers = match.totalOvers;
      _customRulesEnabled = match.customRulesEnabled;

      // If tournament is present, prioritize tournament's lastPlayerCanPlay rule
      final tournament = tournamentController.selectedTournament;
      if (tournament != null && tournament.id == match.tournamentId) {
        _lastPlayerCanPlay = tournament.lastPlayerCanPlay;
        print(
          "DEBUG: Match Resume - Prioritizing Tournament Flag: $_lastPlayerCanPlay",
        );
      } else {
        _lastPlayerCanPlay = match.lastPlayerCanPlay;
      }
      if (match.maxBattingOvers != null) {
        _maxBattingOvers = match.maxBattingOvers!;
      }
      if (match.maxBowlingOvers != null) {
        _maxBowlingOvers = match.maxBowlingOvers!;
      }

      // Jump to squads step
      _currentStep = 1;
    });

    if (_teamAId != null && _teamBId != null) {
      _autoPopulateSquadsForTeams(_teamAId!, _teamBId!);
    }
  }

  void _applyTournamentRules(TournamentModel tournament) {
    setState(() {
      _totalOvers = tournament.defaultOvers;
      _ballsPerOver = tournament.ballsPerOver;
      _customRulesEnabled = tournament.customRulesEnabled;
      _lastPlayerCanPlay = tournament.lastPlayerCanPlay;
      _maxBattingOvers = tournament.maxBattingOvers ?? _maxBattingOvers;
      _maxBowlingOvers = tournament.maxBowlingOvers ?? _maxBowlingOvers;

      print(
        "DEBUG: Applied Tournament Rules - LastPlayerCanPlay: $_lastPlayerCanPlay",
      );
    });
  }

  void _applyPreviousMatchSettings(String tournamentId) {
    // 1. First, apply global tournament rules if available
    final tournament = tournamentController.selectedTournament;
    if (tournament != null && tournament.id == tournamentId) {
      _applyTournamentRules(tournament);
    }

    // 2. Then, check for the most recent completed match in this tournament to copy settings
    // (In case the user changed rules in a previous match and wants to continue that pattern,
    // though the requirement says Tournament rules = global rules).
    // For now, tournament defaults are the primary source.
    final matches = tournamentController.tournamentMatches;
    if (matches.isEmpty) return;

    // Sort by creation date to get the latest one
    final completedMatches =
        matches.where((m) => m.isCompleted).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (completedMatches.isNotEmpty) {
      final prevMatch = completedMatches.first;
      setState(() {
        _totalOvers = prevMatch.totalOvers;
        _ballsPerOver = prevMatch.ballsPerOver;
        _customRulesEnabled = prevMatch.customRulesEnabled;

        // If tournament is present, prioritize tournament's lastPlayerCanPlay rule
        final tournament = tournamentController.selectedTournament;
        if (tournament != null && tournament.id == tournamentId) {
          _lastPlayerCanPlay = tournament.lastPlayerCanPlay;
          print(
            "DEBUG: Prev Match Load - Prioritizing Tournament Flag: $_lastPlayerCanPlay",
          );
        } else {
          _lastPlayerCanPlay = prevMatch.lastPlayerCanPlay;
        }

        _maxBattingOvers = prevMatch.maxBattingOvers ?? _maxBattingOvers;
        _maxBowlingOvers = prevMatch.maxBowlingOvers ?? _maxBowlingOvers;
      });
    }
  }

  Future<void> _loadAndStartScheduledMatch(String matchId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection(AppConstants.matchesCollection)
              .doc(matchId)
              .get();
      if (doc.exists) {
        final match = MatchModel.fromFirestore(doc);
        _startScheduledMatch(match);
      }
    } catch (e) {
      print('Error loading scheduled match: $e');
    }
  }

  Future<List<PlayerModel>> _fetchPlayersByIds(List<String> ids) async {
    // Optimization: Use locally loaded _registeredUsers if available
    if (_registeredUsers.isNotEmpty) {
      final List<PlayerModel> players = [];
      for (final id in ids) {
        final user = _registeredUsers.firstWhereOrNull((u) => u.uid == id);
        if (user != null) {
          players.add(
            PlayerModel(
              id: user.uid,
              name: user.name,
              role: 'player',
              teamId: '', // Will be set later
              profileImageUrl: user.profileImageUrl,
            ),
          );
        }
      }
      if (players.isNotEmpty) return players;
    }

    // Fallback: Batch fetch from Firestore if not in local list (max 30 ids for whereIn)
    final List<PlayerModel> players = [];
    if (ids.isEmpty) return players;

    try {
      // Chunk IDs into groups of 30 due to Firestore's 'whereIn' limit
      for (var i = 0; i < ids.length; i += 30) {
        final end = (i + 30 < ids.length) ? i + 30 : ids.length;
        final chunk = ids.sublist(i, end);

        final snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();

        for (final doc in snapshot.docs) {
          players.add(PlayerModel.fromFirestore(doc));
        }
      }
    } catch (e) {
      print('Error batch fetching players: $e');
    }

    return players;
  }

  Future<void> _autoPopulateSquadsForTeams(
    String teamAId,
    String teamBId,
  ) async {
    final teamController = Get.find<TeamController>();
    final teamA = teamController.teams.firstWhereOrNull((t) => t.id == teamAId);
    final teamB = teamController.teams.firstWhereOrNull((t) => t.id == teamBId);

    if (teamA == null || teamB == null) return;

    setState(() => _isLoadingUsers = true);

    try {
      // Load both teams in parallel for speed
      final results = await Future.wait([
        _fetchPlayersByIds(teamA.playerIds),
        _fetchPlayersByIds(teamB.playerIds),
      ]);

      final teamAPlayers = results[0];
      final teamBPlayers = results[1];

      setState(() {
        _teamAPlayers.clear();
        _teamAPlayers.addAll(teamAPlayers);
        _teamBPlayers.clear();
        _teamBPlayers.addAll(teamBPlayers);

        // Auto-select captains if available
        if (teamAPlayers.isNotEmpty) _teamACaptainId = teamAPlayers.first.id;
        if (teamBPlayers.isNotEmpty) _teamBCaptainId = teamBPlayers.first.id;
      });
    } catch (e) {
      print('Error auto-populating squads: $e');
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  Widget _buildRoundSelector(bool isDark) {
    final rounds = ['League', 'Knockout', 'Final'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Match Round',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ),
        Row(
          children:
              rounds
                  .map(
                    (r) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(r),
                          selected: _round == r,
                          onSelected: (val) {
                            if (val) setState(() => _round = r);
                          },
                          selectedColor: AppTheme.primaryGreen,
                          labelStyle: GoogleFonts.inter(
                            color:
                                _round == r
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black87),
                            fontWeight:
                                _round == r
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  // ─── Avatar Helper ─────────────────────────────────
  Widget _buildAvatar(
    AppUser? user,
    double radius, {
    bool isSelected = false,
    Color? selectedColor,
  }) {
    final name = user?.name ?? '?';
    final imageUrl = user?.profileImageUrl;
    final bgColor =
        isSelected
            ? (selectedColor ?? AppTheme.primaryGreen)
            : Colors.grey[400]!;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      backgroundImage:
          imageUrl != null && imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : null,
      child:
          imageUrl == null || imageUrl.isEmpty
              ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: radius * 0.85,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
              : null,
    );
  }

  // ─── Divider ───────────────────────────────────────
  Widget _buildDivider(String label, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
          ),
        ),
      ],
    );
  }

  // ─── Step 3: Toss & Scorers ────────────────────────
  Widget _buildTossStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('TOSS DECISION', Icons.toll_rounded, isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WHO WON THE TOSS?',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceCard(
                      label: _teamANameController.text,
                      isSelected: _tossWonBy == 'A',
                      onTap: () => setState(() => _tossWonBy = 'A'),
                      isDark: isDark,
                      activeColor: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChoiceCard(
                      label: _teamBNameController.text,
                      isSelected: _tossWonBy == 'B',
                      onTap: () => setState(() => _tossWonBy = 'B'),
                      isDark: isDark,
                      activeColor: AppTheme.vibrantOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'ELECTED TO?',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceCard(
                      label: 'BAT',
                      isSelected: _tossDecision == 'bat',
                      onTap: () => setState(() => _tossDecision = 'bat'),
                      isDark: isDark,
                      activeColor: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChoiceCard(
                      label: 'BOWL',
                      isSelected: _tossDecision == 'bowl',
                      onTap: () => setState(() => _tossDecision = 'bowl'),
                      isDark: isDark,
                      activeColor: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSectionHeader(
          'OFFICIALS & SCORERS',
          Icons.scoreboard_rounded,
          isDark,
        ),
        const SizedBox(height: 16),
        _buildScorerPickerButton(
          _registeredUsers
              .map(
                (u) => PlayerModel(
                  id: u.uid,
                  name: u.name,
                  role: 'player',
                  teamId: '',
                  profileImageUrl: u.profileImageUrl,
                ),
              )
              .toList(),
          isDark,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'By default, you are selected as the scorer.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceCard({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? activeColor
                  : (isDark ? AppTheme.primaryDark : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : [],
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color:
                  isSelected
                      ? Colors.white
                      : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Navigation ────────────────────────────────────
  void _onStepContinue() {
    switch (_currentStep) {
      case 0:
        if (_titleController.text.trim().isEmpty) {
          UIUtils.showError('Please enter a match title');
          return;
        }
        if (_teamANameController.text.trim().isEmpty ||
            _teamANameController.text == 'TEAM A') {
          UIUtils.showError('Please select Team A');
          return;
        }
        if (_teamBNameController.text.trim().isEmpty ||
            _teamBNameController.text == 'TEAM B') {
          UIUtils.showError('Please select Team B');
          return;
        }
        break;
      case 1:
        if (_teamAPlayers.isEmpty || _teamBPlayers.isEmpty) {
          UIUtils.showError('Add at least 1 player to each team');
          return;
        }
        break;
      case 2:
        if (_selectedScorerIds.isEmpty) {
          UIUtils.showError('Select at least one scorer');
          return;
        }
        _createMatch();
        return;
    }
    setState(() => _currentStep++);
  }

  Future<void> _createMatch() async {
    if (_isCreatingMatch) return;

    setState(() => _isCreatingMatch = true);

    try {
      final matchId = await matchController.createMatch(
        title: _titleController.text.trim(),
        createdBy: authController.userId,
        totalOvers:
            _customRulesEnabled
                ? (_teamAPlayers.length > _teamBPlayers.length
                        ? _teamAPlayers.length
                        : _teamBPlayers.length) *
                    _maxBattingOvers
                : _totalOvers,
        teamAName: _teamANameController.text.trim(),
        teamBName: _teamBNameController.text.trim(),
        groundName: '', // Ground name removed as per requirement
        teamAPlayers: _teamAPlayers,
        teamBPlayers: _teamBPlayers,
        scorerIds: _selectedScorerIds,
        tossWonBy: _tossWonBy,
        tossDecision: _tossDecision,
        teamACaptainId: _teamACaptainId,
        teamAViceCaptainId: null, // VC removed
        teamBCaptainId: _teamBCaptainId,
        teamBViceCaptainId: null, // VC removed
        customRulesEnabled: _customRulesEnabled,
        lastPlayerCanPlay: _lastPlayerCanPlay,
        maxBattingOvers: _customRulesEnabled ? _maxBattingOvers : null,
        maxBowlingOvers: _customRulesEnabled ? _maxBowlingOvers : null,
        tournamentId: _tournamentId,
        tournamentName: tournamentController.selectedTournament?.name,
        round: _tournamentId != null ? _round : null,
        teamAId: _teamAId,
        teamBId: _teamBId,
        existingMatchId: _scheduledMatchId,
        matchNumber:
            _tournamentId != null
                ? tournamentController.tournamentMatches.length + 1
                : null,
        ballsPerOver: _ballsPerOver,
      );

      if (matchId != null) {
        UIUtils.showSuccess('Match created successfully!');

        // Clear selections for next time
        _teamAPlayers.clear();
        _teamBPlayers.clear();
        _selectedScorerIds.clear();

        // Navigate to Scoring Screen
        Get.offNamed(AppRoutes.scoring, arguments: matchId);
      }
    } catch (e) {
      UIUtils.showError('Failed to create match: $e');
    } finally {
      if (mounted) {
        setState(() => _isCreatingMatch = false);
      }
    }
  }
}
