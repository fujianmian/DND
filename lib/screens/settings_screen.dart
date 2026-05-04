import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Mock state for settings
  bool _isEmergencyBypassEnabled = true;
  bool _isLocationEnabled = true;
  bool _isAppUsageEnabled = false;

  final List<String> _bypassKeywords = ['Urgent', 'Emergency', 'Wife'];
  final TextEditingController _keywordController = TextEditingController();

  void _addKeyword(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !_bypassKeywords.contains(trimmed)) {
      setState(() {
        _bypassKeywords.add(trimmed);
      });
      _keywordController.clear();
    }
  }

  void _removeKeyword(String keyword) {
    setState(() {
      _bypassKeywords.remove(keyword);
    });
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildEmergencyBypassSection(colorScheme),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(indent: 24, endIndent: 24, height: 32),
          ),
          _buildPermissionsSection(colorScheme),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(indent: 24, endIndent: 24, height: 32),
          ),
          _buildAboutSection(colorScheme),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: GLOBAL EMERGENCY BYPASS
  // ===========================================================================
  Widget _buildEmergencyBypassSection(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        // Soft tonal background distinct from the pure white cards
        color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text(
                  'Emergency Bypass',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Allow notifications containing specific keywords to bypass DND.',
                ),
                value: _isEmergencyBypassEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _isEmergencyBypassEnabled = value;
                  });
                },
                secondary: Icon(
                  Icons.warning_amber_rounded,
                  color: _isEmergencyBypassEnabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),

              // Keyword Input & Chips
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isEmergencyBypassEnabled ? null : 0,
                curve: Curves.easeInOut,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _bypassKeywords.map((keyword) {
                          return InputChip(
                            label: Text(keyword),
                            onDeleted: () => _removeKeyword(keyword),
                            deleteIconColor: colorScheme.onSecondaryContainer,
                            backgroundColor: colorScheme.secondaryContainer,
                            labelStyle: TextStyle(
                              color: colorScheme.onSecondaryContainer,
                            ),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _keywordController,
                        decoration: InputDecoration(
                          hintText: 'Add keyword (e.g., "Boss")',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withOpacity(
                              0.7,
                            ),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle),
                            color: colorScheme.primary,
                            onPressed: () =>
                                _addKeyword(_keywordController.text),
                          ),
                        ),
                        onSubmitted: _addKeyword,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: PERMISSIONS & PRIVACY
  // ===========================================================================
  Widget _buildPermissionsSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Permissions',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _buildPermissionTile(
          title: 'Location (Geofencing)',
          subtitle: 'Required for location-based rules.',
          icon: Icons.location_on_outlined,
          value: _isLocationEnabled,
          onChanged: (val) => setState(() => _isLocationEnabled = val),
        ),
        _buildPermissionTile(
          title: 'App Usage Access',
          subtitle: 'Required to trigger rules when apps open.',
          icon: Icons.app_settings_alt_outlined,
          value: _isAppUsageEnabled,
          onChanged: (val) => setState(() => _isAppUsageEnabled = val),
        ),
      ],
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      secondary: Icon(icon),
      title: Row(
        children: [Text(title), const SizedBox(width: 8), _buildPrivacyBadge()],
      ),
      subtitle: Text(subtitle),
    );
  }

  // Custom Green Privacy Badge
  Widget _buildPrivacyBadge() {
    // Hardcoded subtle green to strictly enforce the "trust" aesthetic
    // independently of the current theme's primary color.
    const badgeColor = Color(0xFFE8F5E9);
    const textColor = Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 10, color: textColor),
          SizedBox(width: 4),
          Text(
            'Processed Locally',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 3: ABOUT (Standard filler for settings)
  // ===========================================================================
  Widget _buildAboutSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'About',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.info_outline),
          title: const Text('Version'),
          trailing: Text(
            '1.0.0-beta',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
