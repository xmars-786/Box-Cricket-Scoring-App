import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/controllers/admin_controller.dart';
import '../../core/controllers/rules_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/controllers/auth_controller.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  final AdminController adminController = Get.put(AdminController());
  final RulesController rulesController = Get.find<RulesController>();

  AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            Builder(
              builder:
                  (ctx) => IconButton(
                    icon: const Icon(Icons.person_add),
                    tooltip: 'Add Quick Player',
                    onPressed: () => _showAddQuickPlayerDialog(ctx),
                  ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Approvals', icon: Icon(Icons.verified_user_outlined)),
              Tab(text: 'Users', icon: Icon(Icons.group_outlined)),
              Tab(text: 'Rules', icon: Icon(Icons.settings_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingUsersList(),
            _buildAllUsersList(),
            _buildGlobalRulesSettings(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingUsersList() {
    return Obx(() {
      final approvalList =
          adminController.allUsers
              .where((user) => user.role != AppConstants.roleSuperAdmin)
              .toList();

      if (approvalList.isEmpty) {
        return const Center(child: Text('No users found'));
      }
      return ListView.builder(
        itemCount: approvalList.length,
        itemBuilder: (context, index) {
          final user = approvalList[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    user.profileImageUrl != null
                        ? NetworkImage(user.profileImageUrl!)
                        : null,
                child:
                    user.profileImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
              ),
              title: Text(user.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.phone.isNotEmpty ? user.phone : 'No phone'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: user.isApproved ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.isApproved ? 'Approved' : 'Pending',
                        style: TextStyle(
                          color: user.isApproved ? Colors.green : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () => _showApprovalDialog(context, user),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF253750)
                          : Colors.grey[200],
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Action',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildAllUsersList() {
    return Obx(() {
      return ListView.builder(
        itemCount: adminController.allUsers.length,
        itemBuilder: (context, index) {
          final user = adminController.allUsers[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  user.profileImageUrl != null
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
              child:
                  user.profileImageUrl == null
                      ? const Icon(Icons.person)
                      : null,
            ),
            title: Text(user.name),
            subtitle: Text(
              'Role: ${user.role.replaceAll('_', ' ').toUpperCase()}',
            ),
            trailing:
                Get.find<AuthController>().currentUser?.isSuperAdmin == true
                    ? IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showRoleDialog(context, user),
                    )
                    : null,
          );
        },
      );
    });
  }

  Widget _buildGlobalRulesSettings(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Global Match Rules',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Configure default rules applied to all new matches.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          Obx(
            () => _buildStepperTile(
              isDark,
              'Wide Ball Runs',
              rulesController.wideRuns.value,
              (val) => rulesController.updateRules(wide: val),
            ),
          ),
          const SizedBox(height: 12),

          Obx(
            () => _buildStepperTile(
              isDark,
              'No-Ball Runs',
              rulesController.noBallRuns.value,
              (val) => rulesController.updateRules(noBall: val),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B263B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Obx(
              () => SwitchListTile(
                title: Text(
                  'Free Hit on No-Ball',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: rulesController.freeHitEnabled.value,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF00C853),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onChanged: (val) => rulesController.updateRules(freeHit: val),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Last Player Can Play toggle
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B263B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Obx(
              () => SwitchListTile(
                title: Text(
                  'Last Player Can Play',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Allows the last remaining batsman to bat alone',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
                value: rulesController.lastPlayerCanPlay.value,
                activeColor: Colors.white,
                activeTrackColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onChanged:
                    (val) => rulesController.updateRules(lastPlayerPlay: val),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Custom Over Rules ────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFFFF6B35),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Custom Over Rules',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Limit how many overs a player can bat or bowl per match.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Master toggle
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B263B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Obx(
              () => SwitchListTile(
                title: Text(
                  'Enable Custom Rules',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  rulesController.customRulesEnabled.value
                      ? 'Custom limits active for all matches'
                      : 'Using default (no player limits)',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
                value: rulesController.customRulesEnabled.value,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFFFF6B35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onChanged:
                    (val) => rulesController.updateRules(customEnabled: val),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Obx(
            () =>
                rulesController.customRulesEnabled.value
                    ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: AppTheme.vibrantOrange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Single Batsman mode: New striker only after wicket or quota end. Innings ends when all players finish quota.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: AppTheme.vibrantOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          // Conditional settings (only when enabled)
          Obx(() {
            if (!rulesController.customRulesEnabled.value) {
              return const SizedBox.shrink();
            }
            return Column(
              children: [
                const SizedBox(height: 12),
                _buildStepperTile(
                  isDark,
                  'Max Batting Overs / Player',
                  rulesController.maxBattingOvers.value,
                  (val) => rulesController.updateRules(maxBatting: val),
                  min: 1,
                  max: 10,
                  color: const Color(0xFF00C853),
                ),
                const SizedBox(height: 12),
                _buildStepperTile(
                  isDark,
                  'Max Bowling Overs / Player',
                  rulesController.maxBowlingOvers.value,
                  (val) => rulesController.updateRules(maxBowling: val),
                  min: 1,
                  max: 10,
                  color: const Color(0xFF2196F3),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStepperTile(
    bool isDark,
    String title,
    int currentValue,
    Function(int) onChanged, {
    int min = 0,
    int max = 99,
    Color? color,
  }) {
    final accentColor = color ?? const Color(0xFF00C853);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepperButton(
                    isDark,
                    Icons.remove,
                    accentColor,
                    currentValue > min
                        ? () => onChanged(currentValue - 1)
                        : null,
                  ),
                  Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: Text(
                      currentValue.toString(),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  _stepperButton(
                    isDark,
                    Icons.add,
                    accentColor,
                    currentValue < max
                        ? () => onChanged(currentValue + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(
    bool isDark,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              disabled
                  ? (isDark ? const Color(0xFF1E2D42) : Colors.grey[100])
                  : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: disabled ? Colors.grey[400] : color),
      ),
    );
  }

  void _showRoleDialog(BuildContext context, AppUser user) {
    final availableRoles = [
      AppConstants.rolePlayer,
      AppConstants.roleAdmin,
      AppConstants.roleSuperAdmin,
    ];
    String selectedRole =
        availableRoles.contains(user.role)
            ? user.role
            : AppConstants.rolePlayer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign Role',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a new role for ${user.name}',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              StatefulBuilder(
                builder: (context, setState) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF334155)
                                : Colors.grey[200]!,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedRole,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        dropdownColor:
                            isDark ? const Color(0xFF1B263B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: AppConstants.rolePlayer,
                            child: Text('Player'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.roleAdmin,
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.roleSuperAdmin,
                            child: Text('Super Admin'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectedRole = val);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Get.find<AdminController>().updateUserRole(
                        user.uid,
                        selectedRole,
                      );
                      Get.back();
                      // Get.snackbar(
                      //   'Success',
                      //   'Role updated to ${selectedRole.toUpperCase()}',
                      //   snackPosition: SnackPosition.TOP,
                      //   backgroundColor: Colors.green,
                      //   colorText: Colors.white,
                      // );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApprovalDialog(BuildContext context, AppUser user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add,
                  color: Color(0xFF00C853),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Review Registration',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Approve or decline ${user.name}\'s request.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back();
                        Get.find<AdminController>().unapproveUser(user.uid);
                        // Get.snackbar(
                        //   'Unapproved',
                        //   'User has been unapproved',
                        //   snackPosition: SnackPosition.TOP,
                        // );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Unapprove',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.find<AdminController>().approveUser(
                          user.uid,
                          AppConstants.rolePlayer,
                        );
                        // Get.snackbar(
                        //   'Approved',
                        //   '${user.name} approved as Player',
                        //   snackPosition: SnackPosition.TOP,
                        //   backgroundColor: Colors.green,
                        //   colorText: Colors.white,
                        // );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Approve',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddQuickPlayerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create Player',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Player will be immediately approved.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixText: '+91 ',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final phone = '+91${phoneCtrl.text.trim()}';
                        if (name.isEmpty) {
                          Get.snackbar('Required', 'Please enter a name');
                          return;
                        }
                        if (phoneCtrl.text.trim().length < 10) {
                          Get.snackbar(
                            'Required',
                            'Enter a valid 10-digit phone number',
                          );
                          return;
                        }
                        Get.back();
                        Get.find<AdminController>().addQuickPlayer(name, phone);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
