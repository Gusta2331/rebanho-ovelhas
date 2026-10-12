# Administração de produtores e planos

O painel administrativo cria usuários pelo Supabase Auth e permite administrar planos e prazos. As credenciais privilegiadas são usadas somente pelas Edge Functions; o aplicativo móvel nunca recebe a `service_role`.

## Configurar Meu plano e Pix

A tela **Meu plano** consulta a atribuição real da fazenda, os dias restantes, o catálogo ativo do Supabase e o histórico de cobranças. Os preços não ficam escritos no Flutter: são lidos de `planos_produtor`, para respeitar os valores atualizados no banco.

1. Aplique as migrations pendentes em ordem, incluindo:
   - `20261013100000_pagamentos_planos_mercado_pago.sql`
   - `20261014100000_meu_plano_pix_seguro.sql`
2. No painel do Supabase, configure o secret `MERCADOPAGO_ACCESS_TOKEN` nas Edge Functions. Comece com as credenciais de teste do Mercado Pago. Nunca coloque esse token no Flutter ou no GitHub.
3. Publique as funções:
   - `supabase functions deploy create-plan-pix`
   - `supabase functions deploy verify-plan-payment`
4. O cliente abre **Mais → Meu plano**, escolhe um plano pago e gera a cobrança Pix. Depois de pagar, toca em **Já paguei, verificar pagamento**. A função do servidor consulta a ordem diretamente no Mercado Pago e confere a referência e o valor antes de ativar o plano por 30 dias.
5. O plano só é atualizado quando a consulta ao Mercado Pago confirma o pagamento. A criação do QR Code, por si só, nunca ativa o plano. Se a cobrança estiver pendente, o cliente pode consultar novamente.

Execute os comandos com o Supabase CLI instalado, depois de entrar e vincular o projeto correto. Também é possível publicar as funções pelo painel do Supabase.

As variáveis `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` são fornecidas pelo ambiente das Edge Functions do Supabase. Não copie a chave `service_role` para o app nem a compartilhe.

## Configuração do administrador

1. Publique a Edge Function `admin-producers` com `supabase functions deploy admin-producers`.
2. Cadastre primeiro no OviGestão a conta que será administradora. Depois configure o secret `ADMIN_EMAILS` com somente o e-mail `ovigestao.app@gmail.com`. Não coloque esse e-mail como regra no código do app. Para manter apenas um administrador, não adicione outros endereços.
3. Atualize o aplicativo. A opção Administração aparece em Mais; o servidor valida o e-mail em cada solicitação.

## Planos e validade

O catálogo comercial atual é definido pela migration `20261011100000_atualiza_planos_produtor.sql`: gratuito até 10 animais; faixas pagas até 100, 200, 300 e assim sucessivamente até 1.000 animais, com preços cadastrados no Supabase; acima disso existe o plano personalizado, cujo preço pode ficar sob consulta. A tela lê os preços ativos diretamente do banco, então alterações feitas no painel não exigem novo build do aplicativo.

O painel administrativo permite definir uma duração personalizada em dias. As contratações via Pix ativam o plano por 30 dias após a confirmação segura do pagamento. O plano gratuito não vence. Quando um plano pago vence, a validação de novos animais passa a respeitar temporariamente o limite de 10 animais, sem apagar os animais existentes.

Para cobrança recorrente automática no Android, será necessário definir os produtos/preços e integrar o fluxo de pagamentos adequado à distribuição na Play Store.
