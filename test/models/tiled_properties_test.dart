import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

void main() {
  test('returns typed values', () {
    final props = TiledProperties({
      'name': 'test',
      'health': 100,
      'speed': 5.5,
      'active': true,
    });
    expect(props.getString('name'), equals('test'));
    expect(props.getInt('health'), equals(100));
    expect(props.getDouble('speed'), equals(5.5));
    expect(props.getBool('active'), isTrue);
  });

  test('returns null for missing keys', () {
    const props = TiledProperties();
    expect(props.getString('missing'), isNull);
    expect(props.getInt('missing'), isNull);
    expect(props.getDouble('missing'), isNull);
    expect(props.getBool('missing'), isNull);
  });

  test('coerces int to double', () {
    final props = TiledProperties({'v': 3});
    expect(props.getDouble('v'), equals(3.0));
  });

  test('coerces string to types', () {
    final props = TiledProperties({'n': '42', 'f': '1.5', 'b': 'true'});
    expect(props.getInt('n'), equals(42));
    expect(props.getDouble('f'), equals(1.5));
    expect(props.getBool('b'), isTrue);
  });

  test('isEmpty / isNotEmpty', () {
    expect(const TiledProperties().isEmpty, isTrue);
    expect(TiledProperties({'x': 1}).isNotEmpty, isTrue);
  });

  test('toMap returns unmodifiable map', () {
    final props = TiledProperties({'a': 1});
    expect(() => props.toMap()['b'] = 2, throwsUnsupportedError);
  });
}
