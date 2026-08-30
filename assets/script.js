// ===== Boha Fitness — script compartilhado =====

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

// Números de WhatsApp por unidade
var BOHA_WHATSAPP = {
  "Jardim Santa Tereza": "5511976976483",
  "Jardim Casa Branca": "5511918526915",
  "Jardim Macedônia": "5511969186057"
};
var BOHA_WHATSAPP_PADRAO = "5511976976483";

// Formulário de matrícula -> WhatsApp
(function(){
  var form = document.getElementById('formMatricula');
  if (!form) return;
  form.addEventListener('submit', function(e){
    e.preventDefault();
    var nome = (document.getElementById('nome') || {}).value || '';
    var whatsapp = (document.getElementById('whatsapp') || {}).value || '';
    var unidadeEl = document.getElementById('unidade');
    var unidade = unidadeEl ? unidadeEl.value : '';
    var planoEl = document.getElementById('plano');
    var plano = planoEl ? planoEl.value : '';
    var numero = BOHA_WHATSAPP[unidade] || BOHA_WHATSAPP_PADRAO;
    var msg = 'Olá! Quero me matricular na Boha Fitness.%0A' +
      'Nome: ' + encodeURIComponent(nome) + '%0A' +
      'WhatsApp: ' + encodeURIComponent(whatsapp) + '%0A' +
      'Unidade: ' + encodeURIComponent(unidade || 'não informado') + '%0A' +
      'Plano: ' + encodeURIComponent(plano || 'não informado');
    window.open('https://wa.me/' + numero + '?text=' + msg, '_blank');
  });
})();
