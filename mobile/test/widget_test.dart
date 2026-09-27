import 'package:flutter_test/flutter_test.dart';
import 'package:resource_distribution_app/main.dart';

void main() {
  test('category labels are readable', () {
    expect(pretty('LIKE_NEW'), 'Like New');
    expect(pretty('FOOD'), 'Food');
  });
}
