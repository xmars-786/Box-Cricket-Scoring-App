import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/player_model.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/controllers/rules_controller.dart';
import '../../../core/controllers/team_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_utils.dart';

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
  final TeamController teamController = Get.put(TeamController());

  // Form fields
  final _titleController = TextEditingController();
  final _teamANameController = TextEditingController();
  final _teamBNameController = TextEditingController();
  final _groundNameController = TextEditingController();
  int _totalOvers = 6;
  String? _teamACaptainId;
  String? _teamAViceCaptainId;
  String? _teamBCaptainId;
  String? _teamBViceCaptainId;
  String _tossWonBy = 'A';
  String _tossDecision = 'bat';
  bool _lastPlayerCanPlay = false;

  // Players
  final List<PlayerModel> _teamAPlayers = [];
  final List<PlayerModel> _teamBPlayers = [];

  // Registered users from DB
  List<AppUser> _registeredUsers = [];
  bool _isLoadingUsers = true;

  // Scorers
  final List<String> _selectedScorerIds = [];

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _lastPlayerCanPlay = rulesController.lastPlayerCanPlay.value;
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
    _groundNameController.dispose();
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
      appBar: AppBar(
        title: Text(
          'Create Match',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          controlsBuilder:
              (context, details) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _currentStep == 2 ? 'Create Match' : 'Continue',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    ],
                  ],
                ),
              ),
          steps: [
            Step(
              title: Text(
                'Match Details',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Title, teams, overs'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildMatchDetailsStep(isDark),
            ),
            Step(
              title: Text(
                'Players & Roles',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${_teamAPlayers.length + _teamBPlayers.length} players',
              ),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildPlayersStep(isDark),
            ),
            Step(
              title: Text(
                'Toss & Settings',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Toss details'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: _buildTossStep(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 1 ────────────────────────────────────────
  Widget _buildMatchDetailsStep(bool isDark) {
    return Column(
      children: [
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Match Title',
            prefixIcon: Icon(Icons.title),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Enter match title' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _groundNameController,
          decoration: const InputDecoration(
            hintText: 'Ground Name (optional)',
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        const SizedBox(height: 16),
        _buildTeamSelector(
          _teamANameController,
          _teamAPlayers,
          'Team A Name',
          'A',
          _teamBNameController.text,
        ),
        const SizedBox(height: 16),
        _buildTeamSelector(
          _teamBNameController,
          _teamBPlayers,
          'Team B Name',
          'B',
          _teamANameController.text,
        ),
        const SizedBox(height: 20),
        Obx(() {
          final customOn = rulesController.customRulesEnabled.value;
          if (customOn) {
            // Show read-only info banner
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFFFF6B35),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Custom Rules active — Match ends when all players complete their quotas.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF6B35),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // Normal overs stepper
          return Row(
            children: [
              Text(
                'Total Overs:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF253750)
                          : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed:
                          _totalOvers > 1
                              ? () => setState(() => _totalOvers--)
                              : null,
                    ),
                    SizedBox(
                      width: 48,
                      child: Center(
                        child: Text(
                          '$_totalOvers',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed:
                          _totalOvers < 20
                              ? () => setState(() => _totalOvers++)
                              : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTeamSelector(
    TextEditingController nameController,
    List<PlayerModel> teamPlayers,
    String label,
    String teamId,
    String excludeTeamName,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ),
        GestureDetector(
          onTap:
              () => _showSelectMasterTeamDialog(
                nameController,
                teamPlayers,
                teamId,
                excludeTeamName,
              ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B263B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.group, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nameController.text.isEmpty ||
                            nameController.text == 'Team A' ||
                            nameController.text == 'Team B'
                        ? 'Select $label'
                        : nameController.text,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color:
                          nameController.text.isEmpty ||
                                  nameController.text == 'Team A' ||
                                  nameController.text == 'Team B'
                              ? (isDark ? Colors.white38 : Colors.grey[500])
                              : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.grey[500],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSelectMasterTeamDialog(
    TextEditingController nameController,
    List<PlayerModel> teamPlayers,
    String teamId,
    String excludeTeamName,
  ) {
    final availableTeams =
        teamController.teams.where((t) => t.name != excludeTeamName).toList();

    if (availableTeams.isEmpty) {
      Get.snackbar('No Teams', 'No other teams available to select.');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.group,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Select Team',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableTeams.length,
                itemBuilder: (context, index) {
                  final team = availableTeams[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                      child: const Icon(
                        Icons.group,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      team.name,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${team.playerIds.length} players',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        nameController.text = team.name;
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
                      Navigator.pop(ctx);
                      // Get.snackbar(
                      //   'Team Loaded',
                      //   '${team.name} loaded with ${teamPlayers.length} players',
                      //   backgroundColor: AppTheme.primaryGreen,
                      //   colorText: Colors.white,
                      // );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // ─── Step 2 ────────────────────────────────────────
  Widget _buildPlayersStep(bool isDark) {
    final allPlayers = [..._teamAPlayers, ..._teamBPlayers];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Team A player picker ──
        _buildTeamPickerButton(
          teamName: _teamANameController.text,
          teamPlayers: _teamAPlayers,
          otherTeamPlayers: _teamBPlayers,
          color: AppTheme.primaryGreen,
          isDark: isDark,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),

        // ── Team B player picker ──
        _buildTeamPickerButton(
          teamName: _teamBNameController.text,
          teamPlayers: _teamBPlayers,
          otherTeamPlayers: _teamAPlayers,
          color: const Color(0xFF64B5F6),
          isDark: isDark,
          onChanged: () => setState(() {}),
        ),

        // ── Roles section ──
        if (allPlayers.isNotEmpty) ...[
          const SizedBox(height: 20),

          // Team A Roles
          if (_teamAPlayers.isNotEmpty) ...[
            _buildDivider(_teamANameController.text, isDark),
            const SizedBox(height: 10),
            _buildRoleSelector(
              label: 'Captain',
              icon: Icons.star_rounded,
              color: const Color(0xFFFFB800),
              players: _teamAPlayers,
              selectedId: _teamACaptainId,
              onChanged: (val) => setState(() => _teamACaptainId = val),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildRoleSelector(
              label: 'Vice Captain',
              icon: Icons.star_half_rounded,
              color: const Color(0xFF64B5F6),
              players: _teamAPlayers,
              selectedId: _teamAViceCaptainId,
              onChanged: (val) => setState(() => _teamAViceCaptainId = val),
              isDark: isDark,
            ),
          ],

          const SizedBox(height: 14),

          // Team B Roles
          if (_teamBPlayers.isNotEmpty) ...[
            _buildDivider(_teamBNameController.text, isDark),
            const SizedBox(height: 10),
            _buildRoleSelector(
              label: 'Captain',
              icon: Icons.star_rounded,
              color: const Color(0xFFFFB800),
              players: _teamBPlayers,
              selectedId: _teamBCaptainId,
              onChanged: (val) => setState(() => _teamBCaptainId = val),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildRoleSelector(
              label: 'Vice Captain',
              icon: Icons.star_half_rounded,
              color: const Color(0xFF64B5F6),
              players: _teamBPlayers,
              selectedId: _teamBViceCaptainId,
              onChanged: (val) => setState(() => _teamBViceCaptainId = val),
              isDark: isDark,
            ),
          ],

          const SizedBox(height: 20),

          // Scorers
          _buildDivider('Scorers', isDark),
          const SizedBox(height: 10),
          _buildScorerPickerButton(
            _registeredUsers.map((u) {
              return PlayerModel(
                id: u.uid,
                name: u.name,
                role: 'player', // Default role for picker
                teamId: '', // No team yet
                profileImageUrl: u.profileImageUrl,
              );
            }).toList(),
            isDark,
          ),
        ],
      ],
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
            Icon(
              Icons.scoreboard_outlined,
              color: AppTheme.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  _selectedScorerIds.isEmpty
                      ? Text(
                        'Tap to select scorers',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      )
                      : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children:
                            _selectedScorerIds.map((id) {
                              final player = allPlayers.firstWhere(
                                (p) => p.id == id,
                              );
                              final user = _userForPlayer(player);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(
                                    0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.primaryGreen.withOpacity(
                                      0.4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildAvatar(user, 10, isSelected: true),
                                    const SizedBox(width: 4),
                                    Text(
                                      player.name.split(' ').first,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.primaryGreen,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
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
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              builder:
                  (_, controller) => Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: color.withOpacity(0.15),
                              child: Icon(Icons.group, color: color, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              teamName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${teamPlayers.length} selected',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search player...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    isDark
                                        ? const Color(0xFF253750)
                                        : const Color(0xFFE5E7EB),
                              ),
                            ),
                          ),
                          onChanged:
                              (v) => setInner(() => query = v.toLowerCase()),
                        ),
                      ),
                      const Divider(height: 16),
                      Expanded(
                        child:
                            _isLoadingUsers
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : ListView.builder(
                                  controller: controller,
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
                                    final isInOther = otherIds.contains(u.uid);
                                    final isSelected = teamPlayers.any(
                                      (p) => p.id == u.uid,
                                    );

                                    return CheckboxListTile(
                                      enabled: !isInOther,
                                      secondary: Stack(
                                        children: [
                                          _buildAvatar(
                                            u,
                                            20,
                                            isSelected: isSelected,
                                            selectedColor: color,
                                          ),
                                          if (isInOther)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.block,
                                                  size: 8,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      title: Text(
                                        u.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                          color:
                                              isInOther
                                                  ? Colors.grey
                                                  : (isSelected ? color : null),
                                        ),
                                      ),
                                      subtitle:
                                          isInOther
                                              ? Text(
                                                'In other team',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: Colors.redAccent,
                                                ),
                                              )
                                              : null,
                                      value: isSelected,
                                      activeColor: color,
                                      checkColor: Colors.white,
                                      onChanged:
                                          isInOther
                                              ? null
                                              : (val) {
                                                setInner(() {
                                                  setState(() {
                                                    if (val == true) {
                                                      teamPlayers.add(
                                                        PlayerModel(
                                                          id: u.uid,
                                                          name: u.name,
                                                          role: 'player',
                                                          teamId: '',
                                                          profileImageUrl:
                                                              u.profileImageUrl,
                                                        ),
                                                      );
                                                    } else {
                                                      teamPlayers.removeWhere(
                                                        (p) => p.id == u.uid,
                                                      );
                                                      // Clear roles if removed
                                                      _clearRolesForPlayer(
                                                        u.uid,
                                                        teamPlayers,
                                                      );
                                                    }
                                                  });
                                                });
                                                onChanged();
                                              },
                                    );
                                  },
                                ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Done (${teamPlayers.length} selected)',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            );
          },
        );
      },
    );
  }

  void _clearRolesForPlayer(String uid, List<PlayerModel> teamPlayers) {
    // Clear captain/vc if player removed
    if (_teamACaptainId == uid) _teamACaptainId = null;
    if (_teamAViceCaptainId == uid) _teamAViceCaptainId = null;
    if (_teamBCaptainId == uid) _teamBCaptainId = null;
    if (_teamBViceCaptainId == uid) _teamBViceCaptainId = null;
    _selectedScorerIds.remove(uid);
  }

  // ─── Bottom Sheet: Scorer Picker ───────────────────
  void _showScorerPicker(List<PlayerModel> players, bool isDark) {
    final searchCtrl = TextEditingController();
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              builder:
                  (_, controller) => Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.scoreboard_outlined,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Select Scorers',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_selectedScorerIds.length} selected',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search scorer...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    isDark
                                        ? const Color(0xFF253750)
                                        : const Color(0xFFE5E7EB),
                              ),
                            ),
                          ),
                          onChanged:
                              (v) => setInner(() => query = v.toLowerCase()),
                        ),
                      ),
                      const Divider(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          itemCount:
                              players
                                  .where(
                                    (p) => p.name.toLowerCase().contains(query),
                                  )
                                  .length,
                          itemBuilder: (_, i) {
                            final filtered =
                                players
                                    .where(
                                      (p) =>
                                          p.name.toLowerCase().contains(query),
                                    )
                                    .toList();
                            final p = filtered[i];
                            final user = _userForPlayer(p);
                            final isSelected = _selectedScorerIds.contains(
                              p.id,
                            );
                            final isTeamA = _teamAPlayers.contains(p);
                            return CheckboxListTile(
                              secondary: _buildAvatar(
                                user,
                                20,
                                isSelected: isSelected,
                              ),
                              title: Text(
                                p.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                  color:
                                      isSelected ? AppTheme.primaryGreen : null,
                                ),
                              ),
                              subtitle: Text(
                                isTeamA
                                    ? _teamANameController.text
                                    : _teamBNameController.text,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              value: isSelected,
                              activeColor: AppTheme.primaryGreen,
                              checkColor: Colors.white,
                              onChanged: (val) {
                                setInner(() {
                                  setState(() {
                                    if (val == true) {
                                      _selectedScorerIds.add(p.id);
                                    } else {
                                      _selectedScorerIds.remove(p.id);
                                    }
                                  });
                                });
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Done'),
                          ),
                        ),
                      ),
                    ],
                  ),
            );
          },
        );
      },
    );
  }

  // ─── Bottom Sheet: Role Picker ─────────────────────
  void _showRolePicker({
    required String label,
    required IconData icon,
    required Color color,
    required List<PlayerModel> players,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Select $label',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[300],
                      child: const Icon(
                        Icons.person_off,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                    title: Text(
                      'None (Optional)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing:
                        selectedId == null
                            ? Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryGreen,
                            )
                            : null,
                    onTap: () {
                      onChanged(null);
                      Navigator.pop(context);
                      setState(() {});
                    },
                  ),
                  ...players.map((p) {
                    final user = _userForPlayer(p);
                    final isSelected = selectedId == p.id;
                    return ListTile(
                      leading: _buildAvatar(
                        user,
                        20,
                        isSelected: isSelected,
                        selectedColor: color,
                      ),
                      title: Text(
                        p.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? color : null,
                        ),
                      ),
                      trailing:
                          isSelected
                              ? Icon(Icons.check_circle, color: color)
                              : null,
                      onTap: () {
                        onChanged(p.id);
                        Navigator.pop(context);
                        setState(() {});
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
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
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
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

  // ─── Step 3: Toss ──────────────────────────────────
  Widget _buildTossStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toss won by:',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            RadioListTile<String>(
              value: 'A',
              groupValue: _tossWonBy,
              onChanged: (v) => setState(() => _tossWonBy = v!),
              title: Text(_teamANameController.text),
              activeColor: AppTheme.primaryGreen,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            RadioListTile<String>(
              value: 'B',
              groupValue: _tossWonBy,
              onChanged: (v) => setState(() => _tossWonBy = v!),
              title: Text(_teamBNameController.text),
              activeColor: AppTheme.primaryGreen,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Chose to:',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                value: 'bat',
                groupValue: _tossDecision,
                onChanged: (v) => setState(() => _tossDecision = v!),
                title: const Text('Bat'),
                activeColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                value: 'bowl',
                groupValue: _tossDecision,
                onChanged: (v) => setState(() => _tossDecision = v!),
                title: const Text('Bowl'),
                activeColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildDivider('Advanced Settings', isDark),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B263B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
            ),
          ),
          child: SwitchListTile(
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
        ),
      ],
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
            _teamANameController.text == 'Team A') {
          UIUtils.showError('Please select Team A');
          return;
        }
        if (_teamBNameController.text.trim().isEmpty ||
            _teamBNameController.text == 'Team B') {
          UIUtils.showError('Please select Team B');
          return;
        }
        break;
      case 1:
        if (_teamAPlayers.isEmpty || _teamBPlayers.isEmpty) {
          UIUtils.showError('Add at least 1 player to each team');
          return;
        }
        if (_selectedScorerIds.isEmpty) {
          UIUtils.showError('Select at least one scorer');
          return;
        }
        break;
      case 2:
        _createMatch();
        return;
    }
    setState(() => _currentStep++);
  }

  Future<void> _createMatch() async {
    final matchId = await matchController.createMatch(
      title: _titleController.text.trim(),
      createdBy: authController.userId,
      totalOvers: rulesController.effectiveOvers(
        _totalOvers,
        teamSize:
            _teamAPlayers.length > _teamBPlayers.length
                ? _teamAPlayers.length
                : _teamBPlayers.length,
      ),
      teamAName: _teamANameController.text.trim(),
      teamBName: _teamBNameController.text.trim(),
      groundName: _groundNameController.text.trim(),
      teamAPlayers: _teamAPlayers,
      teamBPlayers: _teamBPlayers,
      scorerIds: _selectedScorerIds,
      tossWonBy: _tossWonBy,
      tossDecision: _tossDecision,
      teamACaptainId: _teamACaptainId,
      teamAViceCaptainId: _teamAViceCaptainId,
      teamBCaptainId: _teamBCaptainId,
      teamBViceCaptainId: _teamBViceCaptainId,
      customRulesEnabled: rulesController.customRulesEnabled.value,
      lastPlayerCanPlay: _lastPlayerCanPlay,
    );

    if (matchId != null) {
      UIUtils.showSuccess('Match created successfully!');

      // Clear selections for next time
      _teamAPlayers.clear();
      _teamBPlayers.clear();
      _selectedScorerIds.clear();

      // Navigate to Scoring Screen
      debugPrint('🚀 Navigating to Scoring Screen with ID: $matchId');
      Get.offNamed(AppRoutes.scoring, arguments: matchId);
    }
  }
}
