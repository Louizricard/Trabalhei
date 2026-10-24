import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/services/storage_service.dart';

void main() {
  group('privateStorageObject', () {
    const base = 'https://abc.supabase.co/storage/v1/object';

    test('reconhece arquivo do bucket privado pela URL pública', () {
      final object = privateStorageObject(
        '$base/public/chat_attachments/u1/conv1/arquivo%20final.pdf',
      );
      expect(object?.bucket, 'chat_attachments');
      expect(object?.path, 'u1/conv1/arquivo final.pdf');
    });

    test('reconhece URL já assinada', () {
      final object = privateStorageObject(
        '$base/sign/chat_attachments/u1/deliverables/m1/a.png?token=xyz',
      );
      expect(object?.path, 'u1/deliverables/m1/a.png');
    });

    test('ignora buckets públicos e URLs externas', () {
      expect(privateStorageObject('$base/public/job_covers/u1/c.png'), isNull);
      expect(privateStorageObject('https://example.com/a.png'), isNull);
    });
  });
}
