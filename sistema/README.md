# Sistema interno da Boha — módulos

Módulos que abrem dentro do hub (`equipe.html`), depois do login. Cada módulo é um arquivo HTML único, sem build e sem dependências além das fontes.

| Arquivo | O que é |
| --- | --- |
| `resultados.html` | Dashboard de clientes, vendas e financeiro das 3 unidades (dados do EVO), comparando com o mesmo mês do ano anterior. |
| `checklist.html` | Checklist do líder: tarefas pessoais com dia, hora, detalhes, repetição e aviso na hora marcada. |
| `sw.js` | Service worker mínimo, só para exibir a notificação do checklist e abrir o sistema ao clicar. Não faz cache. |

## Onde ficam os dados

Nenhum dado fica neste repositório. Tudo está no Supabase (projeto `boha-equipe-interna`) e só é lido depois do login:

- `boha_evo`: uma linha por **unidade + mês** (chave única), com data consultada, situação (`fechado` ou `parcial`) e os indicadores. Só administradores leem e gravam.
- `boha_evo_history`: cópia automática da versão anterior sempre que uma linha é alterada.
- `boha_tasks`: tarefas do checklist. Cada pessoa só enxerga as próprias.

## Executar localmente

```
python3 -m http.server 8811
```

Abra `http://localhost:8811/equipe.html`, faça login e entre no módulo pelo hub. Os módulos não funcionam abertos direto pelo endereço: eles usam a sessão do hub.

## Publicar

É um site estático: o que entra na branch `main` vai ao ar. Ao alterar um módulo, troque o valor de `VERSION` em `equipe.html` para o navegador buscar a versão nova.

## Atualizar os dados do EVO (todo fim de mês)

1. No EVO, escolha a unidade no **menu de perfil** (canto superior direito).
2. Abra o **Dashboard gerencial** e escolha **no calendário** o último dia do mês. Espere 15 segundos e confira se os cartões mostram o mês certo.
3. Anote as abas Clientes (com cancelamentos e renovações), Vendas (com visitantes e conversões) e Financeiro (recebimentos, gastos e ticket médio). Deixe "Apenas vendas recebidas" desligado.
4. No dashboard, clique em **Atualizar dados → Baixar modelo CSV**. Preencha uma linha por mês, um arquivo por unidade (o nome do arquivo com `casa_branca`, `tereza` ou `macedonia` já seleciona a unidade). Também é aceito o JSON no formato do pacote original.
5. Arraste os arquivos para **Atualizar dados**, confira a prévia e clique em **Aplicar**.
6. Compare pelo menos um número de cada unidade com o EVO.

Regras da importação:

- Linha com data consultada diferente do último dia do mês entra como **parcial**, mesmo que o arquivo diga `fechado`. Mês parcial aparece marcado e não é comparado com o ano anterior. Ao fechar o mês, importe a linha de novo.
- A importação é recusada se houver unidade + mês repetido, valor vazio ou não numérico (lacunas não viram zero), valor negativo, ou `ativos ≠ adimplentes + inadimplentes`.
- Alterar um mês já fechado é permitido; a versão anterior fica em `boha_evo_history`.
- **Baixar base atual (JSON)** gera um backup completo antes de qualquer correção.

## Regras de cálculo do dashboard

- Saldos (ativos, inadimplência em R$, contas vencidas) nunca são somados entre meses.
- Fluxos (contratos, cancelamentos, vendas, recebimentos, gastos) têm acumulado do ano só em intervalos iguais e com meses fechados.
- Churn é comparado em pontos percentuais. Taxas e médias não são somadas nem calculadas entre unidades.
- Meta igual a zero aparece como "não configurada — validar".
- Valores em R$ que o EVO exibe em "mil" são aproximados (≈).
- O ticket médio do Financeiro é deslocado para o mês a que se refere (o EVO mostra o mês anterior ao filtro) e fica fora da comparação principal.
- "Acessos do dia", custo por cliente e tempo médio de contrato ficam fora do painel.
- "Recebimentos − gastos" é a diferença entre os dois valores exibidos pelo EVO, não lucro.

## Pendências que dependem de validação no EVO

- Financeiro de Macedônia em 2025 parece incompleto; a comparação financeira dessa unidade com 2025 aparece como "validar".
- Conversões maiores que visitantes em vários meses; a taxa de conversão não é calculada.
- Tempo médio de vida de 1 mês em Macedônia (jan/2026 e jun/2026).
- Zeros em ticket médio e mensalidade média podem ser ausência de configuração.

## Avisos do checklist

O aviso dispara no navegador de quem está com o sistema aberto (pode estar em segundo plano). Com o sistema fechado não há aviso: isso exige notificação push enviada por servidor, que ainda não existe.
