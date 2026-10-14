# Configuração do Fale com o OviGestão

A tela salva cada mensagem no Supabase e armazena as imagens em um bucket privado. A notificação para `ovigestao.app@gmail.com` é enviada pela Edge Function `notify-support-message`. A chave de serviço do Supabase e a chave do provedor de e-mail ficam somente nos secrets do backend.

## 1. Aplicar a migration

Na pasta do projeto, com o Supabase CLI instalado e vinculado ao projeto correto:

```powershell
supabase db push
```

A migration `20261020100000_mensagens_suporte.sql` cria a tabela de mensagens, políticas RLS e o bucket privado `support-attachments`. Confira as migrations pendentes antes de confirmar a aplicação.

## 2. Configurar o envio de e-mail

A função usa o serviço Resend. Crie uma API key no Resend e configure os secrets da Edge Function no painel do Supabase em **Edge Functions → Secrets**, ou pelo CLI:

```powershell
supabase secrets set RESEND_API_KEY=re_sua_chave
supabase secrets set RESEND_FROM_EMAIL="OviGestão <suporte@SEU-DOMINIO-VERIFICADO>"
```

Substitua os valores pelos seus dados reais. O endereço usado em `RESEND_FROM_EMAIL` precisa pertencer a um domínio verificado no Resend. Não use uma chave de teste nem coloque esses valores no Flutter ou no GitHub. O destinatário já está definido no backend como `ovigestao.app@gmail.com`.

O Supabase fornece `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` ao ambiente das Edge Functions.

## 3. Publicar a função

```powershell
supabase functions deploy notify-support-message
```

A função exige uma sessão autenticada. Ela verifica se a mensagem pertence ao usuário que fez a chamada, gera links temporários para as imagens privadas e envia o aviso por e-mail. Os links expiram após 7 dias; a mensagem e os anexos continuam armazenados no Supabase.

## 4. Atualizar e validar o aplicativo

```powershell
git pull origin feature/cadastro-plano-gratuito
flutter pub get
flutter analyze
```

Teste com uma conta de usuário: envie uma mensagem sem anexos, depois outra com imagens JPG, PNG ou WEBP. São aceitas até 3 imagens, cada uma com no máximo 5 MB. Confira a linha em `mensagens_suporte`, os objetos no bucket privado e o e-mail recebido.

Se o aviso por e-mail falhar, a mensagem continua salva no Supabase. O aplicativo informa que o relato foi registrado, para evitar que a pessoa envie várias cópias.
