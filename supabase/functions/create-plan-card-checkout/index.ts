import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (request.method !== 'POST') return json({ error: 'Método não permitido.' }, 405)

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const mercadoPagoToken = Deno.env.get('MERCADOPAGO_ACCESS_TOKEN')

    if (!supabaseUrl || !anonKey || !serviceKey || !mercadoPagoToken) {
      return json({ error: 'A integração de pagamentos ainda não está configurada no servidor.' }, 500)
    }

    const accessToken = request.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1]
    if (!accessToken) return json({ error: 'Faça login para contratar um plano.' }, 401)

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: { user }, error: authError } = await authClient.auth.getUser(accessToken)
    if (authError || !user?.id || !user.email) return json({ error: 'Sessão inválida.' }, 401)

    const payload = await request.json().catch(() => ({}))
    const planId = String(payload.plano_id ?? '').trim()
    if (!planId) return json({ error: 'Selecione um plano.' }, 400)

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: plan, error: planError } = await admin
      .from('planos_produtor')
      .select('id,nome,preco_mensal,ativo')
      .eq('id', planId)
      .eq('ativo', true)
      .maybeSingle()

    if (planError) throw planError
    if (!plan) return json({ error: 'O plano selecionado não existe ou está indisponível.' }, 400)

    const amount = Number(plan.preco_mensal)
    if (!Number.isFinite(amount) || amount <= 0) {
      return json({ error: 'Este plano não possui preço válido para pagamento.' }, 400)
    }

    const { data: payment, error: insertError } = await admin
      .from('pagamentos_planos')
      .insert({
        usuario_id: user.id,
        plano_id: plan.id,
        valor: amount,
        metodo: 'cartao_credito',
        status: 'criado',
      })
      .select('id')
      .single()

    if (insertError) throw insertError

    const orderResponse = await fetch('https://api.mercadopago.com/v1/orders', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${mercadoPagoToken}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Idempotency-Key': payment.id,
      },
      body: JSON.stringify({
        type: 'online',
        processing_mode: 'manual',
        capture_mode: 'automatic_async',
        total_amount: amount.toFixed(2),
        external_reference: payment.id,
        description: `Plano OviGestão: ${plan.nome}`,
        expiration_time: 'P1D',
        payer: { email: user.email },
        items: [{
          title: `Plano OviGestão: ${plan.nome}`,
          quantity: 1,
          unit_price: amount.toFixed(2),
          total_amount: amount.toFixed(2),
          unit_measure: 'unit',
        }],
        config: {
          online: {
            retries: { allowed: false },
          },
          payment_method: {
            default_type: 'credit_card',
            max_installments: 12,
            not_allowed_types: [
              'debit_card',
              'prepaid_card',
              'ticket',
              'bank_transfer',
              'atm',
              'digital_currency',
              'digital_wallet',
              'voucher_card',
            ],
          },
        },
      }),
    })

    const order = await orderResponse.json().catch(() => ({}))
    if (!orderResponse.ok) {
      await admin.from('pagamentos_planos')
        .update({ status: 'erro', atualizado_em: new Date().toISOString() })
        .eq('id', payment.id)
      console.error('Mercado Pago card checkout error:', orderResponse.status, order)
      return json({
        error: 'O Mercado Pago não conseguiu abrir o checkout de cartão. Confira as credenciais de teste e tente novamente.',
        referencia: payment.id,
      }, 502)
    }

    const checkoutUrl = typeof order.checkout_url === 'string' ? order.checkout_url : ''
    const orderId = typeof order.id === 'string' ? order.id : ''
    if (!checkoutUrl || !orderId) {
      await admin.from('pagamentos_planos')
        .update({ status: 'erro', atualizado_em: new Date().toISOString() })
        .eq('id', payment.id)
      console.error('Mercado Pago card checkout response missing URL or order ID:', order)
      return json({ error: 'O Mercado Pago não retornou o link seguro do cartão.' }, 502)
    }

    const { error: updateError } = await admin.from('pagamentos_planos').update({
      provedor_order_id: orderId,
      status: 'pendente',
      ticket_url: checkoutUrl,
      atualizado_em: new Date().toISOString(),
    }).eq('id', payment.id)

    if (updateError) {
      console.error('Could not save Mercado Pago card order:', updateError)
      return json({
        error: 'O checkout foi criado, mas não conseguimos salvar os dados. Informe o suporte com a referência da cobrança.',
        referencia: payment.id,
      }, 500)
    }

    return json({
      pagamento_id: payment.id,
      plano_id: plan.id,
      plano_nome: plan.nome,
      valor: amount,
      metodo: 'cartao_credito',
      status: 'pendente',
      checkout_url: checkoutUrl,
    })
  } catch (error) {
    console.error('create-plan-card-checkout:', error)
    const message = error instanceof Error ? error.message : 'Erro interno.'
    return json({ error: message }, 500)
  }
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
