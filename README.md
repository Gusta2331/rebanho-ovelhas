# OviGestão

Aplicativo Flutter para gestão de rebanhos ovinos, desenvolvido para a Fazenda Baixinha.

## Recursos

- Cadastro e histórico de animais, lotes e transferências.
- Reprodução, montas, coberturas e nascimentos.
- Manejos sanitários, agenda, FAMACHA, pesagens e farmácia.
- Receitas, despesas e vendas de animais.
- Cache local e fila de sincronização para operações compatíveis com uso offline.
- Login e persistência de dados no Supabase.

## Requisitos

- Flutter compatível com o SDK definido em `pubspec.yaml`.
- Projeto Supabase configurado com as tabelas, políticas e funções SQL do diretório `supabase/migrations/`.

## Executar

Instale as dependências:

```sh
flutter pub get
```

Execute informando a URL e a chave publicável do seu projeto Supabase:

```sh
flutter run --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICAVEL
```

Não grave chaves privadas ou `service_role` no aplicativo. O app deve receber somente a chave publicável, com as políticas de acesso do Supabase configuradas.

## Banco de dados

As migrations em `supabase/migrations/` incluem o esquema adicional usado pelos módulos de manejo, vendas, farmácia, financeiro e sincronização offline. Aplique cada migration ao projeto Supabase antes de usar os fluxos correspondentes.

## Recuperação de senha por código

No painel do Supabase, abra **Authentication → Email Templates → Reset Password** e ajuste o conteúdo do e-mail para incluir `{{ .Token }}`. Exemplo:

```html
<h2>Recuperar senha do OviGestão</h2>
<p>Use este código no aplicativo para criar uma nova senha:</p>
<p>{{ .Token }}</p>
<p>Se você não solicitou a recuperação, ignore este e-mail.</p>
```

O aplicativo valida o código de recuperação e permite cadastrar uma nova senha. Sem essa configuração, o template padrão pode enviar um link em vez do código numérico esperado pela tela.

## Verificação estática

```sh
flutter analyze
```
