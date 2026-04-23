// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple test to check Riverpod setup
void main() {
  test('Simple Riverpod test', () {
    final container = ProviderContainer();
    
    // This should work if Riverpod is set up correctly
    final helloProvider = Provider<String>((ref) => 'hello');
    expect(container.read(helloProvider), 'hello');
    print('✓ Simple Riverpod test passed');
  });
}
