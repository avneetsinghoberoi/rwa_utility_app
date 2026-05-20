import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import '../../models/user.dart' as UserModel;
import '../../services/account_link_service.dart' hide debugPrint;
import '../../theme/app_theme.dart';
import '../../utils/dashboard_key.dart';

class ManageMembersScreen extends StatefulWidget {
  final UserModel.User currentUser;

  const ManageMembersScreen({required this.currentUser});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  late UserModel.User currentUser;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Account Access'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => dashboardScaffoldKey.currentState?.openDrawer(),
              ),
        actions: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () => dashboardScaffoldKey.currentState?.openDrawer(),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Current Members Section
                  _buildCurrentMembersSection(),
                  const SizedBox(height: 32),

                  // Add New Member Button (only for owner)
                  if (currentUser.canManageFlatMembers) ...[
                    _buildAddMemberButton(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flat ${currentUser.unitInfo.wing}/${currentUser.unitInfo.flatNo}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Users with access to this account',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Text(
            '${currentUser.flatMemberCount} ${currentUser.flatMemberCount == 1 ? 'member' : 'members'} have access',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentMembersSection() {
    return StreamBuilder<List<UserModel.User>>(
      stream: _getFlatMembersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No members yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Members',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final member = members[index];
                final isOwner = member.isAccountOwner;
                final isSelf = member.uid == currentUser.uid;

                return _buildMemberCard(
                  member: member,
                  isOwner: isOwner,
                  isSelf: isSelf,
                  canRemove: currentUser.canManageFlatMembers &&
                      !isOwner &&
                      !isSelf,
                  onRemove: () => _showRemoveConfirmation(member),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMemberCard({
    required UserModel.User member,
    required bool isOwner,
    required bool isSelf,
    required bool canRemove,
    required VoidCallback onRemove,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isOwner
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary,
              child: Text(
                member.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Member info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'You',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (member.accountLink.linkedAs.isNotEmpty)
                    Text(
                      _getRelationshipLabel(member.accountLink.linkedAs),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Actions
            if (isOwner)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Text(
                  'Owner',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              )
            else if (canRemove)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onRemove,
                tooltip: 'Remove member',
              )
            else
              Text(
                'Member',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMemberButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showAddMemberDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add User to This Account'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // DIALOGS
  // ============================================================================

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(
        currentUser: currentUser,
        onAdd: _addMember,
      ),
    );
  }

  void _showRemoveConfirmation(UserModel.User member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          'Are you sure you want to remove ${member.name} from this account? They will no longer have access to flat ${currentUser.unitInfo.wing}/${currentUser.unitInfo.flatNo}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeMember(member);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================

  Future<void> _addMember({
    required String email,
    required String name,
    required String relationship,
  }) async {
    setState(() => isLoading = true);

    try {
      await AccountLinkService.addFlatMember(
        email: email,
        name: name,
        relationship: relationship,
        currentUser: currentUser,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request created for $email. You will need to manually share credentials until email system is configured.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _removeMember(UserModel.User member) async {
    setState(() => isLoading = true);

    try {
      await AccountLinkService.removeFlatMember(
        memberUidToRemove: member.uid,
        currentUser: currentUser,
      );

      // Refresh currentUser so flatMembers reflects the removal.
      // Without this, the stream would still query for the removed UID
      // and get permission-denied (they're no longer in flat_members).
      await _refreshCurrentUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name} removed from account'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Re-fetch the current user document from Firestore and rebuild the screen.
  Future<void> _refreshCurrentUser() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          currentUser = UserModel.User.fromFirestore(doc);
        });
      }
    } catch (e) {
      debugPrint('Failed to refresh current user: $e');
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  Stream<List<UserModel.User>> _getFlatMembersStream() {
    // ✅ If no flat members, return empty stream instead of error
    if (currentUser.flatMembers.isEmpty) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .where(
          FieldPath.documentId,
          whereIn: currentUser.flatMembers,
        )
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.User.fromFirestore(doc)).toList());
  }

  String _getRelationshipLabel(String relationship) {
    final labels = {
      'owner': '👤 Account Owner',
      'spouse': '💑 Spouse',
      'tenant': '🏠 Tenant',
      'roommate': '👥 Roommate',
      'family': '👨‍👩‍👧‍👦 Family',
    };
    return labels[relationship] ?? relationship;
  }
}

// ============================================================================
// ADD MEMBER DIALOG
// ============================================================================

class _AddMemberDialog extends StatefulWidget {
  final UserModel.User currentUser;
  final Function({
    required String email,
    required String name,
    required String relationship,
  }) onAdd;

  const _AddMemberDialog({
    required this.currentUser,
    required this.onAdd,
  });

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  String selectedRelationship = 'tenant';
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add User to Account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                hintText: 'Enter their full name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email Address *',
                hintText: 'Enter their email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedRelationship,
              items: [
                'spouse',
                'tenant',
                'roommate',
                'family',
                'other',
              ]
                  .map((rel) => DropdownMenuItem(
                        value: rel,
                        child: Text(_capitalize(rel)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => selectedRelationship = value ?? 'tenant');
              },
              decoration: InputDecoration(
                labelText: 'Relationship',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.info_outline),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'An invitation will be sent. They can set their password and log in.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add User'),
        ),
      ],
    );
  }

  void _handleSubmit() {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    // Validation
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name')),
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid email')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    widget.onAdd(
      name: name,
      email: email,
      relationship: selectedRelationship,
    );

    Navigator.pop(context);
  }

  String _capitalize(String str) {
    return str[0].toUpperCase() + str.substring(1);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }
}
