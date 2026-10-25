import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/features/chat/domain/entities/system_event.dart';

void main() {
  group('systemEventKindOf', () {
    test('classifica pelo início fixo das mensagens do banco', () {
      expect(
        systemEventKindOf('📦 Entrega enviada para o marco "Logo":\n\n"ok"'),
        SystemEventKind.delivery,
      );
      expect(
        systemEventKindOf('🔄 Revisão solicitada no marco "Logo":\n\n"ajuste"'),
        SystemEventKind.revision,
      );
      expect(
        systemEventKindOf('🎉 Marco "Logo" aprovado pelo cliente!'),
        SystemEventKind.approval,
      );
      expect(
        systemEventKindOf('✅ Projeto concluído! Deixe sua avaliação.'),
        SystemEventKind.other,
      );
    });

    test('aprovação de marco chamado "Entrega..." não vira entrega', () {
      expect(
        systemEventKindOf(
          '🎉 Marco "Entrega do projeto" aprovado pelo cliente!',
        ),
        SystemEventKind.approval,
      );
    });

    test('extrai o título do marco citado', () {
      expect(
        milestoneTitleOf('🎉 Marco "Entrega do projeto" aprovado pelo cliente!'),
        'Entrega do projeto',
      );
      expect(
        milestoneTitleOf('📦 Entrega enviada para o marco "Logo":'),
        'Logo',
      );
      expect(milestoneTitleOf('Mensagem comum'), isNull);
    });
  });
}
