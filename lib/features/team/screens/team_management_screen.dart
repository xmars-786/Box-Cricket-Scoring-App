import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/controllers/team_controller.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/models/team_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/ui_utils.dart';
import '../../explore/screens/player_profile_screen.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final TeamController _teamController = Get.put(TeamController());

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.primaryDark : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  _buildSectionIndicator(),
                  const SizedBox(width: 12),
                  Text(
                    'YOUR TEAMS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Obx(() {
            if (_teamController.isLoading.value) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (_teamController.teams.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(isDark),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final team = _teamController.teams[index];
                  return _buildModernTeamCard(team, isDark);
                }, childCount: _teamController.teams.length),
              ),
            );
          }),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
        ),
      ),
      floatingActionButton: _buildModernFAB(context, isDark),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      expandedHeight: 100,
      pinned: true,
      backgroundColor: AppTheme.primaryGreen,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'TEAMS',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryGreen,
                    const Color(0xFF00B894).withOpacity(0.8),
                  ],
                ),
              ),
            ),
            // Subtle geometric shape
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionIndicator() {
    return Container(
      width: 4,
      height: 16,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildModernTeamCard(TeamModel team, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showCreateOrEditTeamDialog(context, team: team),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryGreen.withOpacity(0.2),
                          const Color(0xFF00B894).withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.groups_rounded,
                        color: AppTheme.primaryGreen,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${team.playerIds.length} Players Registered',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: Icons.edit_rounded,
                        color: AppTheme.primaryGreen,
                        onTap:
                            () => _showCreateOrEditTeamDialog(
                              context,
                              team: team,
                            ),
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Icons.delete_rounded,
                        color: Colors.redAccent,
                        onTap: () => _confirmDelete(team),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildModernFAB(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _showCreateOrEditTeamDialog(context),
        icon: const Icon(Icons.add_rounded, size: 24),
        label: Text(
          'NEW TEAM',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_off_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Teams Yet',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Build your legendary squad and start dominating the tournaments!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black45,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(TeamModel team) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Team?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete ${team.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'CANCEL',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _teamController.deleteTeam(team.id);
              Get.back();
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateOrEditTeamDialog(BuildContext context, {TeamModel? team}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TeamEditorSheet(team: team),
    );
  }
}

class _TeamEditorSheet extends StatefulWidget {
  final TeamModel? team;
  const _TeamEditorSheet({this.team});

  @override
  State<_TeamEditorSheet> createState() => _TeamEditorSheetState();
}

class _TeamEditorSheetState extends State<_TeamEditorSheet> {
  final _nameController = TextEditingController();
  final List<String> _selectedPlayerIds = [];
  List<AppUser> _allApprovedUsers = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    if (widget.team != null) {
      _nameController.text = widget.team!.name;
      _selectedPlayerIds.addAll(widget.team!.playerIds.toSet().toList());
    }
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final teamController = Get.find<TeamController>();

      // Collect all player IDs that are already in OTHER teams
      final assignedPlayerIds = <String>{};
      for (final t in teamController.teams) {
        if (widget.team == null || t.id != widget.team!.id) {
          assignedPlayerIds.addAll(t.playerIds);
        }
      }

      final snapshot =
          await FirebaseFirestore.instance
              .collection(AppConstants.usersCollection)
              .get();
      if (mounted) {
        setState(() {
          _allApprovedUsers =
              snapshot.docs
                  .map((d) => AppUser.fromFirestore(d))
                  .where((u) {
                    final isAlreadyInTeam = _selectedPlayerIds.contains(u.uid);
                    final isAvailable = u.isApproved && !assignedPlayerIds.contains(u.uid);
                    // Show if they are already in the team OR if they are available to be added
                    return isAlreadyInTeam || isAvailable;
                  })
                  .toList();
          _isLoadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  void _saveTeam() async {
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Please enter a team name');
      return;
    }
    if (_selectedPlayerIds.isEmpty) {
      Get.snackbar('Required', 'Please select at least 1 player');
      return;
    }

    final auth = Get.find<AuthController>();
    final controller = Get.find<TeamController>();

    Get.back(); // close sheet

    if (widget.team == null) {
      final success = await controller.createTeam(
        _nameController.text.trim(),
        _selectedPlayerIds,
        auth.userId,
      );
      if (success) {
        // UIUtils.showSuccess('Team created successfully');
      }
    } else {
      final success = await controller.updateTeam(
        widget.team!.id,
        _nameController.text.trim(),
        _selectedPlayerIds,
      );
      if (success) {
        // UIUtils.showSuccess('Team updated successfully');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.primaryDark : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.team == null ? 'Create New Squad' : 'Edit Squad',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TEAM IDENTITY',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Enter Team Name',
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      prefixIcon: const Icon(Icons.badge_outlined),
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
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryGreen,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DRAFT PLAYERS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white38 : Colors.black38,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_selectedPlayerIds.length} SELECTED',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingUsers)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_allApprovedUsers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'No available players found',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _allApprovedUsers.length,
                      itemBuilder: (context, index) {
                        final user = _allApprovedUsers[index];
                        final isSelected = _selectedPlayerIds.contains(
                          user.uid,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppTheme.primaryGreen.withOpacity(
                                      isDark ? 0.1 : 0.05,
                                    )
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? AppTheme.primaryGreen.withOpacity(0.3)
                                      : Colors.transparent,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  if (!_selectedPlayerIds.contains(user.uid)) {
                                    _selectedPlayerIds.add(user.uid);
                                  }
                                } else {
                                  _selectedPlayerIds.remove(user.uid);
                                }
                              });
                            },
                            activeColor: AppTheme.primaryGreen,
                            checkboxShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            title: Text(
                              user.name,
                              style: GoogleFonts.inter(
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            secondary: Hero(
                              tag: 'player_${user.uid}',
                              child: InkWell(
                                onTap: () {
                                  Get.to(
                                    () => PlayerProfileScreen(playerId: user.uid),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? AppTheme.primaryGreen
                                              : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.grey[200],
                                    backgroundImage:
                                        user.profileImageUrl != null
                                            ? NetworkImage(user.profileImageUrl!)
                                            : null,
                                    child:
                                        user.profileImageUrl == null
                                            ? Icon(
                                              Icons.person_rounded,
                                              size: 20,
                                              color:
                                                  isDark
                                                      ? Colors.white24
                                                      : Colors.grey[400],
                                            )
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _saveTeam,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.team == null ? 'CREATE TEAM' : 'UPDATE TEAM',
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
    );
  }
}
