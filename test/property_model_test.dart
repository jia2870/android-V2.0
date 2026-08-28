import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_asg/models/property_model.dart';

void main() {
  test('photoUrlList keeps Unsplash and listing CDNs, drops hive-ui junk', () {
    final property = PropertyModel(
      listingId: 't1',
      photoUrls: [
        'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=80',
        'https://my1-cdn.pgimgs.com/listing/abc.jpg',
        'https://cdn.pgimgs.com/hive-ui/static/placeholder.png',
        'not-a-url',
        'https://cdn.pgimgs.com/hive-ui/foo.png',
      ].join('|'),
    );

    expect(property.photoUrlList, [
      'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=80',
      'https://my1-cdn.pgimgs.com/listing/abc.jpg',
    ]);
  });
}
