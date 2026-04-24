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
      appBar: AppBar(
        title: Text(
          'Team Management',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(() {
        if (_teamController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_teamController.teams.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No teams found',
                  style: GoogleFonts.inter(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first team!',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _teamController.teams.length,
          itemBuilder: (context, index) {
            final team = _teamController.teams[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF2196F3).withOpacity(0.2),
                  child: const Icon(Icons.group, color: Color(0xFF2196F3)),
                ),
                title: Text(
                  team.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  '${team.playerIds.length} players',
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed:
                          () =>
                              _showCreateOrEditTeamDialog(context, team: team),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _teamController.deleteTeam(team.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrEditTeamDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Create Team'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
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
      _selectedPlayerIds.addAll(widget.team!.playerIds);
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
                  .where((u) => u.isApproved && !assignedPlayerIds.contains(u.uid))
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
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.team == null ? 'Create New Team' : 'Edit Team',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Get.back(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Team Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select Players (${_selectedPlayerIds.length} selected)',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: _allApprovedUsers.length,
                      itemBuilder: (context, index) {
                        final user = _allApprovedUsers[index];
                        final isSelected = _selectedPlayerIds.contains(
                          user.uid,
                        );
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedPlayerIds.add(user.uid);
                              } else {
                                _selectedPlayerIds.remove(user.uid);
                              }
                            });
                          },
                          title: Text(user.name),
                          secondary: CircleAvatar(
                            backgroundImage:
                                user.profileImageUrl != null
                                    ? NetworkImage(user.profileImageUrl!)
                                    : null,
                            child:
                                user.profileImageUrl == null
                                    ? const Icon(Icons.person, size: 16)
                                    : null,
                          ),
                        );
                      },
                    ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveTeam,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(widget.team == null ? 'Create Team' : 'Update Team'),
            ),
          ),
        ],
      ),
    );
  }
}
