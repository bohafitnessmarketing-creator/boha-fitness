/* Perguntas do processo seletivo (texto público). A chave de pontuação NÃO fica aqui: fica só no banco de dados.
   Alternativas são gravadas pelo índice (0, 1, 2…) na ordem em que aparecem abaixo. Não reordene alternativas sem ajustar a pontuação no banco. */
window.BOHA_TAL = {
  units: {
    cb: { name: 'Casa Branca', email: 'bohafitnescasabranca@gmail.com' },
    te: { name: 'Santa Tereza', email: 'bohafitnesssantatereza@gmail.com' },
    ma: { name: 'Macedônia', email: 'bohafitnessmacedonia@gmail.com' }
  },
  vagas: {
    recepcao: {
      title: 'Jovem Aprendiz – Recepção',
      intro: [
        'Olá! Seja bem-vindo(a) ao processo seletivo da Boha Fitness!',
        'Estamos em busca de jovens talentos que desejam iniciar sua trajetória profissional e desenvolver habilidades na área de atendimento e recepção.',
        'Este formulário tem como objetivo conhecer melhor você, sua personalidade, suas habilidades, sua disponibilidade e seu interesse pela oportunidade.',
        'Responda com atenção e sinceridade. Não estamos procurando respostas perfeitas, mas pessoas com vontade de aprender, responsabilidade e comprometimento. Boa sorte!'
      ],
      thanks: [
        'Obrigado por participar do processo seletivo da Boha Fitness!',
        'Recebemos suas respostas e nossa equipe realizará a análise do seu perfil.',
        'Caso você seja selecionado(a) para a próxima etapa, entraremos em contato pelo telefone informado.',
        'Agradecemos seu interesse em fazer parte da nossa equipe! Equipe Boha Fitness.'
      ],
      sections: [
        { id: 's1', title: 'Informações pessoais', qs: [
          { id: 'name', type: 'short', label: 'Qual é seu nome completo?', auto: 'name' },
          { id: 'age', type: 'radio', label: 'Qual é sua idade?', opts: ['16 anos', '17 anos', '18 anos', '19 anos', '20 anos ou mais'] },
          { id: 'phone', type: 'short', label: 'Qual é seu telefone/WhatsApp com DDD?', auto: 'tel', ph: '(11) 99999-9999' },
          { id: 'place', type: 'short', label: 'Em qual bairro e cidade você mora?', ph: 'Ex.: Jardim Macedônia, São Paulo' },
          { id: 'q5', type: 'radio', label: 'Qual é seu nível de escolaridade atual?', opts: ['Ensino fundamental incompleto', 'Ensino fundamental completo', 'Ensino médio cursando', 'Ensino médio completo', 'Ensino superior cursando'] },
          { id: 'q6', type: 'radio', label: 'Você está estudando atualmente?', opts: ['Sim', 'Não'] },
          { id: 'q7', type: 'radio', label: 'Em qual período você estuda?', opts: ['Manhã', 'Tarde', 'Noite', 'Integral', 'Não estou estudando atualmente'] },
          { id: 'q8', type: 'radio', label: 'Você possui disponibilidade para trabalhar no horário informado pela empresa?', opts: ['Sim, tenho disponibilidade.', 'Tenho disponibilidade parcial.', 'Preciso verificar os horários.', 'Não tenho disponibilidade.'] }
        ] },
        { id: 's2', title: 'Experiência e conhecimentos', qs: [
          { id: 'q9', type: 'radio', label: 'Você já teve alguma experiência profissional?', opts: ['Sim, com carteira assinada.', 'Sim, como jovem aprendiz.', 'Sim, trabalho informal.', 'Não, será minha primeira experiência.'] },
          { id: 'q10', type: 'radio', label: 'Você já trabalhou ou teve contato com atendimento ao público?', opts: ['Sim, tenho experiência.', 'Já tive algum contato, mas pouca experiência.', 'Não, mas tenho interesse em aprender.'] },
          { id: 'q11', type: 'radio', label: 'Como você considera sua comunicação com outras pessoas?', opts: ['Tenho facilidade para conversar e me expressar.', 'Sou comunicativo(a), mas às vezes fico tímido(a).', 'Tenho um pouco de dificuldade, mas estou melhorando.', 'Tenho bastante dificuldade para me comunicar.'] },
          { id: 'q12', type: 'radio', label: 'Você sabe utilizar computador e ferramentas digitais?', opts: ['Sim, tenho facilidade.', 'Tenho conhecimentos básicos.', 'Sei utilizar apenas algumas ferramentas.', 'Tenho pouca experiência, mas quero aprender.'] },
          { id: 'q13', type: 'check', label: 'Quais destas ferramentas você já utilizou?', hint: 'Marque todas que já usou.', opts: ['Word', 'Excel', 'Google Planilhas', 'Google Documentos', 'E-mail', 'WhatsApp', 'Sistemas de cadastro', 'Nenhuma das opções'], none: 7 },
          { id: 'q14', type: 'check', label: 'Na sua opinião, quais são as três características mais importantes para trabalhar na recepção de uma academia?', hint: 'Escolha exatamente 3.', exact: 3, opts: ['Educação', 'Organização', 'Responsabilidade', 'Comunicação', 'Paciência', 'Agilidade', 'Pontualidade', 'Proatividade', 'Trabalho em equipe'] }
        ] },
        { id: 's3', title: 'Comportamento e situações práticas', qs: [
          { id: 'q15', type: 'radio', label: 'Imagine que um aluno chega à recepção irritado, reclamando de um problema no cadastro. Como você agiria?', opts: ['Responderia no mesmo tom, pois o aluno está sendo grosseiro.', 'Manteria a calma, ouviria o aluno e tentaria entender o problema.', 'Chamaria imediatamente outro funcionário sem tentar compreender a situação.', 'Ignoraria a reclamação e continuaria minhas atividades.'] },
          { id: 'q16', type: 'radio', label: 'Você está atendendo um aluno e, ao mesmo tempo, outra pessoa chega solicitando ajuda. O que faria?', opts: ['Ignoraria a segunda pessoa até terminar o primeiro atendimento.', 'Interromperia o atendimento atual imediatamente.', 'Cumprimentaria a segunda pessoa, demonstraria que percebeu sua chegada e organizaria a ordem dos atendimentos.', 'Pediria para a pessoa voltar outro dia.'] },
          { id: 'q17', type: 'radio', label: 'Se você cometer um erro durante uma atividade, qual seria sua atitude?', opts: ['Tentaria esconder o erro.', 'Colocaria a culpa em outra pessoa.', 'Comunicaria o responsável e buscaria corrigir o erro.', 'Esperaria alguém perceber.'] },
          { id: 'q18', type: 'radio', label: 'Se um colega de trabalho estiver sobrecarregado e você já tiver terminado suas tarefas, o que faria?', opts: ['Ajudaria o colega, caso fosse possível.', 'Esperaria receber uma ordem.', 'Continuaria sem fazer nada.', 'Diria que aquela não é minha responsabilidade.'] },
          { id: 'q19', type: 'radio', label: 'Um aluno pergunta sobre um plano da academia, mas você ainda não sabe explicar todos os detalhes. Como agiria?', opts: ['Inventaria uma resposta para não demonstrar desconhecimento.', 'Diria que não sei e encerraria o atendimento.', 'Informaria que vai confirmar as informações com um responsável para passar a orientação correta.', 'Encaminharia o aluno para outro dia.'] },
          { id: 'q20', type: 'radio', label: 'Você percebe que chegou atrasado(a) ou que não conseguirá comparecer ao trabalho. O que faria?', opts: ['Avisaria o responsável o quanto antes e explicaria a situação.', 'Esperaria alguém entrar em contato.', 'Não avisaria, pois imprevistos acontecem.', 'Pediria para um colega justificar minha ausência.'] }
        ] },
        { id: 's4', title: 'Perfil pessoal e desenvolvimento', qs: [
          { id: 'q21', type: 'area', label: 'Por que você deseja trabalhar na Boha Fitness?' },
          { id: 'q22', type: 'area', label: 'Quais são suas três principais qualidades?' },
          { id: 'q23', type: 'area', label: 'Qual característica sua você acredita que precisa melhorar?' },
          { id: 'q24', type: 'area', label: 'Como você lida com críticas e orientações de superiores?' },
          { id: 'q25', type: 'area', label: 'O que significa, para você, ter responsabilidade no ambiente de trabalho?' },
          { id: 'q26', type: 'area', label: 'Como você se comportaria diante de uma tarefa que nunca realizou?' },
          { id: 'q27', type: 'area', label: 'Conte uma situação em que você precisou trabalhar em equipe ou resolver algum problema. Se ainda não teve essa experiência, conte como agiria em uma situação assim.' },
          { id: 'q28', type: 'area', label: 'Por que deveríamos escolher você para essa oportunidade?' }
        ] },
        { id: 's5', title: 'Comprometimento e interesse', qs: [
          { id: 'q29', type: 'area', label: 'O que você espera aprender trabalhando na recepção da Boha Fitness?' },
          { id: 'q30', type: 'radio', label: 'Você se considera uma pessoa pontual e organizada?', opts: ['Sim, tenho bastante organização.', 'Na maioria das vezes, sim.', 'Estou desenvolvendo essas habilidades.', 'Tenho dificuldade com organização e horários.'] },
          { id: 'q31', type: 'radio', label: 'Você se sente confortável em trabalhar em equipe e receber orientações de diferentes pessoas?', opts: ['Sim, tranquilamente.', 'Sim, mas preciso de um período de adaptação.', 'Tenho preferência por trabalhar individualmente.', 'Não tenho certeza.'] },
          { id: 'q32', type: 'radio', label: 'Caso seja selecionado(a), quando poderia iniciar?', opts: ['Imediatamente, conforme os trâmites de contratação.', 'Em até 15 dias.', 'Em até 30 dias.', 'Tenho outra situação que precisa ser avaliada.'] },
          { id: 'q33', type: 'area', label: 'Existe alguma informação que gostaria de compartilhar conosco?', opt: true }
        ] },
        { id: 's6', title: 'Confirmação e envio', qs: [
          { id: 'q34', type: 'radio', label: 'Você confirma que as informações fornecidas neste formulário são verdadeiras?', opts: ['Sim.', 'Não.'] },
          { id: 'q35', type: 'radio', label: 'Você autoriza a Boha Fitness a utilizar os dados informados para fins de participação neste processo seletivo e contato sobre a oportunidade?', opts: ['Sim, autorizo.', 'Não autorizo.'] }
        ] }
      ]
    }
  }
};
