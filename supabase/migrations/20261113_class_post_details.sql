alter table public.boha_class_postings
  add column if not exists post_details jsonb not null default '[]'::jsonb;

delete from public.boha_class_schedule where unit='cb' and class_name='Step';
delete from public.boha_class_postings where unit='cb' and class_name='Step';

update public.boha_class_postings set
  post_dates=(select array_agg(d order by d) from (select unnest(post_dates) d union select date '2026-07-27') q),
  post_details=post_details||jsonb_build_array(jsonb_build_object('date','2026-07-27','caption','Se liga nessas duplas dando um show na aula de H.I.T.! 🔥 Aqui a motivação é em dobro e a evolução também! 💪 Treinar em dupla é ter incentivo, parceria e aquela energia extra pra ir além em cada exercício. Vem sentir essa experiência, desafiar seus limites e fazer parte dessa turma que não para de evoluir! 🚀💛','screen','Quando a dupla é boa, o treino rende ainda mais! 🚀'))
where unit='cb' and class_name='HIIT';

update public.boha_class_postings set
  post_dates=(select array_agg(d order by d) from (select unnest(post_dates) d union select date '2026-07-24') q),
  post_details=post_details||jsonb_build_array(jsonb_build_object('date','2026-07-24','caption','CROSS NA BOHA: intensidade, energia e evolução em cada treino! 🔥💪 Aqui, cada exercício é um desafio, cada repetição é uma conquista e cada aluno dá o seu melhor para evoluir. Com acompanhamento dos nossos professores e uma turma que motiva do início ao fim, o resultado é um treino completo e cheio de energia. Venha viver essa experiência com a gente! 🖤💛 #bohafitness #cross #sextou','screen','🏋️ CROSS NA BOHA'))
where unit='cb' and class_name='Cross';

update public.boha_class_postings set
  post_dates=(select array_agg(d order by d) from (select unnest(post_dates) d union select date '2026-07-24') q),
  post_details=post_details||jsonb_build_array(jsonb_build_object('date','2026-07-24','caption','💃 A @fernandaespacolaje provando que no Zumba as mulheres que comandam! 👑🔥 Muita energia, diversão e uma aula que faz todo mundo sair sorrindo! Quem participou sabe: aqui o treino vira festa. 💛✨ #bohafitness #zumba #vempraboha','screen','Quando as mulheres entram no ritmo, o resultado é esse!'))
where unit='cb' and class_name='Zumba';

update public.boha_class_postings set
  post_dates=(select array_agg(d order by d) from (select unnest(post_dates) d union select date '2026-07-14') q),
  post_details=post_details||jsonb_build_array(jsonb_build_object('date','2026-07-14','caption','🔥 Energia lá em cima e treino que entrega resultado! A aula de Jump da prof. Fernanda @fernandaespacolaje é sempre sinônimo de muita animação, intensidade e eficiência. 💛 Cada música é um incentivo pra você se movimentar, queimar calorias e sair da aula com aquela sensação de missão cumprida. Se você ainda não experimentou, essa é a sua chance! Vem sentir a energia da BOHA e descobrir por que essa aula conquista tanta gente. 🚀 #bohafitness #jump #treinoemgrupo','screen','POV: Você veio para a aula de Jump na Boha'))
where unit='cb' and class_name='Jump';

update public.boha_class_postings set
  post_dates=(select array_agg(d order by d) from (select unnest(post_dates) d union select date '2026-06-27' union select date '2025-09-19') q),
  post_details=post_details||jsonb_build_array(
    jsonb_build_object('date','2026-06-27','caption','Quadrilha + sertanejo + comida = Arraiá Boha! 🤠🎉 A festa foi agitada do início ao fim, com muita energia, animação e aquele clima de arraiá que só a Boha Fitness tem. Foi incrível demais! 💛 #bohafitness #arraiá #sertanejo #festajunina #boha','screen',''),
    jsonb_build_object('date','2025-09-19','caption','💃🔥 Relembrando as nossas aulas de Sertanejo na Boha Fitness! Aqui a gente mistura treino, dança e diversão pra manter o corpo ativo e a energia lá em cima. Quem aí já participou dessas aulas? 👀👇 #BohaFitness #SertanejoFitness #DançaQueTransforma #EnergiaBoha','screen',''))
where unit='cb' and class_name='Sertanejo';

update public.boha_class_postings set
  post_dates=(select array_agg(d order by d) from (select unnest(post_dates) d union select date '2025-10-28') q),
  post_details=post_details||jsonb_build_array(jsonb_build_object('date','2025-10-28','caption','Mais que uma luta, um estilo de vida. 👊 Assim são as nossas aulas de Jiu-Jitsu na Boha Fitness: foco total, técnica apurada e muito companheirismo. Transforme sua rotina e descubra sua força. Clique no link da bio e agende sua primeira aula! #bohafitness #jiujitsu #bjj #academia #treinopesado #comunidadebjj #artesuave','screen',''))
where unit='cb' and class_name='Jiu-Jitsu';

update public.boha_class_postings set
  post_dates=(select array_agg(d order by d) from (select unnest(post_dates) d union select date '2026-07-21') q),
  post_details=post_details||jsonb_build_array(jsonb_build_object('date','2026-07-21','caption','Pilates vai muito além do alongamento. 💛 Cada movimento fortalece seu corpo de dentro para fora, melhora a postura, ativa o core e desenvolve força com controle e consciência. Na BOHA, nossas aulas são pensadas para quem busca mais qualidade de vida, menos dores e um corpo mais forte para a rotina. ✅ Melhora a postura · Fortalece o core · Define e tonifica a musculatura. Seu corpo sente a diferença em cada aula.','screen','3 coisas que o pilates faz com o seu corpo!!'))
where unit='cb' and class_name='Pilates';

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Termômetro das aulas mais simples de acompanhar',
  'Agora os cards mostram os dias da aula, a última postagem, a barra e a prioridade. Toque ou passe o mouse para ver horários, legendas e registrar uma postagem. Step foi removido da unidade Casa Branca.',
  'marketing',array['admin','marketing'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Termômetro das aulas mais simples de acompanhar');
