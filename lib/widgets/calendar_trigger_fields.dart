import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CalendarTriggerFields extends StatelessWidget {
  const CalendarTriggerFields({
    super.key,
    required this.connected,
    required this.isConnecting,
    required this.includeAllDay,
    required this.onIncludeAllDayChanged,
    required this.keyword,
    required this.onKeywordChanged,
    required this.onConnect,
    this.email,
  });

  final bool connected;
  final bool isConnecting;
  final bool includeAllDay;
  final ValueChanged<bool> onIncludeAllDayChanged;
  final String? keyword;
  final ValueChanged<String> onKeywordChanged;
  final VoidCallback onConnect;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final statusText = connected && email != null
        ? 'Connected as $email'
        : connected
        ? 'Connected'
        : 'Not connected';

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            connected ? Icons.event_available : Icons.event_busy,
            color: connected ? AppTheme.logoBlue : AppTheme.logoPurple,
          ),
          title: const Text('Google Calendar'),
          subtitle: Text(statusText),
          trailing: connected
              ? const Icon(Icons.check_circle, color: AppTheme.logoCyan)
              : TextButton(
                  onPressed: isConnecting ? null : onConnect,
                  child: isConnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect'),
                ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.today, color: AppTheme.logoBlue),
          title: const Text('Include all-day events'),
          subtitle: const Text('Off by default for meeting-based automation.'),
          value: includeAllDay,
          onChanged: onIncludeAllDayChanged,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('calendar-keyword-${keyword ?? ''}'),
          initialValue: keyword,
          decoration: const InputDecoration(
            labelText: 'Title keyword filter',
            hintText: 'Optional, e.g. meeting, exam, class',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          textInputAction: TextInputAction.done,
          onChanged: onKeywordChanged,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 18,
              color: AppTheme.pureBlack.withValues(alpha: 0.62),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Quietly caches only busy windows. Event details are not stored.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.pureBlack.withValues(alpha: 0.62),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
