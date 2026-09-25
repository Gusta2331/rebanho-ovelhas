import { createClient } from 'npm:@supabase/supabase-js@2'
import { cert, getApps, initializeApp } from 'npm:firebase-admin/app'
import { getMessaging } from 'npm:firebase-admin/messaging'

type WebhookPayload = {
  record?: {
    id?: string
    fazenda_id?: string
    titulo?: string
    mensagem?: string
    tipo?: string
    aberto?: boolean
  }
}

function firebaseApp() {
  const existing = getApps()
  if (existing.length > 0) return existing[0]

  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON não configurado.')

  return initializeApp({
    credential: cert(JSON.parse(raw)),
  })
}

Deno.serve(async (request) => {
  try {
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 })
    }

    const payload = (await request.json()) as WebhookPayload
    const alert = payload.record

    if (!alert?.id || !alert.fazenda_id || alert.aberto === false) {
      return Response.json({ ignored: true })
    }

    const secretKey = Deno.env.get('OVIGESTAO_SERVICE_ROLE_KEY')

    if (!secretKey) {
      throw new Error('OVIGESTAO_SERVICE_ROLE_KEY não configurado.')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      secretKey,
    )

    const { data: devices, error } = await supabase
      .from('notificacao_dispositivos')
      .select('id, fcm_token')
      .eq('fazenda_id', alert.fazenda_id)
      .eq('ativo', true)

    if (error) throw error

    firebaseApp()

    let enviados = 0

    for (const device of devices ?? []) {
      try {
        await getMessaging().send({
          token: device.fcm_token,
          notification: {
            title: alert.titulo ?? 'Fazenda Baixinha',
            body: alert.mensagem ?? 'Há uma nova atenção na Farmácia.',
          },
          data: {
            tipo: alert.tipo ?? 'farmacia',
            alerta_id: alert.id,
          },
          android: {
            priority: 'high',
          },
        })
        enviados++
      } catch (sendError) {
        console.error('Falha ao enviar para token', device.id, sendError)
      }
    }

    return Response.json({ ok: true, enviados })
  } catch (error) {
    console.error(error)
    return Response.json(
      { ok: false, error: String(error) },
      { status: 500 },
    )
  }
})
