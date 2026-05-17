import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';

import '../database/database.dart';
import '../main.dart';
import '../models/rule_trigger_summary.dart';
import '../services/app_catalog.dart';
import '../theme/app_theme.dart';
import 'create_rule_wizard.dart';
import 'multi_trigger_rule_form_screen.dart';
import 'rule_form_screen.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final Set<String> _loadingAppPackages = {};
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late bool _profileEnabled;
  int? _loadedProfileUpdatedAt;
  String? _nameError;
  bool _profileFormDirty = false;
  bool _isSavingProfile = false;
  bool _isSyncingProfileForm = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _applyProfileToForm(widget.profile);
    _nameController.addListener(_handleProfileFormChanged);
    _descriptionController.addListener(_handleProfileFormChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleProfileFormChanged)
      ..dispose();
    _descriptionController
      ..removeListener(_handleProfileFormChanged)
      ..dispose();
    super.dispose();
  }

  void _applyProfileToForm(Profile profile) {
    _isSyncingProfileForm = true;
    _nameController.text = profile.name;
    _descriptionController.text = profile.description ?? '';
    _profileEnabled = profile.isEnabled;
    _loadedProfileUpdatedAt = profile.updatedAt;
    _nameError = null;
    _profileFormDirty = false;
    _isSyncingProfileForm = false;
  }

  void _syncFormFromProfileIfNeeded(Profile profile) {
    if (_profileFormDirty) return;
    if (_loadedProfileUpdatedAt == profile.updatedAt) return;
    _applyProfileToForm(profile);
  }

  void _handleProfileFormChanged() {
    if (_isSyncingProfileForm) return;
    if (_nameError != null &&
        validateProfileName(_nameController.text) == null) {
      setState(() => _nameError = null);
      return;
    }
    if (!_profileFormDirty) {
      setState(() => _profileFormDirty = true);
    }
  }

  void _setProfileDraft(VoidCallback update) {
    setState(() {
      update();
      _profileFormDirty = true;
    });
  }

  Future<void> _addRule(Profile profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRuleWizard(profileId: profile.id),
      ),
    );
  }

  Future<void> _editRule(RuleWithTriggers entry) async {
    if (entry.triggers.length > 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiTriggerRuleFormScreen(ruleWithTriggers: entry),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RuleFormScreen(rule: entry.rule)),
    );
  }

  Future<void> _deleteRule(RuleWithTriggers entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('Delete "${entry.rule.name}" from this profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    await database.deleteRuleAndTriggers(entry.rule.id);
    await automationManager.syncRulesToAndroid();
    if (!mounted) return;
    _showSnackBar('Rule deleted.');
  }

  Future<void> _saveProfileChanges(Profile profile) async {
    final validationError = validateProfileName(_nameController.text);
    if (validationError != null) {
      setState(() => _nameError = validationError);
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      final description = _descriptionController.text.trim();
      await database.updateProfile(
        profile.copyWith(
          name: _nameController.text.trim(),
          description: d.Value(description.isEmpty ? null : description),
          isEnabled: _profileEnabled,
          allowStarredContacts: false,
          allowRepeatCallers: false,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await automationManager.syncRulesToAndroid();
      if (!mounted) return;
      setState(() {
        _profileFormDirty = false;
        _isSavingProfile = false;
      });
      _showSnackBar('Profile updated.');
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() {
        _nameError = error.message?.toString() ?? 'Profile name is required.';
        _isSavingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingProfile = false);
      _showSnackBar('Profile could not be updated.');
    }
  }

  Future<void> _toggleRule(RuleWithTriggers entry, bool isEnabled) async {
    await database.updateRule(entry.rule.copyWith(isEnabled: isEnabled));
    await automationManager.syncRulesToAndroid();
    if (!mounted) return;
    _showSnackBar(isEnabled ? 'Rule enabled.' : 'Rule paused.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    return StreamBuilder<List<Profile>>(
      stream: database.watchProfiles(includeArchived: true),
      builder: (context, profileSnapshot) {
        final profiles = profileSnapshot.data ?? const <Profile>[];
        final matches = profiles.where(
          (profile) => profile.id == widget.profile.id,
        );
        final profile = matches.isEmpty ? widget.profile : matches.first;
        _syncFormFromProfileIfNeeded(profile);

        return Scaffold(
          appBar: AppBar(title: Text(profile.name)),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              AppTheme.pagePadding,
              AppTheme.pagePadding,
              96 + bottomSafePadding,
            ),
            children: [
              _buildProfileEditor(profile),
              if (!_profileEnabled) ...[
                const SizedBox(height: AppTheme.sectionGap),
                _buildDisabledWarning(),
              ],
              const SizedBox(height: AppTheme.sectionGap),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Rules',
                      style: TextStyle(
                        color: AppTheme.pureBlack,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addRule(profile),
                    icon: const Icon(Icons.add),
                    label: const Text('Add rule'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<RuleWithTriggers>>(
                stream: database.watchRulesForProfile(profile.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final entries = snapshot.data ?? const <RuleWithTriggers>[];
                  if (entries.isEmpty) return _buildEmptyState(profile);
                  _primeAppLabels(entries);

                  return Column(
                    children: entries
                        .map(
                          (entry) => _ProfileRuleCard(
                            entry: entry,
                            profileEnabled: _profileEnabled,
                            onToggle: (enabled) => _toggleRule(entry, enabled),
                            onTap: () => _editRule(entry),
                            onDelete: () => _deleteRule(entry),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add rule'),
            onPressed: () => _addRule(profile),
          ),
        );
      },
    );
  }

  Widget _buildProfileEditor(Profile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              maxLength: 80,
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
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Profile enabled'),
              subtitle: const Text('Disabled profiles do not activate rules.'),
              value: _profileEnabled,
              onChanged: (enabled) {
                _setProfileDraft(() => _profileEnabled = enabled);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSavingProfile
                    ? null
                    : () => _saveProfileChanges(profile),
                icon: _isSavingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save profile changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledWarning() {
    return Card(
      color: AppTheme.logoPurple.withValues(alpha: 0.1),
      child: const Padding(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile disabled',
              style: TextStyle(
                color: AppTheme.pureBlack,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text('Rules are paused because this profile is off.'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Profile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sectionGap),
        child: Column(
          children: [
            const Icon(Icons.rule_outlined, size: 52, color: AppTheme.logoCyan),
            const SizedBox(height: 16),
            const Text(
              'No rules in this profile yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.pureBlack,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _addRule(profile),
              icon: const Icon(Icons.add),
              label: const Text('Add rule'),
            ),
          ],
        ),
      ),
    );
  }

  void _primeAppLabels(List<RuleWithTriggers> entries) {
    for (final entry in entries) {
      for (final packageName in _appPackagesFor(entry)) {
        if (packageName == null ||
            packageName.isEmpty ||
            appCatalog.cachedEntry(packageName) != null ||
            _loadingAppPackages.contains(packageName)) {
          continue;
        }

        _loadingAppPackages.add(packageName);
        appCatalog.loadAppInfo(packageName).whenComplete(() {
          _loadingAppPackages.remove(packageName);
          if (mounted) setState(() {});
        });
      }
    }
  }

  Iterable<String?> _appPackagesFor(RuleWithTriggers entry) {
    if (entry.triggers.isNotEmpty) {
      return entry.triggers
          .where((trigger) => trigger.triggerType == 2)
          .map((trigger) => trigger.packageName);
    }

    if (entry.rule.type == 2) return [entry.rule.packageName];
    return const [];
  }
}

class _ProfileRuleCard extends StatelessWidget {
  const _ProfileRuleCard({
    required this.entry,
    required this.profileEnabled,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  final RuleWithTriggers entry;
  final bool profileEnabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rule = entry.rule;
    return Card(
      child: InkWell(
        borderRadius: AppTheme.cardBorderRadius,
        onTap: onTap,
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
                          rule.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.pureBlack,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rule.isEnabled ? 'Enabled' : 'Paused',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: rule.isEnabled
                                ? AppTheme.logoBlue
                                : AppTheme.pureBlack.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(value: rule.isEnabled, onChanged: onToggle),
                  Tooltip(
                    message: 'Delete rule',
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: AppTheme.logoPurple,
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ),
              if (!profileEnabled && rule.isEnabled) ...[
                const SizedBox(height: 8),
                Text(
                  'Paused by profile',
                  style: TextStyle(
                    color: AppTheme.logoPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                RuleTriggerSummaryFormatter.ruleSummary(
                  entry,
                  appLabelFor: appCatalog.labelFor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.pureBlack,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    context,
                    'Priority: ${priorityLabel(rule.priority)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.logoBlue),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 96,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppTheme.pureBlack),
        ),
      ),
    );
  }
}
