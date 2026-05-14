import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/utils/saved_location_validation.dart';

void main() {
  group('cleanSavedLocationName', () {
    test('trims valid names', () {
      expect(cleanSavedLocationName('  Library  '), 'Library');
    });

    test('rejects empty names', () {
      expect(cleanSavedLocationName('   '), isNull);
      expect(cleanSavedLocationName(null), isNull);
    });
  });
}
