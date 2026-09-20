import 'package:flutter_test/flutter_test.dart';

import 'package:rebanho_app/app/app.dart';

void main() {
  testWidgets('Aplicativo Fazenda Baixinha inicia corretamente', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FazendaBaixinhaApp());

    expect(find.text('Fazenda Baixinha'), findsOneWidget);
    expect(find.text('Gestão inteligente do seu rebanho'), findsOneWidget);
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });
}
