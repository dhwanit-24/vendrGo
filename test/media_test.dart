import 'package:flutter_test/flutter_test.dart';
import 'package:vendr_go/services/media_service.dart';

void main() {
  group('MediaService.urlFor', () {
    test('returns null when there is no photo', () {
      expect(MediaService.urlFor(null), isNull);
      expect(MediaService.urlFor(''), isNull);
      expect(MediaService.urlFor('   '), isNull);
    });

    test('keeps full web links as they are', () {
      expect(
        MediaService.urlFor('https://example.com/photo.jpg'),
        'https://example.com/photo.jpg',
      );
    });
  });

  test('compression settings keep photos small', () {
    expect(MediaService.maxDimension, lessThanOrEqualTo(1280));
    expect(MediaService.jpegQuality, lessThanOrEqualTo(75));
  });
}
