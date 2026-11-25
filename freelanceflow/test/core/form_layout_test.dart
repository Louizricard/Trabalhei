import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/widgets/adaptive_pair.dart';
import 'package:trabalhei/core/widgets/custom_button.dart';
import 'package:trabalhei/core/widgets/custom_text_field.dart';

Widget _app(Widget child, {double width = 400, double textScale = 1}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    ),
  );
}

void main() {
  group('Campo de valor em reais', () {
    testWidgets('mostra R\$ com o campo vazio e completa os centavos ao sair', (
      tester,
    ) async {
      final money = TextEditingController();
      final other = TextEditingController();
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              CustomTextField(controller: money, label: 'Valor', money: true),
              CustomTextField(controller: other, label: 'Outro'),
            ],
          ),
        ),
      );
      expect(find.text('R\$'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '1500');
      expect(money.text, '1.500');
      await tester.tap(find.byType(TextFormField).last);
      await tester.pump();
      expect(money.text, '1.500,00');
    });
  });

  group('AdaptivePair', () {
    Widget pair() => const AdaptivePair(
      first: Text('A', key: Key('a')),
      second: Text('B', key: Key('b')),
    );

    testWidgets('fica lado a lado quando cabe', (tester) async {
      await tester.pumpWidget(_app(pair(), width: 600));
      final a = tester.getTopLeft(find.byKey(const Key('a')));
      final b = tester.getTopLeft(find.byKey(const Key('b')));
      expect(a.dy, b.dy);
    });

    testWidgets('empilha com letra grande na mesma largura', (tester) async {
      await tester.pumpWidget(_app(pair(), width: 600, textScale: 1.5));
      final a = tester.getTopLeft(find.byKey(const Key('a')));
      final b = tester.getTopLeft(find.byKey(const Key('b')));
      expect(b.dy, greaterThan(a.dy));
    });
  });

  testWidgets('botão estreito não transborda o rótulo', (tester) async {
    await tester.pumpWidget(
      _app(
        const CustomButton(
          text: 'Um rótulo bem comprido para um botão estreito',
          icon: Icons.send_rounded,
          width: 140,
          onPressed: null,
        ),
        width: 140,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
