import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/widgets/custom_text_field.dart';
import 'package:trabalhei/core/widgets/field_label.dart';
import 'package:trabalhei/features/auth/domain/password_policy.dart';

void main() {
  test('senha nova diz quanto falta', () {
    expect(validateNewPassword(''), 'Crie uma senha.');
    expect(validateNewPassword('abc12'), contains('faltam 3'));
    expect(validateNewPassword('abcd1234'), isNull);
  });

  testWidgets('a regra da senha aparece antes de digitar e o erro só depois', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: Column(
              children: [
                CustomTextField(
                  controller: controller,
                  label: 'Senha',
                  helperText: passwordHelp,
                  requirement: FieldRequirement.required,
                  obscureText: true,
                  validator: validateNewPassword,
                ),
                const TextField(key: Key('outro')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text(passwordHelp), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.pump();
    expect(find.textContaining('faltam'), findsNothing);

    await tester.tap(find.byKey(const Key('outro')));
    await tester.pump();
    expect(find.textContaining('faltam 5'), findsOneWidget);
  });
}
