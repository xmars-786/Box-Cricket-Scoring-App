import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/controllers/admin_controller.dart';
import '../../core/controllers/rules_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/controllers/auth_controller.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_utils.dart';

class AdminDashboardScreen extends StatelessWidget {
  final AdminController adminController = Get.put(AdminController());
  final RulesController rulesController = Get.find<RulesController>();

  AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor:
            isDark ? AppTheme.primaryDark : const Color(0xFFF8FAFC),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                floating: true,
                elevation: innerBoxIsScrolled ? 4 : 0,
                backgroundColor: isDark ? AppTheme.primaryDark : Colors.white,
                foregroundColor:
                    isDark ? Colors.white : const Color(0xFF1A1A2E),
                centerTitle: true,
                title: Text(
                  'Admin Panel',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 1,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      onPressed: () => _showAddQuickPlayerDialog(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
                bottom: TabBar(
                  indicatorColor: AppTheme.primaryGreen,
                  indicatorWeight: 3,
                  labelColor: AppTheme.primaryGreen,
                  unselectedLabelColor:
                      isDark ? Colors.white60 : Colors.black45,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                  tabs: const [
                    Tab(text: 'APPROVALS'),
                    Tab(text: 'USERS'),
                    Tab(text: 'RULES'),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildPendingUsersList(isDark),
              _buildAllUsersList(isDark),
              _buildGlobalRulesSettings(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Pending Users List ────────────────────────────────
  Widget _buildPendingUsersList(bool isDark) {
    return Obx(() {
      final approvalList =
          adminController.allUsers
              .where((u) => !u.isApproved)
              .toList(); // Fixed logic to show only unapproved

      if (approvalList.isEmpty) {
        return _buildEmptyState(
          isDark,
          Icons.verified_user_outlined,
          'No Pending Requests',
          'All registration requests are processed!',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: approvalList.length,
        itemBuilder: (context, index) {
          return _buildUserCard(context, approvalList[index], isDark, true);
        },
      );
    });
  }

  // ─── All Users List ───────────────────────────────────
  Widget _buildAllUsersList(bool isDark) {
    return Obx(() {
      final users = adminController.allUsers;

      if (users.isEmpty) {
        return _buildEmptyState(
          isDark,
          Icons.group_outlined,
          'No Users Found',
          'Your community is empty right now.',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: users.length,
        itemBuilder: (context, index) {
          return _buildUserCard(context, users[index], isDark, false);
        },
      );
    });
  }

  // ─── User Card Component ──────────────────────────────
  Widget _buildUserCard(
    BuildContext context,
    AppUser user,
    bool isDark,
    bool isPending,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Hero(
            tag: 'admin_user_${user.uid}',
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
              foregroundImage:
                  user.profileImageUrl != null &&
                          user.profileImageUrl!.isNotEmpty
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
              child: Text(
                user.name.substring(0, 1).toUpperCase(),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
          title: Text(
            user.name,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      user.isApproved
                          ? AppTheme.primaryGreen.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user.isApproved ? 'APPROVED' : 'PENDING',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color:
                        user.isApproved ? AppTheme.primaryGreen : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                user.role.replaceAll('_', ' ').toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildActionChip(
                        icon: Icons.edit_outlined,
                        label: 'Edit Info',
                        color: Colors.blue,
                        onTap: () => _showEditUserDialog(context, user),
                      ),
                      const SizedBox(width: 8),
                      if (isPending || !user.isApproved)
                        _buildActionChip(
                          icon: Icons.check_circle_outline,
                          label: 'Approve',
                          color: AppTheme.primaryGreen,
                          onTap: () => _showApprovalDialog(context, user),
                        )
                      else
                        _buildActionChip(
                          icon: Icons.remove_circle_outline,
                          label: 'Unapprove',
                          color: Colors.orange,
                          onTap: () => adminController.unapproveUser(user.uid),
                        ),
                      const Spacer(),
                      _buildActionChip(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: AppTheme.wicketRed,
                        onTap: () => _showDeleteConfirmation(context, user),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Edit User Dialog ────────────────────────────────
  void _showEditUserDialog(BuildContext context, AppUser user) {
    final nameController = TextEditingController(text: user.name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final availableRoles = [AppConstants.rolePlayer, AppConstants.roleAdmin];
    String selectedRole =
        availableRoles.contains(user.role)
            ? user.role
            : AppConstants.rolePlayer;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Player',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'FULL NAME',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ROLE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setState) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedRole,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        dropdownColor:
                            isDark ? const Color(0xFF1B263B) : Colors.white,
                        items: const [
                          DropdownMenuItem(
                            value: AppConstants.rolePlayer,
                            child: Text('Player'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.roleAdmin,
                            child: Text('Admin'),
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
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      adminController.updateUserDetails(
                        uid: user.uid,
                        name: nameController.text.trim(),
                        role: selectedRole,
                      );
                      Get.back();
                      UIUtils.showSuccess('Player updated successfully');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Approval Dialog ────────────────────────────────
  void _showApprovalDialog(BuildContext context, AppUser user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: AppTheme.primaryGreen,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Review User',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Approve ${user.name} to join the community?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        adminController.approveUser(
                          user.uid,
                          AppConstants.rolePlayer,
                        );
                        Get.back();
                        UIUtils.showSuccess('${user.name} Approved!');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Approve'),
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

  // ─── Rules Tab ──────────────────────────────────────
  Widget _buildGlobalRulesSettings(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Global Match Rules',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Default rules applied to all new matches.',
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
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                subtitle: Text(
                  'Award free hit for next ball',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
                value: rulesController.freeHitEnabled.value,
                activeColor: AppTheme.primaryGreen,
                onChanged: (val) => rulesController.updateRules(freeHit: val),
              ),
            ),
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              '${AppConstants.developedBy} ${AppConstants.appVersion}',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.grey.withOpacity(0.3),
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────
  Widget _buildStepperTile(
    bool isDark,
    String title,
    int currentValue,
    Function(int) onChanged, {
    int min = 0,
    int max = 99,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          Row(
            children: [
              _stepperButton(
                isDark,
                Icons.remove_rounded,
                currentValue > min ? () => onChanged(currentValue - 1) : null,
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  currentValue.toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              _stepperButton(
                isDark,
                Icons.add_rounded,
                currentValue < max ? () => onChanged(currentValue + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(bool isDark, IconData icon, VoidCallback? onTap) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              disabled
                  ? Colors.grey.withOpacity(0.1)
                  : AppTheme.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled ? Colors.grey : AppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showAddQuickPlayerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Quick Player',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty &&
                          phoneController.text.isNotEmpty) {
                        adminController.addQuickPlayer(
                          nameController.text.trim(),
                          phoneController.text.trim(),
                        );
                        Get.back();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add Player'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppUser user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.wicketRed,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Player?',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently remove ${user.name} from the app. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        adminController.deleteUser(user.uid);
                        Get.back();
                        UIUtils.showSuccess('Player Deleted');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.wicketRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Delete'),
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
