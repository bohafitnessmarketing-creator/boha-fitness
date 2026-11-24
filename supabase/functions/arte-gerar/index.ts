// Edge Function "arte-gerar": direção de imagem (texto) + imagem de fundo (OpenAI) para o módulo Criação de artes.
// A chave OPENAI_API_KEY vive só aqui (Secrets do Supabase). O site nunca a enxerga.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const FORMATS: Record<string, { size: string; label: string; orient: string }> = {
  '9x16': { size: '1024x1536', label: 'vertical 9:16 (Stories e Reels)', orient: 'portrait' },
  '4x3': { size: '1536x1024', label: 'horizontal 4:3', orient: 'landscape' },
  '16x9': { size: '1536x1024', label: 'horizontal 16:9 (TV e telas)', orient: 'landscape' },
};
const UNITS: Record<string, string> = { cb: 'Casa Branca', te: 'Jardim Santa Tereza', ma: 'Macedônia' };

// Regras da skill "Boha Fitness — Creative Studio" (resumo operacional para a direção de arte).
const SKILL = `
IDENTIDADE
- Fundo preto ou grafite (#111111); amarelo de destaque #FFF000; branco para contraste. Tons neutros só quando úteis.
- Estética premium, esportiva, contemporânea e enérgica. Diagonais, recortes e linhas amarelas com moderação. Evitar excesso de glow, texturas, efeitos, ícones e informação.
- Hierarquia: headline dominante, benefício ou informação principal, detalhes, CTA e assinatura. Respiro, alinhamento, contraste e leitura rápida no celular.
- Fotografia: pessoas com aparência natural e anatomia plausível; sem marcas reais; respeitar pedidos de peça sem pessoas.
- Nunca inventar preço, condição, data, horário, endereço, contato ou benefício. Nunca prometer resultado físico ou médico. Evitar constrangimento corporal.
- Português brasileiro correto, frases curtas e verbos ativos, sem clichês nem excesso de exclamações.
PADRÕES POR FINALIDADE
- Comercial: preço/benefício em destaque, CTA como "Conheça a Boha" ou "Fale com nossa equipe" (somente se já estiver no texto).
- Institucional: estrutura, atendimento, comunidade e evolução.
- Educacional: uma ideia por peça, explicação simples.
- Aulas coletivas: modalidade, unidade e horário só quando informados; estética dinâmica.
- Comunicação interna: objetivo e ação claros; números, progresso e prazo legíveis à distância.
- Datas comemorativas: conectar a data a treino, saúde, movimento ou comunidade.
`;

const SYSTEM = `Você é o diretor de arte da Boha Fitness, uma academia em Embu das Artes e região (SP).
Siga as regras da marca:
${SKILL}
TAREFA
Você recebe TEXTO DO POST, OBJETIVO, UNIDADE e FORMATO. Responda SOMENTE o JSON do esquema.
- headline, support e cta: distribua EXATAMENTE o texto do usuário. Não acrescente, troque, corrija, traduza nem remova nenhuma palavra, número, preço ou data. Você só separa o texto nas três partes, mantendo a ordem.
  headline = a ideia principal, curta (ideal até 7 palavras). support = informação de apoio (pode ser vazia). cta = chamada para ação SOMENTE se o texto do usuário já trouxer uma (senão vazia).
- highlight: de 1 a 3 palavras CONSECUTIVAS da headline, copiadas exatamente, para destacar em amarelo; ou vazio.
- zone: onde o texto ficará sobre a imagem ("bottom", "top" ou "center"), pensando na composição.
- image_prompt: em inglês, descreva SOMENTE a imagem de fundo (a arte final terá logo e texto colocados depois, por cima). Regras do image_prompt:
  * Absolutamente NENHUM texto, letra, número, logotipo, marca d'água, sinalização ou interface na imagem.
  * Estética premium esportiva escura: base preta/grafite (#111111) com acentos amarelos (#FFF000) usados com moderação.
  * Deixe a região da zona escolhida (cerca de 45% do quadro) calma, escura e livre para receber o texto; o assunto principal fica no restante.
  * Mantenha também o canto superior esquerdo (cerca de 30% da largura e 18% da altura, onde o logo será colocado) livre de rostos e detalhes importantes.
  * Pessoas, se houver, com aparência natural e anatomia plausível, em ambiente de academia moderna. Sem marcas reais.
  * Adapte ao objetivo e ao formato informado.`;

const SCHEMA = {
  name: 'direcao_arte',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: ['headline', 'support', 'cta', 'highlight', 'zone', 'image_prompt'],
    properties: {
      headline: { type: 'string' },
      support: { type: 'string' },
      cta: { type: 'string' },
      highlight: { type: 'string' },
      zone: { type: 'string', enum: ['top', 'center', 'bottom'] },
      image_prompt: { type: 'string' },
    },
  },
};

async function openai(path: string, body: unknown, key: string, ms: number) {
  const r = await fetch('https://api.openai.com' + path, {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(ms),
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) {
    const msg = data?.error?.message || ('OpenAI HTTP ' + r.status);
    const e = new Error(msg) as Error & { status?: number };
    e.status = r.status;
    throw e;
  }
  return data;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Método não permitido.' }, 405);

  const url = Deno.env.get('SUPABASE_URL')!;
  const svc = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
  const auth = req.headers.get('Authorization') || '';
  const token = auth.replace(/^Bearer\s+/i, '');
  if (!token) return json({ error: 'Faça login para continuar.' }, 401);

  const admin = createClient(url, svc, { auth: { persistSession: false } });
  const { data: u, error: ue } = await admin.auth.getUser(token);
  const email = u?.user?.email?.toLowerCase();
  if (ue || !email) return json({ error: 'Sessão inválida. Entre novamente.' }, 401);

  // Permissão real, a mesma regra do banco (perfil Gerente ou Administrador com o módulo liberado).
  const asUser = createClient(url, anon, { global: { headers: { Authorization: auth } }, auth: { persistSession: false } });
  const { data: can } = await asUser.rpc('boha_can', { p_module: 'artes' });
  if (!can) return json({ error: 'Seu perfil não tem acesso a este módulo.' }, 403);
  const { data: acc } = await admin.from('boha_access').select('role,unit,name').eq('email', email).maybeSingle();
  if (!acc || !['gerente', 'admin'].includes(acc.role)) return json({ error: 'Seu perfil não tem acesso a este módulo.' }, 403);

  // Entrada
  let b: Record<string, unknown> = {};
  try { b = await req.json(); } catch { return json({ error: 'Pedido inválido.' }, 400); }
  const text = String(b.text ?? '').trim().slice(0, 400);
  const objective = String(b.objective ?? '').trim().slice(0, 120);
  const format = String(b.format ?? '');
  if (text.length < 3) return json({ error: 'Escreva o texto do post.' }, 400);
  if (!objective) return json({ error: 'Escolha o objetivo do post.' }, 400);
  if (!FORMATS[format]) return json({ error: 'Formato inválido.' }, 400);
  // Gerente só gera para a própria unidade; administrador escolhe (ou rede toda).
  let unit: string | null = acc.unit || (UNITS[String(b.unit ?? '')] ? String(b.unit) : null);
  if (acc.unit) unit = acc.unit;

  const key = Deno.env.get('OPENAI_API_KEY');
  if (!key) return json({ error: 'A chave da OpenAI ainda não foi configurada no servidor. Peça ao administrador.' }, 503);
  const textModel = Deno.env.get('OPENAI_TEXT_MODEL') || 'gpt-4.1-mini';
  const imageModel = Deno.env.get('OPENAI_IMAGE_MODEL') || 'gpt-image-2';
  const quality = Deno.env.get('OPENAI_IMAGE_QUALITY') || 'medium';

  // Limpeza de artes vencidas (30 dias): arquivos e linhas. Melhor esforço.
  try {
    const { data: old } = await admin.from('boha_art_history').select('id,final_path').lt('expires_at', new Date().toISOString()).limit(100);
    if (old && old.length) {
      const paths = old.map((r) => r.final_path).filter(Boolean) as string[];
      if (paths.length) await admin.storage.from('boha-artes').remove(paths);
      await admin.from('boha_art_history').delete().in('id', old.map((r) => r.id));
    }
  } catch { /* ignora */ }

  // Reserva a cota do dia (5 para gerente). Se algo falhar adiante, devolve.
  const limit = acc.role === 'admin' ? 30 : 5;
  const { data: used, error: re } = await admin.rpc('boha_art_reserve', { p_email: email, p_limit: limit });
  if (re) return json({ error: 'Não foi possível verificar o limite diário.' }, 500);
  if (used === null || used === undefined) return json({ error: `Você já usou as ${limit} artes de hoje. O limite volta amanhã.`, quota: { used: limit, lim: limit } }, 429);
  const refund = () => admin.rpc('boha_art_refund', { p_email: email });

  try {
    const F = FORMATS[format];
    const unitName = unit ? UNITS[unit] : 'rede (as três unidades)';
    const dir = await openai('/v1/chat/completions', {
      model: textModel,
      temperature: 0.7,
      response_format: { type: 'json_schema', json_schema: SCHEMA },
      messages: [
        { role: 'system', content: SYSTEM },
        { role: 'user', content: `TEXTO DO POST:\n${text}\n\nOBJETIVO: ${objective}\nUNIDADE: ${unitName}\nFORMATO: ${F.label} (${F.orient})` },
      ],
    }, key, 60000);
    let layout: Record<string, string>;
    try { layout = JSON.parse(dir.choices[0].message.content); } catch { throw new Error('Resposta da direção de arte veio em formato inesperado.'); }

    const prompt = `${layout.image_prompt}\n\nStrict rules: background artwork only, no text, no letters, no numbers, no logos, no watermarks anywhere in the image. Keep the ${layout.zone} area of the frame dark, calm and uncluttered, and keep the top-left corner free of faces and key details. ${F.orient} composition. Premium dark sports look, black/graphite base with sparing yellow (#FFF000) accents.`;
    const img = await openai('/v1/images/generations', {
      model: imageModel, prompt, size: F.size, quality, n: 1, output_format: 'jpeg', output_compression: 88,
    }, key, 120000);
    const b64 = img?.data?.[0]?.b64_json;
    if (!b64) throw new Error('A imagem não veio na resposta.');

    const { data: row, error: he } = await admin.from('boha_art_history').insert({
      created_by: email, created_by_name: acc.name || null, unit, format, objective,
      input_text: text, direction: layout,
    }).select('id').single();
    if (he || !row) throw new Error('Não foi possível registrar no histórico.');

    return json({ id: row.id, image_b64: b64, mime: 'image/jpeg', layout, quota: { used, lim: limit } });
  } catch (e) {
    await refund();
    const err = e as Error & { status?: number };
    console.error('arte-gerar', err.status, err.message);
    let msg = 'Não foi possível gerar a arte agora. Tente de novo em instantes. Sua cota não foi gasta.';
    if (err.status === 401) msg = 'A chave da OpenAI é inválida. Peça ao administrador para conferir.';
    else if (err.status === 403) msg = 'A conta da OpenAI ainda não está liberada para gerar imagens (pode ser preciso verificar a organização em platform.openai.com). Peça ao administrador. Sua cota não foi gasta.';
    else if (err.status === 429) msg = 'A OpenAI está sem créditos ou no limite de uso. Peça ao administrador para conferir a conta. Sua cota não foi gasta.';
    else if (err.status === 400 && /safety|policy|moderation/i.test(err.message)) msg = 'A OpenAI recusou esse pedido por política de conteúdo. Reescreva o texto e tente de novo.';
    else if (err.name === 'TimeoutError') msg = 'A geração demorou demais. Tente de novo. Sua cota não foi gasta.';
    return json({ error: msg, detail: err.message?.slice(0, 200) }, 502);
  }
});
