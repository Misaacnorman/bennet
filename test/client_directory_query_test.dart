import 'package:bennet/domain/client_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Client sample({
    ClientStatus status = ClientStatus.active,
    String code = 'CL-1',
    String name = 'Acme Co',
    String? legal,
    String? email,
    String? phone,
    String? notes,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Client(
      id: 1,
      bookId: 1,
      clientCode: code,
      displayName: name,
      legalName: legal,
      status: status,
      primaryEmail: email,
      primaryPhone: phone,
      notes: notes,
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  group('Client.matchesClientDirectoryQuery', () {
    test('empty query matches', () {
      final c = sample();
      expect(c.matchesClientDirectoryQuery(''), isTrue);
    });

    test('matches display name and code', () {
      expect(sample(name: 'River Tours').matchesClientDirectoryQuery('river'), isTrue);
      expect(sample(code: 'CL-99').matchesClientDirectoryQuery('cl-99'), isTrue);
    });

    test('matches legal name email phone notes', () {
      expect(
        sample(legal: 'Acme Holdings LLC').matchesClientDirectoryQuery('holdings'),
        isTrue,
      );
      expect(
        sample(email: 'Billing@Example.COM').matchesClientDirectoryQuery('billing'),
        isTrue,
      );
      expect(
        sample(phone: '+1 555 0100').matchesClientDirectoryQuery('555'),
        isTrue,
      );
      expect(
        sample(notes: 'prefers monthly PDF').matchesClientDirectoryQuery('pdf'),
        isTrue,
      );
    });

    test('non-match', () {
      expect(sample(name: 'Beta').matchesClientDirectoryQuery('gamma'), isFalse);
    });
  });
}
