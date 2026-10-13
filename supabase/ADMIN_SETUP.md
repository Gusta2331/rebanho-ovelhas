# Administração de produtores e planos

O painel administrativo cria usuários pelo Supabase Auth e permite administrar planos e prazos. As credenciais privilegiadas são usadas somente pelas Edge Functions; o aplicativo móvel nunca recebe a `service_role`.

## Configurar Meu plano, Pix, cartão de crédito e confirmação automática

A tela **Meu plano** consulta a atribuição real da fazenda, os dias restantes, o catálogo ativo do Supabase e o histórico de cobranças. Os preços não ficam escritos no Flutter: são lidos de `planos_produtor`, para respeitar os valores atualizados no banco.

1. Aplique as migrations pendentes em ordem, incluindo:
   - `20261013100000_pagamentos_planos_mercado_pago.sql`
   - `20261014100000_meu_plano_pix_seguro.sql`
   - `20261015100000_meio_pagamento_cartao_credito.sql`
   - `20261016100000_duracao_pagamentos_planos.sql`
2. No painel do Supabase, configure os secrets das Edge Functions. Comece com as credenciais de teste do Mercado Pago:
   - `MERCADOPAGO_ACCESS_TOKEN`: Access Token da aplicação no ambiente correspondente.
   - `MERCADOPAGO_WEBHOOK_SECRET`: assinatura secreta gerada em **Mercado Pago Developers → sua aplicação → Webhooks → Configurar notificações**. Não é o Access Token.
   
   Nunca coloque esses valores no Flutter ou no GitHub.
3. Publique as funções:
   - `supabase functions deploy create-plan-pix`
   - `supabase functions deploy create-plan-card-checkout`
   - `supabase functions deploy verify-plan-payment`
   - `supabase functions deploy mercadopago-webhook`
4. No painel do Mercado Pago Developers, abra a aplicação do OviGestão e configure Webhooks para o **ambiente de teste**. Use como URL:
   `https://ezbfjgozqwzricjwxtba.supabase.co/functions/v1/mercadopago-webhook`
   
   Ative o evento **Orders (Mercado Pago)** / tópico `orders`, salve e copie a assinatura secreta gerada para o secret `MERCADOPAGO_WEBHOOK_SECRET` no Supabase. A URL de teste deve ser configurada com credenciais de teste. Quando for para produção, configure a URL e a assinatura correspondentes ao ambiente de produção separadamente.
5. O webhook valida a assinatura HMAC do Mercado Pago e depois consulta a ordem diretamente na API do provedor. Só ativa o plano se a referência, o valor e o estado da ordem/transação conferirem. A função SQL é idempotente: receber novamente a mesma notificação não deve renovar o prazo de um pagamento já aprovado.
6. O cliente pode continuar usando **Já paguei, verificar pagamento** como verificação manual/fallback. Com o webhook configurado, a atualização normalmente acontece sem o cliente precisar voltar e tocar nesse botão. A confirmação pode levar alguns instantes; notificações também podem ser reenviadas pelo provedor.

Execute os comandos com o Supabase CLI instalado, depois de entrar e vincular o projeto correto. Também é possível publicar as funções pelo painel do Supabase. A seção `[functions.mercadopago-webhook]` em `supabase/config.toml` desativa a exigência de JWT do Supabase apenas para esse endpoint público; a própria função exige e valida a assinatura do Mercado Pago.

As variáveis `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` são fornecidas pelo ambiente das Edge Functions do Supabase. Não copie a chave `service_role` para o app nem a compartilhe.

## Configuração do administrador

1. Publique a Edge Function `admin-producers` com `supabase functions deploy admin-producers`.
2. Cadastre primeiro no OviGestão a conta que será administradora. Depois configure o secret `ADMIN_EMAILS` com somente o e-mail `ovigestao.app@gmail.com`. Não coloque esse e-mail como regra no código do app. Para manter apenas um administrador, não adicione outros endereços.
3. Atualize o aplicativo. A opção Administração aparece em Mais; o servidor valida o e-mail em cada solicitação.

## Planos e validade

O catálogo comercial inicial continua registrado na migration `20261011100000_atualiza_planos_produtor.sql`. A migration `20261012100000_novas_faixas_planos_50_animais.sql` atualiza o catálogo para: grátis até 10 animais; R$ 9,99 até 50; R$ 14,99 até 100; R$ 19,99 até 150; e acréscimo de R$ 5,00 por faixa adicional de 50 animais até 1.000. Acima de 1.000 animais, o plano personalizado fica sob consulta. Não há promoções ou cupons previstos. Os planos antigos permanecem no banco para preservar referências históricas; as atribuições atuais são migradas para a faixa equivalente, sem alterar a validade.

O painel administrativo permite definir uma duração personalizada em dias. As contratações via Pix e cartão de crédito registram a duração da cobrança em `pagamentos_planos.duracao_dias`, com padrão de 30 dias. A função de ativação usa essa duração ao iniciar ou estender a validade e continua ignorando notificações repetidas de um pagamento já aprovado. O painel administrativo pode definir uma validade personalizada diretamente na atribuição do plano; essa alteração não muda a duração padrão das próximas cobranças. O plano gratuito não vence. Quando um plano pago vence, a validação de novos animais passa a respeitar temporariamente o limite de 10 animais, sem apagar os animais existentes.

**Importante:** o upgrade com cobrança proporcional e preservação dos dias restantes ainda precisa ser implementado antes de oferecer a troca de plano aos clientes. Até lá, não habilite mudanças de plano pagas no fluxo do cliente sem uma regra explícita de migração de validade.

Para cobrança recorrente automática no Android, será necessário definir os produtos/preços e integrar o fluxo de pagamentos adequado à distribuição na Play Store.
