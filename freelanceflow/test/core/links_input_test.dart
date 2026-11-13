import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabalhei/core/widgets/link_chips.dart';
import 'package:trabalhei/core/widgets/links_input.dart';

void main() {
  group('linkError', () {
    test('aceita link sem protocolo e recusa texto inválido', () {
      expect(linkError('behance.net/ana', const [], 10), isNull);
      expect(linkError('meu portfolio', const [], 10), isNotNull);
      expect(linkError('  ', const [], 10), contains('Cole um link'));
    });

    test('recusa repetido sem diferenciar maiúsculas', () {
      final error = linkError('HTTPS://Behance.net/Ana', const [
        'https://behance.net/ana',
      ], 10);
      expect(error, 'Este link já está na lista.');
    });

    test('respeita o limite', () {
      final full = [for (var i = 0; i < 3; i++) 'https://site$i.com'];
      expect(linkError('https://outro.com', full, 3), contains('até 3'));
    });
  });

  test('linkKind identifica o tipo pelo domínio', () {
    expect(linkKind('https://github.com/ana').label, 'GitHub');
    expect(linkKind('https://www.behance.net/ana').label, 'Behance');
    expect(linkKind('https://youtu.be/x').label, 'Vídeo');
    expect(linkKind('https://notgithub.com').label, 'Site');
  });

  testWidgets('adiciona com https://, remove e avisa repetido', (tester) async {
    var links = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => LinksInput(
              links: links,
              onChanged: (v) => setState(() => links = v),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('links-input-field')),
      'dribbble.com/ana',
    );
    await tester.tap(find.byKey(const Key('links-input-add')));
    await tester.pump();
    expect(links, ['https://dribbble.com/ana']);
    expect(find.text('Dribbble'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('links-input-field')),
      'https://dribbble.com/ana',
    );
    await tester.tap(find.byKey(const Key('links-input-add')));
    await tester.pump();
    expect(find.text('Este link já está na lista.'), findsOneWidget);
    expect(links, hasLength(1));

    await tester.tap(find.byTooltip('Remover link'));
    await tester.pump();
    expect(links, isEmpty);
  });

  testWidgets('LinkChips mostra o endereço curto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LinkChips(links: ['https://www.github.com/ana/app']),
        ),
      ),
    );
    expect(find.text('github.com/ana/app'), findsOneWidget);
  });
}
