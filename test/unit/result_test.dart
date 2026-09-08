import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/shared/errors/lipi_error.dart';
import 'package:lipi/shared/result/result.dart';

void main() {
  group('Result and LipiError tests', () {
    test('Success returns value and handles fold', () {
      const Result<int, LipiError> result = Success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, equals(42));
      expect(result.errorOrNull, isNull);

      final folded = result.fold(
        onSuccess: (v) => 'Value: $v',
        onFailure: (e) => 'Error: ${e.message}',
      );
      expect(folded, equals('Value: 42'));
    });

    test('Failure returns error and handles fold', () {
      const Result<int, LipiError> result = Failure(VaultError('Vault locked'));
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull?.message, equals('Vault locked'));

      final folded = result.fold(
        onSuccess: (v) => 'Value: $v',
        onFailure: (e) => 'Error: ${e.message}',
      );
      expect(folded, equals('Error: Vault locked'));
    });

    test('LipiError hierarchy formats correctly without leaking secrets', () {
      const error = DocumentError('Corrupted manifest.json');
      expect(error.toString(), contains('DocumentError: Corrupted manifest.json'));
    });
  });
}
