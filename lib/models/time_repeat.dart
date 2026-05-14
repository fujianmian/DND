const int timeRepeatEveryDay = 0;
const int timeRepeatWeekdays = 1;
const int timeRepeatWeekends = 2;
const int timeRepeatCustom = 3;

const int timeRepeatMondayBit = 1 << 0;
const int timeRepeatTuesdayBit = 1 << 1;
const int timeRepeatWednesdayBit = 1 << 2;
const int timeRepeatThursdayBit = 1 << 3;
const int timeRepeatFridayBit = 1 << 4;
const int timeRepeatSaturdayBit = 1 << 5;
const int timeRepeatSundayBit = 1 << 6;

const int timeRepeatEveryDayMask = 127;
const int timeRepeatWeekdaysMask = 31;
const int timeRepeatWeekendsMask = 96;

const List<int> timeRepeatDayBits = [
  timeRepeatMondayBit,
  timeRepeatTuesdayBit,
  timeRepeatWednesdayBit,
  timeRepeatThursdayBit,
  timeRepeatFridayBit,
  timeRepeatSaturdayBit,
  timeRepeatSundayBit,
];

const List<String> timeRepeatDayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

int normalizeTimeRepeatMode(int? repeatMode) {
  switch (repeatMode) {
    case timeRepeatEveryDay:
    case timeRepeatWeekdays:
    case timeRepeatWeekends:
    case timeRepeatCustom:
      return repeatMode!;
    default:
      return timeRepeatEveryDay;
  }
}

int maskForRepeatMode(int? repeatMode) {
  switch (normalizeTimeRepeatMode(repeatMode)) {
    case timeRepeatWeekdays:
      return timeRepeatWeekdaysMask;
    case timeRepeatWeekends:
      return timeRepeatWeekendsMask;
    case timeRepeatCustom:
      return 0;
    case timeRepeatEveryDay:
    default:
      return timeRepeatEveryDayMask;
  }
}

int normalizeTimeRepeatDaysMask(int? daysMask, {int? repeatMode}) {
  final mode = normalizeTimeRepeatMode(repeatMode);
  if (mode != timeRepeatCustom) return maskForRepeatMode(mode);
  return (daysMask ?? 0) & timeRepeatEveryDayMask;
}

bool isValidCustomDaysMask(int? daysMask) {
  return ((daysMask ?? 0) & timeRepeatEveryDayMask) != 0;
}

String repeatLabel(int? repeatMode, {int? daysMask}) {
  switch (normalizeTimeRepeatMode(repeatMode)) {
    case timeRepeatWeekdays:
      return 'weekdays';
    case timeRepeatWeekends:
      return 'weekends';
    case timeRepeatCustom:
      return repeatDaysLabel(daysMask);
    case timeRepeatEveryDay:
    default:
      return 'every day';
  }
}

String repeatDaysLabel(int? daysMask) {
  final normalized = (daysMask ?? 0) & timeRepeatEveryDayMask;
  if (normalized == timeRepeatEveryDayMask) return 'every day';
  if (normalized == timeRepeatWeekdaysMask) return 'weekdays';
  if (normalized == timeRepeatWeekendsMask) return 'weekends';
  if (normalized == 0) return 'custom days';

  final labels = <String>[];
  for (var i = 0; i < timeRepeatDayBits.length; i += 1) {
    if ((normalized & timeRepeatDayBits[i]) != 0) {
      labels.add(timeRepeatDayLabels[i]);
    }
  }
  return labels.join('/');
}
