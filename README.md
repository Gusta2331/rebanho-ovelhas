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

O endereço do projeto e a chave pública do Supabase ficam em
`lib/core/config/supabase_config.dart`. O aplicativo usa somente a chave
publicável (`sb_publishable_...`) ou a chave pública legada `anon`; nunca use a
chave `service_role` no aplicativo.

Execute o aplicativo:

```sh
flutter run
```

As tabelas e políticas de acesso do Supabase devem estar configuradas para o projeto.

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

## Atualização do aplicativo Android

O aplicativo verifica ao abrir se existe uma versão mais recente publicada em **GitHub → Releases** deste repositório. Quando encontra uma versão nova com o arquivo `app-release.apk`, mostra um aviso, permite baixar com indicador de progresso e abre o instalador do Android. O Android sempre exige a confirmação da pessoa para instalar o APK; em alguns aparelhos também será necessário permitir a instalação pelo aplicativo de origem.

Para publicar uma atualização:

1. Incremente a versão em `pubspec.yaml`. Exemplo: `version: 1.0.1+2` (a parte antes de `+` é a versão exibida; o número depois de `+` deve aumentar a cada APK).
2. No mesmo computador que assina a versão instalada, execute `flutter pub get` e `flutter build apk --release`.
3. O APK será gerado em `build/app/outputs/flutter-apk/app-release.apk`.
4. No GitHub, abra **Releases → Draft a new release**. Use uma tag correspondente à versão, por exemplo `v1.0.1`, escreva as novidades e anexe o APK com o nome exato `app-release.apk`.
5. Publique a release como versão estável, não como rascunho ou pré-lançamento.

**Importante sobre assinatura:** toda atualização precisa ser assinada com a mesma chave da versão já instalada. Não apague nem perca o arquivo de assinatura/keystore. O Gradle do projeto usa `android/key.properties` e o keystore configurado nele quando esse arquivo existe; sem ele, atualmente usa a chave de depuração local, que não deve ser usada para distribuir versões públicas. Antes de distribuir para mais pessoas, configure e guarde uma chave de lançamento permanente e faça a primeira instalação pública com ela.

A verificação de atualização depende de internet, mas uma falha ao consultar o GitHub não impede o usuário de abrir o aplicativo. A primeira release com APK precisa ser publicada antes que o aviso de atualização possa aparecer.
