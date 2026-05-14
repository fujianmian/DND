import 'package:flutter/material.dart';

import '../models/time_repeat.dart';

typedef TimeRepeatChanged = void Function(int repeatMode, int repeatDaysMask);

class TimeRepeatFields extends StatelessWidget {
  const TimeRepeatFields({
    super.key,
    required this.repeatMode,
    required this.repeatDaysMask,
    required this.onChanged,
    this.contentPadding = EdgeInsets.zero,
  });

  final int repeatMode;
  final int repeatDaysMask;
  final TimeRepeatChanged onChanged;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final normalizedMode = normalizeTimeRepeatMode(repeatMode);
    final normalizedMask = normalizeTimeRepeatDaysMask(
      repeatDaysMask,
      repeatMode: normalizedMode,
    );
    final customMask = normalizedMode == timeRepeatCustom
        ? normalizedMask
        : _repeatTimeMaskOrEveryDay(repeatDaysMask);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: contentPadding,
          child: DropdownButtonFormField<int>(
            initialValue: normalizedMode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Repeat',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: timeRepeatEveryDay,
                child: Text('Every day'),
              ),
              DropdownMenuItem(
                value: timeRepeatWeekdays,
                child: Text('Weekdays'),
              ),
              DropdownMenuItem(
                value: timeRepeatWeekends,
                child: Text('Weekends'),
              ),
              DropdownMenuItem(value: timeRepeatCustom, child: Text('Custom')),
            ],
            onChanged: (value) {
              if (value == null) return;
              final nextMask = value == timeRepeatCustom
                  ? customMask
                  : maskForRepeatMode(value);
              onChanged(value, nextMask);
            },
          ),
        ),
        if (normalizedMode == timeRepeatCustom) ...[
          const SizedBox(height: 8),
          Padding(
            padding: contentPadding,
            child: Text(
              'Choose the days this time condition should run.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: contentPadding,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < timeRepeatDayBits.length; i += 1)
                  ChoiceChip(
                    label: Text(timeRepeatDayLabels[i]),
                    selected: (normalizedMask & timeRepeatDayBits[i]) != 0,
                    onSelected: (selected) {
                      final bit = timeRepeatDayBits[i];
                      final nextMask = selected
                          ? normalizedMask | bit
                          : normalizedMask & ~bit;
                      onChanged(timeRepeatCustom, nextMask);
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

int _repeatTimeMaskOrEveryDay(int daysMask) {
  final normalized = daysMask & timeRepeatEveryDayMask;
  return normalized == 0 ? timeRepeatEveryDayMask : normalized;
}
