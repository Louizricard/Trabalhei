import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_client.dart';
import '../../data/datasources/chat_remote_data_source.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';

final chatDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSource(ref.watch(supabaseClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(chatDataSourceProvider));
});

final conversationsListProvider = FutureProvider<List<Conversation>>((
  ref,
) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getConversations();
});

final conversationDetailProvider = FutureProvider.family<Conversation?, String>(
  (ref, id) async {
    final repository = ref.watch(chatRepositoryProvider);
    return repository.getConversationById(id);
  },
);

final chatMessagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
      final repository = ref.watch(chatRepositoryProvider);
      return repository.getMessagesStream(conversationId);
    });
