// ===== Boha Fitness — script compartilhado =====

// Dias da semana — usado pela grade de horários e pelos horários por modalidade
var DIAS_SEMANA = [
  { key: 'segunda', nome: 'Segunda', abrev: 'Seg' },
  { key: 'terca', nome: 'Terça', abrev: 'Ter' },
  { key: 'quarta', nome: 'Quarta', abrev: 'Qua' },
  { key: 'quinta', nome: 'Quinta', abrev: 'Qui' },
  { key: 'sexta', nome: 'Sexta', abrev: 'Sex' },
  { key: 'sabado', nome: 'Sábado', abrev: 'Sáb' },
  { key: 'domingo', nome: 'Domingo', abrev: 'Dom' }
];

// Grade de horários das aulas coletivas (páginas de unidade) — usa os dados de assets/horarios-data.js
(function(){
  var containers = document.querySelectorAll('[data-horarios]');
  if (!containers.length) return;
  if (typeof HORARIOS_POR_UNIDADE === 'undefined') return;

  containers.forEach(function(container){
    var dados = HORARIOS_POR_UNIDADE[container.getAttribute('data-horarios')];
    if (!dados) return;

    var diasComAula = DIAS_SEMANA.filter(function(d){ return dados[d.key] && dados[d.key].length; });
    if (!diasComAula.length) return;

    var horas = [];
    diasComAula.forEach(function(d){
      dados[d.key].forEach(function(item){
        if (horas.indexOf(item.hora) === -1) horas.push(item.hora);
      });
    });
    horas.sort();

    function aulaEm(diaKey, hora){
      var achado = (dados[diaKey] || []).filter(function(i){ return i.hora === hora; })[0];
      return achado ? achado.aula : null;
    }

    function listaDoDia(diaKey){
      var lista = (dados[diaKey] || []).slice().sort(function(a, b){ return a.hora < b.hora ? -1 : 1; });
      return lista.map(function(item){
        return '<div class="grade-item"><span class="grade-item-hora">' + item.hora + '</span><span class="grade-item-aula">' + item.aula + '</span></div>';
      }).join('');
    }

    var thead = '<tr><th>Horário</th>' + diasComAula.map(function(d){ return '<th>' + d.nome + '</th>'; }).join('') + '</tr>';
    var tbody = horas.map(function(hora){
      var linha = '<tr><td class="grade-hora">' + hora + '</td>';
      diasComAula.forEach(function(d){
        var aula = aulaEm(d.key, hora);
        linha += '<td>' + (aula ? '<span class="grade-aula">' + aula + '</span>' : '<span class="grade-vazio">–</span>') + '</td>';
      });
      return linha + '</tr>';
    }).join('');

    var abas = diasComAula.map(function(d, i){
      return '<button type="button" class="grade-aba' + (i === 0 ? ' active' : '') + '" data-dia="' + d.key + '">' + d.abrev + '</button>';
    }).join('');

    container.innerHTML =
      '<div class="grade-tabela-wrap"><div class="grade-tabela-scroll"><table class="grade-tabela"><thead>' + thead + '</thead><tbody>' + tbody + '</tbody></table></div></div>' +
      '<div class="grade-abas-wrap">' +
        '<div class="grade-abas" role="tablist">' + abas + '</div>' +
        '<div class="grade-lista">' + listaDoDia(diasComAula[0].key) + '</div>' +
      '</div>';

    container.querySelectorAll('.grade-aba').forEach(function(btn){
      btn.addEventListener('click', function(){
        container.querySelectorAll('.grade-aba').forEach(function(b){ b.classList.toggle('active', b === btn); });
        container.querySelector('.grade-lista').innerHTML = listaDoDia(btn.getAttribute('data-dia'));
      });
    });
  });
})();

// Horários por modalidade (modalidades.html) — deriva da mesma fonte, sem duplicar dados
(function(){
  var botoes = document.querySelectorAll('.modalidade-card[data-aula]');
  if (!botoes.length) return;
  if (typeof HORARIOS_POR_UNIDADE === 'undefined') return;

  var UNIDADES = [
    { key: 'casa-branca', nome: 'Casa Branca' },
    { key: 'santa-tereza', nome: 'Santa Tereza' }
  ];

  function horariosDaAula(unidadeKey, aula){
    var dados = HORARIOS_POR_UNIDADE[unidadeKey] || {};
    var linhas = [];
    DIAS_SEMANA.forEach(function(d){
      (dados[d.key] || []).forEach(function(item){
        if (item.aula === aula) linhas.push(d.abrev + ' · ' + item.hora);
      });
    });
    return linhas;
  }

  botoes.forEach(function(btn){
    var aula = btn.getAttribute('data-aula');
    if (!aula) return;
    var panel = btn.nextElementSibling;
    if (!panel || !panel.classList.contains('modalidade-horarios')) return;

    var colsHtml = UNIDADES.map(function(u){
      var linhas = horariosDaAula(u.key, aula);
      var conteudo = linhas.length
        ? '<ul>' + linhas.map(function(l){ return '<li>' + l + '</li>'; }).join('') + '</ul>'
        : '<p class="sem-aula">Não tem nessa unidade</p>';
      return '<div class="modalidade-horarios-col"><h4>' + u.nome + '</h4>' + conteudo + '</div>';
    }).join('');
    panel.innerHTML = '<div class="modalidade-horarios-cols">' + colsHtml + '</div>';

    btn.addEventListener('click', function(){
      btn.parentElement.classList.toggle('open');
    });
  });
})();

// Menu mobile
(function(){
  var toggle = document.getElementById('navToggle');
  var nav = document.getElementById('mainNav');
  if (!toggle || !nav) return;
  toggle.addEventListener('click', function(){
    nav.classList.toggle('open');
    toggle.textContent = nav.classList.contains('open') ? '✕' : '☰';
  });
  nav.querySelectorAll('a').forEach(function(a){
    a.addEventListener('click', function(){
      nav.classList.remove('open');
      toggle.textContent = '☰';
    });
  });
})();

// Dropdown "Mais" do menu (desktop: clique ou hover; fecha ao clicar fora)
(function(){
  document.querySelectorAll('.nav-dropdown').forEach(function(dropdown){
    var btn = dropdown.querySelector('.nav-dropdown-toggle');
    if (!btn) return;
    btn.addEventListener('click', function(e){
      e.stopPropagation();
      dropdown.classList.toggle('open');
    });
  });
  document.addEventListener('click', function(){
    document.querySelectorAll('.nav-dropdown.open').forEach(function(d){ d.classList.remove('open'); });
  });
})();

// FAQ accordion
(function(){
  document.querySelectorAll('.faq-item').forEach(function(item){
    var q = item.querySelector('.faq-q');
    if (!q) return;
    q.addEventListener('click', function(){
      var isOpen = item.classList.contains('open');
      item.parentElement.querySelectorAll('.faq-item').forEach(function(i){ i.classList.remove('open'); });
      if (!isOpen) item.classList.add('open');
    });
  });
})();

// Modal "Qual unidade você prefere treinar?" — fluxo dos botões "Quero esse plano"
(function(){
  var triggers = document.querySelectorAll('[data-plano]');
  if (!triggers.length) return;

  var LINKS = {
    simples: {
      'casa-branca': 'https://evo-totem.w12app.com.br/bohafitness/1/site/Zn50Krsk1XkTW8YXGf83Gw%5BEQUAL%5D%5BEQUAL%5D',
      'santa-tereza': 'https://evo-totem.w12app.com.br/bohafitness/2/site/IDbtKb0QXWZKu391NeSogQ%5BEQUAL%5D%5BEQUAL%5D',
      'macedonia': 'https://evo-totem.w12app.com.br/bohafitness/3/site/YTpDSxG4gAW4qSUq%5BBAR%5D%5BBAR%5DRLnA%5BEQUAL%5D%5BEQUAL%5D'
    },
    vip: {
      'casa-branca': 'https://evo-totem.w12app.com.br/bohafitness/1/site/CGbxAebAzMiJYOfbgbIphg%5BEQUAL%5D%5BEQUAL%5D',
      'santa-tereza': 'https://evo-totem.w12app.com.br/bohafitness/2/site/oxT8H5JG1%5BBAR%5DWI%5BBAR%5DzZmqsBlmA%5BEQUAL%5D%5BEQUAL%5D',
      'macedonia': 'https://evo-totem.w12app.com.br/bohafitness/3/site/Il5lCjpqOYYzTOIhlMhp0Q%5BEQUAL%5D%5BEQUAL%5D'
    },
    basico: {
      'casa-branca': 'https://evo-totem.w12app.com.br/bohafitness/1/site/VttOYx2IIwwdLrg2y7lZag%5BEQUAL%5D%5BEQUAL%5D',
      'santa-tereza': 'https://evo-totem.w12app.com.br/bohafitness/2/site/AcgBZ%5BBAR%5DDIrTCSpo1ymbAWlA%5BEQUAL%5D%5BEQUAL%5D',
      'macedonia': 'https://evo-totem.w12app.com.br/bohafitness/3/site/UJkekf%5BPLUS%5D5sgjzZKuW2hhaUQ%5BEQUAL%5D%5BEQUAL%5D'
    }
  };
  var PLANO_NOMES = { simples: 'Boha Simples', vip: 'Boha VIP Anual', basico: 'Boha Recorrente' };

  var overlay, planoAtual, lastFocused;

  function build(){
    overlay = document.createElement('div');
    overlay.className = 'plano-modal';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.innerHTML =
      '<div class="plano-modal-panel">' +
        '<button type="button" class="plano-modal-close" aria-label="Fechar">✕</button>' +
        '<div class="plano-modal-body">' +
          '<span class="eyebrow"><span class="plano-modal-plano"></span></span>' +
          '<h3>Qual unidade você prefere treinar?</h3>' +
          '<div class="plano-modal-unidades">' +
            '<button type="button" class="plano-modal-unidade" data-unidade="casa-branca">Jardim Casa Branca</button>' +
            '<button type="button" class="plano-modal-unidade" data-unidade="santa-tereza">Jardim Santa Tereza</button>' +
            '<button type="button" class="plano-modal-unidade" data-unidade="macedonia">Jardim Macedônia</button>' +
          '</div>' +
          '<a class="btn btn-amarelo plano-modal-cta" hidden target="_blank" rel="noopener noreferrer">Ver planos e benefícios</a>' +
        '</div>' +
      '</div>';
    document.body.appendChild(overlay);

    overlay.querySelector('.plano-modal-close').addEventListener('click', close);
    overlay.addEventListener('click', function(e){ if (e.target === overlay) close(); });
    overlay.querySelectorAll('.plano-modal-unidade').forEach(function(btn){
      btn.addEventListener('click', function(){ selectUnidade(btn); });
    });
    document.addEventListener('keydown', function(e){
      if (e.key === 'Escape' && overlay.classList.contains('is-open')) close();
    });
  }

  function selectUnidade(btn){
    overlay.querySelectorAll('.plano-modal-unidade').forEach(function(b){
      b.classList.toggle('selected', b === btn);
    });
    var link = (LINKS[planoAtual] || {})[btn.getAttribute('data-unidade')];
    var cta = overlay.querySelector('.plano-modal-cta');
    if (link) {
      cta.href = link;
      cta.hidden = false;
    }
  }

  function open(plano, trigger){
    if (!overlay) build();
    planoAtual = plano;
    lastFocused = trigger;
    overlay.querySelector('.plano-modal-plano').textContent = PLANO_NOMES[plano] || '';
    overlay.querySelectorAll('.plano-modal-unidade').forEach(function(b){ b.classList.remove('selected'); });
    var cta = overlay.querySelector('.plano-modal-cta');
    cta.hidden = true;
    cta.removeAttribute('href');
    overlay.classList.add('is-open');
    document.body.style.overflow = 'hidden';
    overlay.querySelector('.plano-modal-close').focus();
  }

  function close(){
    if (!overlay) return;
    overlay.classList.remove('is-open');
    document.body.style.overflow = '';
    if (lastFocused) lastFocused.focus();
  }

  triggers.forEach(function(t){
    t.addEventListener('click', function(){ open(t.getAttribute('data-plano'), t); });
  });
})();

// Novidades (blog) — monta os cards a partir de assets/novidades-data.js e abre o post num modal
(function(){
  var grid = document.getElementById('novidadesGrid');
  if (!grid || typeof POSTS === 'undefined') return;

  function criarCard(post){
    var card = document.createElement('button');
    card.type = 'button';
    card.className = 'novidade-card';

    var imgWrap = document.createElement('div');
    imgWrap.className = 'novidade-card-img';
    var img = document.createElement('img');
    img.src = post.imagem;
    img.alt = post.titulo;
    img.loading = 'lazy';
    imgWrap.appendChild(img);

    var body = document.createElement('div');
    body.className = 'novidade-card-body';

    var tag = document.createElement('span');
    tag.className = 'novidade-tag';
    tag.textContent = post.unidade;

    var h3 = document.createElement('h3');
    h3.textContent = post.titulo;

    var data = document.createElement('span');
    data.className = 'novidade-data';
    data.textContent = post.data;

    var resumo = document.createElement('p');
    resumo.textContent = post.resumo;

    var leiaMais = document.createElement('span');
    leiaMais.className = 'novidade-leia-mais';
    leiaMais.textContent = 'Ler mais →';

    body.appendChild(tag);
    body.appendChild(h3);
    body.appendChild(data);
    body.appendChild(resumo);
    body.appendChild(leiaMais);
    card.appendChild(imgWrap);
    card.appendChild(body);

    card.addEventListener('click', function(){ openPost(post, card); });
    return card;
  }

  POSTS.forEach(function(post){ grid.appendChild(criarCard(post)); });

  var overlay, lastFocused;

  function build(){
    overlay = document.createElement('div');
    overlay.className = 'post-modal';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.innerHTML =
      '<div class="post-modal-panel">' +
        '<button type="button" class="post-modal-close" aria-label="Fechar">✕</button>' +
        '<div class="post-modal-img"><img alt=""></div>' +
        '<div class="post-modal-body">' +
          '<span class="novidade-tag"></span>' +
          '<h3></h3>' +
          '<span class="novidade-data"></span>' +
          '<div class="post-modal-conteudo"></div>' +
        '</div>' +
      '</div>';
    document.body.appendChild(overlay);

    overlay.querySelector('.post-modal-close').addEventListener('click', closePost);
    overlay.addEventListener('click', function(e){ if (e.target === overlay) closePost(); });
    document.addEventListener('keydown', function(e){
      if (e.key === 'Escape' && overlay.classList.contains('is-open')) closePost();
    });
  }

  function openPost(post, trigger){
    if (!overlay) build();
    lastFocused = trigger;
    var img = overlay.querySelector('.post-modal-img img');
    img.src = post.imagem;
    img.alt = post.titulo;
    overlay.querySelector('.post-modal-body .novidade-tag').textContent = post.unidade;
    overlay.querySelector('.post-modal-body h3').textContent = post.titulo;
    overlay.querySelector('.post-modal-body .novidade-data').textContent = post.data;
    var conteudo = overlay.querySelector('.post-modal-conteudo');
    conteudo.innerHTML = '';
    (post.conteudo || []).forEach(function(paragrafo){
      var p = document.createElement('p');
      p.textContent = paragrafo;
      conteudo.appendChild(p);
    });
    overlay.classList.add('is-open');
    document.body.style.overflow = 'hidden';
    overlay.querySelector('.post-modal-close').focus();
  }

  function closePost(){
    if (!overlay) return;
    overlay.classList.remove('is-open');
    document.body.style.overflow = '';
    if (lastFocused) lastFocused.focus();
  }
})();

// Carrossel de fotos (autoplay, pausa no hover/toque, arraste nativo no celular)
(function(){
  document.querySelectorAll('.carrossel').forEach(function(carrossel){
    var track = carrossel.querySelector('.carrossel-track');
    var slides = track ? Array.prototype.slice.call(track.querySelectorAll('img')) : [];
    if (!track || slides.length < 2) return;

    var intervaloMs = parseInt(carrossel.getAttribute('data-autoplay'), 10) || 4000;
    var indice = 0;
    var timer = null;

    var dotsWrap = document.createElement('div');
    dotsWrap.className = 'carrossel-dots';
    slides.forEach(function(_, i){
      var dot = document.createElement('button');
      dot.type = 'button';
      dot.setAttribute('aria-label', 'Ir para foto ' + (i + 1));
      dot.addEventListener('click', function(){ irPara(i); reiniciarAutoplay(); });
      dotsWrap.appendChild(dot);
    });

    var prev = document.createElement('button');
    prev.type = 'button';
    prev.className = 'carrossel-prev';
    prev.setAttribute('aria-label', 'Foto anterior');
    prev.innerHTML = '‹';
    var next = document.createElement('button');
    next.type = 'button';
    next.className = 'carrossel-next';
    next.setAttribute('aria-label', 'Próxima foto');
    next.innerHTML = '›';

    carrossel.appendChild(prev);
    carrossel.appendChild(next);
    carrossel.appendChild(dotsWrap);

    function posicaoDoSlide(slide){
      return slide.getBoundingClientRect().left - track.getBoundingClientRect().left + track.scrollLeft;
    }

    function atualizarDots(){
      Array.prototype.forEach.call(dotsWrap.children, function(dot, i){
        dot.classList.toggle('active', i === indice);
      });
    }

    function irPara(i){
      indice = (i + slides.length) % slides.length;
      track.scrollTo({ left: posicaoDoSlide(slides[indice]), behavior: 'smooth' });
      atualizarDots();
    }

    function iniciarAutoplay(){
      pararAutoplay();
      timer = setInterval(function(){ irPara(indice + 1); }, intervaloMs);
    }
    function pararAutoplay(){
      if (timer) clearInterval(timer);
      timer = null;
    }
    function reiniciarAutoplay(){ iniciarAutoplay(); }

    next.addEventListener('click', function(){ irPara(indice + 1); reiniciarAutoplay(); });
    prev.addEventListener('click', function(){ irPara(indice - 1); reiniciarAutoplay(); });
    carrossel.addEventListener('mouseenter', pararAutoplay);
    carrossel.addEventListener('mouseleave', iniciarAutoplay);
    carrossel.addEventListener('touchstart', pararAutoplay, { passive: true });
    carrossel.addEventListener('touchend', function(){ setTimeout(iniciarAutoplay, 3000); }, { passive: true });

    var scrollTimer;
    track.addEventListener('scroll', function(){
      clearTimeout(scrollTimer);
      scrollTimer = setTimeout(function(){
        var meio = track.scrollLeft + track.clientWidth / 2;
        var maisPerto = 0, menorDist = Infinity;
        slides.forEach(function(slide, i){
          var centro = posicaoDoSlide(slide) + slide.offsetWidth / 2;
          var dist = Math.abs(centro - meio);
          if (dist < menorDist) { menorDist = dist; maisPerto = i; }
        });
        indice = maisPerto;
        atualizarDots();
      }, 100);
    });

    atualizarDots();
    iniciarAutoplay();
  });
})();

// Carrossel de modalidades (home) — navegação. O clique-pra-expandir é o mesmo dos horários por modalidade (acima).
(function(){
  var carrossel = document.querySelector('.modalidades-carrossel');
  if (!carrossel) return;
  var track = carrossel.querySelector('.modalidades-carrossel-track');
  var itens = track ? Array.prototype.slice.call(track.children) : [];
  if (!itens.length) return;

  var prev = carrossel.querySelector('.carrossel-prev');
  var next = carrossel.querySelector('.carrossel-next');
  var dotsWrap = carrossel.querySelector('.modalidades-carrossel-dots');

  itens.forEach(function(_, i){
    var dot = document.createElement('button');
    dot.type = 'button';
    dot.setAttribute('aria-label', 'Ir para modalidade ' + (i + 1));
    dot.addEventListener('click', function(){ irPara(i); });
    dotsWrap.appendChild(dot);
  });

  function posicaoDoItem(item){
    return item.getBoundingClientRect().left - track.getBoundingClientRect().left + track.scrollLeft;
  }

  function indiceAtual(){
    var meio = track.scrollLeft + track.clientWidth / 2;
    var maisPerto = 0, menorDist = Infinity;
    itens.forEach(function(item, i){
      var centro = posicaoDoItem(item) + item.offsetWidth / 2;
      var dist = Math.abs(centro - meio);
      if (dist < menorDist) { menorDist = dist; maisPerto = i; }
    });
    return maisPerto;
  }

  function atualizarDots(){
    var atual = indiceAtual();
    Array.prototype.forEach.call(dotsWrap.children, function(dot, i){
      dot.classList.toggle('active', i === atual);
    });
  }

  function irPara(i){
    i = Math.max(0, Math.min(itens.length - 1, i));
    track.scrollTo({ left: posicaoDoItem(itens[i]), behavior: 'smooth' });
  }

  if (next) next.addEventListener('click', function(){ irPara(indiceAtual() + 1); });
  if (prev) prev.addEventListener('click', function(){ irPara(indiceAtual() - 1); });

  var scrollTimer;
  track.addEventListener('scroll', function(){
    clearTimeout(scrollTimer);
    scrollTimer = setTimeout(atualizarDots, 100);
  });

  atualizarDots();
})();
