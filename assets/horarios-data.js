// ===== Grade de horários das aulas coletivas =====
// Edite os horários/aulas aqui — não precisa mexer em mais nada.
// Cada dia é uma lista de { hora, aula }. Formato da hora: "HHhMM" (ex.: "07h00", "08h15") — mantenha esse padrão pra ordenar certo.
// Se um dia não tiver aula, apague a lista dele (ou deixe vazia: []) que ele some da grade sozinho.
var HORARIOS_POR_UNIDADE = {
  'casa-branca': {
    segunda: [
      { hora: '07h00', aula: 'Fit Dance' },
      { hora: '08h00', aula: 'Funcional' },
      { hora: '18h00', aula: 'Funcional' },
      { hora: '19h00', aula: 'Zumba' },
      { hora: '20h00', aula: 'Jump' },
      { hora: '21h00', aula: 'Jiu-Jitsu' }
    ],
    terca: [
      { hora: '07h00', aula: 'Pilates' },
      { hora: '08h00', aula: 'Jump' },
      { hora: '18h00', aula: 'Pilates' },
      { hora: '19h00', aula: 'Pilates' },
      { hora: '20h00', aula: 'Fit Dance' },
      { hora: '21h00', aula: 'Muay-Thai' }
    ],
    quarta: [
      { hora: '06h00', aula: 'Pilates' },
      { hora: '07h00', aula: 'Step' },
      { hora: '08h00', aula: 'H.I.T' },
      { hora: '18h00', aula: 'H.I.T' },
      { hora: '19h00', aula: 'Jump' },
      { hora: '20h00', aula: 'Sertanejo' },
      { hora: '21h00', aula: 'Jiu-Jitsu' }
    ],
    quinta: [
      { hora: '07h00', aula: 'Pilates' },
      { hora: '08h00', aula: 'G.A.P' },
      { hora: '18h00', aula: 'Pilates' },
      { hora: '19h00', aula: 'Pilates' },
      { hora: '20h00', aula: 'Fit Dance' },
      { hora: '21h00', aula: 'Muay-Thai' }
    ],
    sexta: [
      { hora: '07h00', aula: 'Cross' },
      { hora: '08h00', aula: 'Zumba' },
      { hora: '19h00', aula: 'Sertanejo' },
      { hora: '20h00', aula: 'Zumba' },
      { hora: '21h00', aula: 'Jiu-Jitsu' }
    ],
    sabado: [
      { hora: '11h00', aula: 'Muay-Thai' }
    ]
  },
  'santa-tereza': {
    segunda: [
      { hora: '07h00', aula: 'Pilates' },
      { hora: '08h15', aula: 'Jump' },
      { hora: '18h00', aula: 'Cross' },
      { hora: '19h15', aula: 'Jump' },
      { hora: '20h15', aula: 'Pilates' }
    ],
    terca: [
      { hora: '07h00', aula: 'Funcional' },
      { hora: '08h15', aula: 'Zumba' },
      { hora: '19h15', aula: 'A.B.S' },
      { hora: '20h15', aula: 'Boxe' }
    ],
    quarta: [
      { hora: '06h00', aula: 'Pilates' },
      { hora: '07h00', aula: 'Pilates' },
      { hora: '08h15', aula: 'Fit Dance' },
      { hora: '18h00', aula: 'Pilates' },
      { hora: '19h15', aula: 'Pilates' },
      { hora: '20h15', aula: 'Jump' }
    ],
    quinta: [
      { hora: '07h00', aula: 'G.A.P' },
      { hora: '08h15', aula: 'Step' },
      { hora: '18h00', aula: 'G.A.P' },
      { hora: '19h15', aula: 'Sertanejo' },
      { hora: '20h15', aula: 'Boxe' }
    ],
    sexta: [
      { hora: '07h00', aula: 'Pilates' },
      { hora: '08h15', aula: 'A.B.S' },
      { hora: '18h00', aula: 'Cross' },
      { hora: '19h15', aula: 'Zumba' },
      { hora: '20h15', aula: 'Sertanejo' }
    ]
  }
};

// Spinning (Jardim Santa Tereza) — fica de fora do HORARIOS_POR_UNIDADE de propósito:
// acontece numa sala própria (bike), em paralelo com a sala coletiva principal, então
// os horários se sobrepõem aos da grade acima. Misturar os dois quebraria a grade
// principal (ela assume só uma aula por horário/dia). Usado pelo card "Spinning" em
// Modalidades e na Home.
var HORARIOS_SPINNING_SANTA_TEREZA = {
  segunda: ['07h00', '19h00', '20h00'],
  terca: ['06h00', '07h00', '18h00', '20h00'],
  quarta: ['07h00', '08h00', '18h00', '19h00'],
  quinta: ['06h00', '07h00', '18h00', '19h00', '20h00'],
  sexta: ['07h00', '20h00']
};
