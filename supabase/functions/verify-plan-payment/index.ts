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
      return json({ error: 'A verificação de pagamentos ainda não está configurada no servidor.' }, 500)
    }

    const accessToken = request.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1]
    if (!accessToken) return json({ error: 'Faça login para verificar o pagamento.' }, 401)

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: { user }, error: authError } = await authClient.auth.getUser(accessToken)
    if (authError || !user?.id) return json({ error: 'Sessão inválida.' }, 401)

    const payload = await request.json().catch(() => ({}))
    const paymentId = String(payload.pagamento_id ?? '').trim()
    if (!paymentId) return json({ error: 'Informe o pagamento que deseja verificar.' }, 400)

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: payment, error: paymentError } = await admin
      .from('pagamentos_planos')
      .select('id,usuario_id,plano_id,valor,status,provedor_order_id')
      .eq('id', paymentId)
      .eq('usuario_id', user.id)
      .maybeSingle()

    if (paymentError) throw paymentError
    if (!payment) return json({ error: 'Pagamento não encontrado para esta conta.' }, 404)
    if (payment.status === 'aprovado') {
      return json({ status: 'aprovado', ativado: true, mensagem: 'Este pagamento já foi confirmado.' })
    }
    if (!payment.provedor_order_id) {
      return json({ error: 'A cobrança ainda não possui referência do Mercado Pago.' }, 409)
    }

    const providerResponse = await fetch(
      'https://api.mercadopago.com/v1/orders/' + encodeURIComponent(String(payment.provedor_order_id)),
      { headers: { Authorization: `Bearer ${mercadoPagoToken}`, Accept: 'application/json' } },
    )
    const order = await providerResponse.json().catch(() => ({}))
    if (!providerResponse.ok) {
      console.error('Mercado Pago order verification error:', providerResponse.status, order)
      return json({ error: 'Não foi possível consultar o Mercado Pago agora. Tente novamente.' }, 502)
    }

    const expectedAmount = Number(payment.valor)
    const orderAmount = Number(order.total_amount)
    if (
      String(order.external_reference ?? '') !== String(payment.id) ||
      !Number.isFinite(orderAmount) ||
      Math.abs(orderAmount - expectedAmount) > 0.009
    ) {
      console.error('Mercado Pago order mismatch for payment:', payment.id)
      return json({ error: 'Os dados da cobrança não conferem. O plano não foi alterado.' }, 409)
    }

    const transactions = Array.isArray(order.transactions?.payments)
      ? order.transactions.payments
      : []
    const approvedStatuses = ['processed', 'approved']
    const approvedTransaction = transactions.some((transaction: { status?: string; amount?: string | number }) =>
      approvedStatuses.includes(String(transaction.status ?? '').toLowerCase()) &&
      Math.abs(Number(transaction.amount) - expectedAmount) <= 0.009
    )
    const approvedOrder = approvedStatuses.includes(String(order.status ?? '').toLowerCase())

    if (approvedOrder && approvedTransaction) {
      const validadeEm = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
      const { error: activationError } = await admin.rpc('ativar_plano_apos_pagamento', {
        p_pagamento_id: payment.id,
        p_provedor_order_id: String(order.id),
        p_validade_em: validadeEm,
      })
      if (activationError) throw activationError

      return json({
        status: 'aprovado',
        ativado: true,
        validade_em: validadeEm,
        mensagem: 'Pagamento confirmado. Seu plano foi atualizado por 30 dias.',
      })
    }

    const transactionStatuses = transactions.map((transaction: { status?: string }) =>
      String(transaction.status ?? '').toLowerCase()
    )
    let status = 'pendente'
    if (String(order.status ?? '').toLowerCase() === 'canceled') status = 'cancelado'
    else if (transactionStatuses.some((value: string) => value === 'rejected')) status = 'rejeitado'

    await admin.from('pagamentos_planos')
      .update({ status, atualizado_em: new Date().toISOString() })
      .eq('id', payment.id)
      .eq('usuario_id', user.id)

    return json({
      status,
      ativado: false,
      mensagem: status === 'pendente'
        ? 'O Mercado Pago ainda não confirmou o pagamento. Aguarde um pouco e verifique novamente.'
        : 'O Mercado Pago informou que este pagamento não foi aprovado.',
    })
  } catch (error) {
    console.error('verify-plan-payment:', error)
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
