import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trabalhei/features/jobs/domain/entities/job.dart';
import 'package:trabalhei/features/jobs/presentation/widgets/job_card.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('no celular o card tem a altura do conteúdo, sem espaço vazio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final job = Job.fromJson({
      'id': 'j1',
      'client_id': 'c1',
      'title': 'Maquete para um trabalho de robótica',
      'category': 'DevOps',
      'description': 'Preciso de uma maquete.',
      'budget_min': 100,
      'budget_max': 2000,
      'status': 'open',
      'skills_required': ['arduino'],
      'created_at': '2026-10-01T10:00:00Z',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [JobCard(job: job, onApply: () {})],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final height = tester.getSize(find.byType(JobCard)).height;
    // Antes o card ocupava 560 px fixos na lista do celular.
    expect(height, lessThan(460));
  });
}
