import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';

import '../database/database.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'profile_detail_screen.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  Future<void> _addProfile() async {
    final result = await showDialog<_ProfileFormResult>(
      context: context,
      builder: (_) => const _ProfileFormDialog(),
    );
    if (result == null) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await database.createProfile(
        ProfilesCompanion.insert(
          name: result.name,
          description: d.Value(result.description),
          isEnabled: d.Value(result.isEnabled),
          allowStarredContacts: d.Value(result.allowStarredContacts),
          allowRepeatCallers: d.Value(result.allowRepeatCallers),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await automationManager.syncRulesToAndroid();
      if (!mounted) return;
      _showSnackBar('Profile added.');
    } on ArgumentError catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message?.toString() ?? 'Profile name is required.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Profile could not be saved.');
    }
  }

  Future<void> _toggleProfile(Profile profile, bool enabled) async {
    try {
      await database.setProfileEnabled(profile.id, enabled);
      await automationManager.syncRulesToAndroid();
      if (!mounted) return;
      _showSnackBar(enabled ? 'Profile enabled.' : 'Profile disabled.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Profile could not be updated.');
    }
  }

  Future<void> _archiveProfile(Profile profile) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove profile?'),
        content: const Text(
          'This will remove the profile, but its rules will stay and move to No profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldArchive != true) return;

    try {
      await database.archiveProfile(profile.id);
      await automationManager.syncRulesToAndroid();
      if (!mounted) return;
      _showSnackBar('Profile removed. Rules moved to No profile.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Profile could not be removed.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _manageProfileRules(Profile profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileDetailScreen(profile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      body: StreamBuilder<List<ProfileWithRuleCount>>(
        stream: database.watchProfilesWithRuleCounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profiles = snapshot.data ?? const <ProfileWithRuleCount>[];
          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.pagePadding,
              AppTheme.pagePadding,
              96 + bottomSafePadding,
            ),
            children: [
              Text(
                'Profiles group rules for scenarios like Library, Work, or Sleep.',
                style: TextStyle(
                  color: AppTheme.pureBlack.withValues(alpha: 0.65),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppTheme.sectionGap),
              if (profiles.isEmpty)
                _ProfilesEmptyState(onAddProfile: _addProfile)
              else
                ...profiles.map(
                  (entry) => _ProfileCard(
                    entry: entry,
                    onToggle: (enabled) =>
                        _toggleProfile(entry.profile, enabled),
                    onManage: () => _manageProfileRules(entry.profile),
                    onArchive: () => _archiveProfile(entry.profile),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add profile'),
        onPressed: _addProfile,
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.entry,
    required this.onToggle,
    required this.onManage,
    required this.onArchive,
  });

  final ProfileWithRuleCount entry;
  final ValueChanged<bool> onToggle;
  final VoidCallback onManage;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final profile = entry.profile;
    final description = profile.description?.trim();
    final stateColor = profile.isEnabled
        ? AppTheme.logoBlue
        : AppTheme.pureBlack.withValues(alpha: 0.5);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.pureBlack,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.pureBlack.withValues(alpha: 0.62),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(value: profile.isEnabled, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: profile.isEnabled
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                  label: profile.isEnabled ? 'Enabled' : 'Disabled',
                  color: stateColor,
                ),
                _InfoChip(
                  icon: Icons.rule_outlined,
                  label: _ruleCountLabel(entry.ruleCount),
                  color: AppTheme.logoPurple,
                ),
                if (profile.allowStarredContacts)
                  const _InfoChip(
                    icon: Icons.star_outline,
                    label: 'Starred contacts',
                    color: AppTheme.logoCyan,
                  ),
                if (profile.allowRepeatCallers)
                  const _InfoChip(
                    icon: Icons.repeat,
                    label: 'Repeat callers',
                    color: AppTheme.logoCyan,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Manage rules'),
                ),
                Tooltip(
                  message: 'Remove profile',
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppTheme.logoPurple,
                    onPressed: onArchive,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _ruleCountLabel(int count) {
    if (count == 1) return '1 rule';
    return '$count rules';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.pureBlack,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilesEmptyState extends StatelessWidget {
  const _ProfilesEmptyState({required this.onAddProfile});

  final VoidCallback onAddProfile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sectionGap),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 56,
              color: AppTheme.logoCyan,
            ),
            const SizedBox(height: 16),
            const Text(
              'No profiles yet.',
              style: TextStyle(
                color: AppTheme.pureBlack,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a profile to group rules for a scenario.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.pureBlack.withValues(alpha: 0.62),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAddProfile,
              icon: const Icon(Icons.add),
              label: const Text('Add profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileFormDialog extends StatefulWidget {
  const _ProfileFormDialog();

  @override
  State<_ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<_ProfileFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late bool _isEnabled;
  late bool _allowStarredContacts;
  late bool _allowRepeatCallers;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _isEnabled = true;
    _allowStarredContacts = false;
    _allowRepeatCallers = false;
    _nameController.addListener(_clearNameErrorWhenValid);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_clearNameErrorWhenValid)
      ..dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _clearNameErrorWhenValid() {
    if (_nameError == null) return;
    if (validateProfileName(_nameController.text) != null) return;
    setState(() => _nameError = null);
  }

  void _submit() {
    final nameError = validateProfileName(_nameController.text);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final description = _descriptionController.text.trim();
    Navigator.pop(
      context,
      _ProfileFormResult(
        name: _nameController.text.trim(),
        description: description.isEmpty ? null : description,
        isEnabled: _isEnabled,
        allowStarredContacts: _allowStarredContacts,
        allowRepeatCallers: _allowRepeatCallers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isEnabled,
              onChanged: (value) => setState(() => _isEnabled = value),
              title: const Text('Enabled'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowStarredContacts,
              onChanged: (value) {
                setState(() => _allowStarredContacts = value ?? false);
              },
              title: const Text('Allow starred contacts'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowRepeatCallers,
              onChanged: (value) {
                setState(() => _allowRepeatCallers = value ?? false);
              },
              title: const Text('Allow repeat callers'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _ProfileFormResult {
  const _ProfileFormResult({
    required this.name,
    required this.description,
    required this.isEnabled,
    required this.allowStarredContacts,
    required this.allowRepeatCallers,
  });

  final String name;
  final String? description;
  final bool isEnabled;
  final bool allowStarredContacts;
  final bool allowRepeatCallers;
}
