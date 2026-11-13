import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/services/storage_service.dart';
import 'package:trabalhei/features/proposals/domain/entities/proposal.dart';
import 'package:trabalhei/features/proposals/presentation/widgets/proposal_portfolio_view.dart';

const _file =
    'https://p.supabase.co/storage/v1/object/public/proposal_attachments/u1/j1/a_amostra.pdf';

void main() {
  test('lê links e anexos da proposta, ignorando itens inválidos', () {
    final p = Proposal.fromJson({
      'id': 'p1',
      'portfolio_links': ['https://behance.net/ana', 42],
      'attachments': [
        {'name': 'amostra.pdf', 'url': _file},
        'lixo',
      ],
    });
    expect(p.portfolioLinks, ['https://behance.net/ana']);
    expect(p.attachments.single['name'], 'amostra.pdf');
  });

  test('proposta antiga, sem as colunas, fica vazia', () {
    final p = Proposal.fromJson({'id': 'p1'});
    expect(p.portfolioLinks, isEmpty);
    expect(p.attachments, isEmpty);
  });

  test('amostras da proposta abrem só por URL assinada', () {
    final object = privateStorageObject(_file);
    expect(object?.bucket, 'proposal_attachments');
    expect(object?.path, 'u1/j1/a_amostra.pdf');
  });

  testWidgets('cliente vê os links; sem portfólio, nada aparece', (
    tester,
  ) async {
    Future<void> show(Proposal p) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProposalPortfolioView(proposal: p)),
      ),
    );
    final base = Proposal.fromJson({'id': 'p1'});

    await show(base);
    expect(find.text('Portfólio e amostras:'), findsNothing);

    await show(base.copyWith(portfolioLinks: ['https://github.com/ana']));
    expect(find.text('Portfólio e amostras:'), findsOneWidget);
    expect(find.text('github.com/ana'), findsOneWidget);
  });
}
