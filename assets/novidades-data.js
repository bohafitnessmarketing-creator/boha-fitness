// Posts do blog "Novidades" (novidades.html).
//
// COMO ADICIONAR UM POST NOVO:
// Copie um objeto inteiro (do "{" ao "},") e cole no TOPO do array POSTS
// (mais recente primeiro). Troque os campos e pronto — não precisa mexer
// em HTML, CSS nem no resto do JS.
//
// Campos:
//   titulo   - título do post
//   data     - texto livre, ex: "15 de fevereiro de 2026"
//   unidade  - "Jardim Casa Branca" / "Jardim Santa Tereza" / "Jardim Macedônia" / "Todas as unidades"
//   imagem   - caminho de uma foto que já está em imagens/...
//   resumo   - texto curto (2-3 linhas) mostrado no card
//   conteudo - lista de parágrafos; cada item vira um parágrafo no post completo
//
// ATENÇÃO: os 3 posts abaixo são EXEMPLOS DE DEMONSTRAÇÃO com conteúdo
// fictício, só para mostrar como o blog fica na prática. Substitua pelos
// posts reais quando for publicar.

const POSTS = [
  {
    titulo: "Em breve, aulas de Spinning na Boha Santa Tereza",
    data: "2 de setembro de 2026",
    unidade: "Jardim Santa Tereza",
    imagem: "imagens/novidades/nov-spninnig.PNG",
    resumo: "Chegando a nova modalidade Spinning na unidade Santa Tereza — fique de olho na agenda!",
    conteudo: [
      "A Boha Jardim Santa Tereza vai passar a oferecer aulas de Spinning, pedalada indoor em ritmo intenso, ótima opção de cardio para todos os níveis.",
      "Em breve divulgamos os horários das turmas. Acompanhe as novidades por aqui ou fale com a equipe da unidade para mais informações."
    ],
    whatsapp: { numero: "5511991195832", texto: "Garantir pré-venda" }
  },
  {
    titulo: "Chegaram novos aparelhos de puxada e cabo na Casa Branca",
    data: "20 de agosto de 2026",
    unidade: "Jardim Casa Branca",
    imagem: "imagens/boha-casabranca/musculacao-06.png",
    resumo: "Ampliamos a área de musculação com uma nova estação de puxadas — já pode usar!",
    conteudo: [
      "A unidade Jardim Casa Branca ganhou uma nova estação de puxadas e cabos, ampliando as opções de treino de costas e braços.",
      "O equipamento já está disponível para uso e os professores estão passando as orientações durante os treinos. Qualquer dúvida, é só chamar a equipe na unidade."
    ]
  },
  {
    titulo: "Nova turma de aula funcional na Santa Tereza",
    data: "10 de agosto de 2026",
    unidade: "Jardim Santa Tereza",
    imagem: "imagens/boha-tereza/sala-coletiva-01.png",
    resumo: "Abrimos uma nova turma de treino funcional na sala de aulas coletivas — vagas limitadas.",
    conteudo: [
      "A partir desse mês, a Boha Jardim Santa Tereza abriu uma nova turma de treino funcional, com foco em condicionamento e resistência.",
      "As vagas são limitadas. Quem tiver interesse pode confirmar o horário direto na recepção ou pelo WhatsApp da unidade."
    ]
  },
  {
    titulo: "Reforma nos vestiários da Macedônia está pronta",
    data: "28 de julho de 2026",
    unidade: "Jardim Macedônia",
    imagem: "imagens/boha-mcd/vestiario-01.png",
    resumo: "Os vestiários passaram por uma reforma completa — mais conforto pra treinar.",
    conteudo: [
      "Concluímos a reforma dos vestiários da unidade Jardim Macedônia, com armários novos e ambiente climatizado.",
      "O espaço já está liberado para uso normal. Agradecemos a paciência de todo mundo durante as obras!"
    ]
  }
];
