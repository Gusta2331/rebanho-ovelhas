import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type, x-signature, x-request-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (request.method !== 'POST') return json({ error: 'Método não permitido.' }, 405)

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const mercadoPagoToken = Deno.env.get('MERCADOPAGO_ACCESS_TOKEN')
    const webhookSecret = Deno.env.get('MERCADOPAGO_WEBHOOK_SECRET')

    if (!supabaseUrl || !serviceKey || !mercadoPagoToken || !webhookSecret) {
      console.error('Mercado Pago webhook is missing required server configuration.')
      return json({ error: 'Webhook não configurado.' }, 500)
    }

    const url = new URL(request.url)
    const dataId = (url.searchParams.get('data.id') ?? url.searchParams.get('data_id') ?? '').trim()
    const xSignature = request.headers.get('x-signature') ?? ''
    const xRequestId = request.headers.get('x-request-id') ?? ''

    if (!dataId || !xSignature || !xRequestId) {
      return json({ error: 'Notificação incompleta.' }, 400)
    }

    const signatureParts = Object.fromEntries(
      xSignature.split(',').map((part) => {
        const separator = part.indexOf('=')
        return separator < 0
          ? [part.trim(), '']
          : [part.slice(0, separator).trim(), part.slice(separator + 1).trim()]
      }),
    )
    const timestamp = signatureParts.ts
    const receivedSignature = signatureParts.v1
    if (!timestamp || !receivedSignature) {
      return json({ error: 'Assinatura inválida.' }, 401)
    }

    // Manifesto oficial do Mercado Pago para notificações Webhooks.
    const manifest = `id:${dataId};request-id:${xRequestId};ts:${timestamp};`
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(webhookSecret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    )
    const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(manifest))
    const expectedSignature = [...new Uint8Array(signature)]
      .map((byte) => byte.toString(16).padStart(2, '0'))
      .join('')

    if (!constantTimeEquals(expectedSignature, receivedSignature.toLowerCase())) {
      console.warn('Rejected Mercado Pago webhook with invalid signature.')
      return json({ error: 'Assinatura inválida.' }, 401)
    }

    // Não confiar no corpo da notificação: buscar a ordem autenticada na API.
    const providerResponse = await fetch(
      'https://api.mercadopago.com/v1/orders/' + encodeURIComponent(dataId),
      { headers: { Authorization: `Bearer ${mercadoPagoToken}`, Accept: 'application/json' } },
    )
    const order = await providerResponse.json().catch(() => ({}))
    if (!providerResponse.ok) {
      console.error('Could not retrieve Mercado Pago order:', providerResponse.status)
      return json({ error: 'Não foi possível consultar a ordem no Mercado Pago.' }, 502)
    }

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const orderId = String(order.id ?? '')
    const { data: payment, error: paymentError } = await supabase
      .from('pagamentos_planos')
      .select('id,usuario_id,plano_id,valor,status,provedor_order_id')
      .eq('provedor_order_id', orderId)
      .maybeSingle()

    if (paymentError) throw paymentError
    // Pode haver notificações de outras ordens da mesma aplicação.
    if (!payment) return json({ received: true, ignored: true })

    const expectedAmount = Number(payment.valor)
    const orderAmount = Number(order.total_amount)
    if (
      String(order.external_reference ?? '') !== String(payment.id) ||
      !Number.isFinite(orderAmount) ||
      !Number.isFinite(expectedAmount) ||
      Math.abs(orderAmount - expectedAmount) > 0.009
    ) {
      console.error('Mercado Pago webhook order mismatch for payment:', payment.id)
      return json({ error: 'Os dados da cobrança não conferem.' }, 409)
    }

    const transactions = Array.isArray(order.transactions?.payments)
      ? order.transactions.payments
      : []
    const approvedStatuses = ['processed', 'approved']
    const approvedTransaction = transactions.some((transaction: { status?: string; amount?: string | number }) =>
      approvedStatuses.includes(String(transaction.status ?? '').toLowerCase()) &&
      Number.isFinite(Number(transaction.amount)) &&
      Math.abs(Number(transaction.amount) - expectedAmount) <= 0.009
    )
    const approvedOrder = approvedStatuses.includes(String(order.status ?? '').toLowerCase())

    if (approvedOrder && approvedTransaction) {
      const validity = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
      const { error: activationError } = await supabase.rpc('ativar_plano_apos_pagamento', {
        p_pagamento_id: payment.id,
        p_provedor_order_id: orderId,
        p_validade_em: validity,
      })
      if (activationError) throw activationError
      return json({ received: true, processed: true, status: 'aprovado' })
    }

    const transactionStatuses = transactions.map((transaction: { status?: string }) =>
      String(transaction.status ?? '').toLowerCase()
    )
    let status = 'pendente'
    if (String(order.status ?? '').toLowerCase() === 'canceled') status = 'cancelado'
    else if (transactionStatuses.some((value: string) => value === 'rejected')) status = 'rejeitado'

    if (payment.status !== 'aprovado') {
      const { error: updateError } = await supabase
        .from('pagamentos_planos')
        .update({ status, atualizado_em: new Date().toISOString() })
        .eq('id', payment.id)
        .neq('status', 'aprovado')
      if (updateError) throw updateError
    }

    return json({ received: true, processed: true, status })
  } catch (error) {
    console.error('mercadopago-webhook:', error)
    return json({ error: 'Erro interno ao processar a notificação.' }, 500)
  }
})

function constantTimeEquals(left: string, right: string): boolean {
  if (left.length !== right.length) return false
  let difference = 0
  for (let index = 0; index < left.length; index++) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index)
  }
  return difference === 0
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
