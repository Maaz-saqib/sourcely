import 'package:flutter_test/flutter_test.dart';
import 'package:sourcely/models/source.dart';

void main() {
  group('Source Model Tests', () {
    test('Source correctly parses from JSON', () {
      final json = {
        'id': '123',
        'knowledge_space_id': 'space_1',
        'type': 'pdf',
        'original_name': 'test.pdf',
        'status': 'ready',
        'chunk_count': 10,
        'created_at': '2023-01-01T00:00:00Z',
      };

      final source = Source.fromJson(json);

      expect(source.id, '123');
      expect(source.knowledgeSpaceId, 'space_1');
      expect(source.type, 'pdf');
      expect(source.originalName, 'test.pdf');
      expect(source.status, 'ready');
      expect(source.chunkCount, 10);
      expect(source.isReady, isTrue);
      expect(source.isProcessing, isFalse);
      expect(source.isFailed, isFalse);
      expect(source.typeIcon, '📄');
    });

    test('Source displayName fallback logic', () {
      final sourceWithName = Source(
        id: '1',
        knowledgeSpaceId: 's1',
        type: 'url',
        status: 'ready',
        createdAt: '2023-01-01',
        originalName: 'My Web Page',
        sourceUrl: 'https://example.com',
      );
      expect(sourceWithName.displayName, 'My Web Page');

      final sourceWithUrl = Source(
        id: '1',
        knowledgeSpaceId: 's1',
        type: 'url',
        status: 'ready',
        createdAt: '2023-01-01',
        sourceUrl: 'https://example.com',
      );
      expect(sourceWithUrl.displayName, 'https://example.com');

      final sourceWithNothing = Source(
        id: '1',
        knowledgeSpaceId: 's1',
        type: 'url',
        status: 'ready',
        createdAt: '2023-01-01',
      );
      expect(sourceWithNothing.displayName, 'Unknown Source');
    });

    test('Source type icons', () {
      expect(Source(id: '1', knowledgeSpaceId: 's1', type: 'pdf', status: 'ready', createdAt: '').typeIcon, '📄');
      expect(Source(id: '1', knowledgeSpaceId: 's1', type: 'docx', status: 'ready', createdAt: '').typeIcon, '📝');
      expect(Source(id: '1', knowledgeSpaceId: 's1', type: 'youtube', status: 'ready', createdAt: '').typeIcon, '▶️');
      expect(Source(id: '1', knowledgeSpaceId: 's1', type: 'url', status: 'ready', createdAt: '').typeIcon, '🌐');
      expect(Source(id: '1', knowledgeSpaceId: 's1', type: 'unknown', status: 'ready', createdAt: '').typeIcon, '📎');
    });
  });
}
