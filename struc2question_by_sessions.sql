select * from
(select c.id, c.name cname
  , b.ext_id bid
  , m.ext_id mid, m.ord m_ord, m.name m_name
  , l.ext_id lid, l.ord l_ord, l.name l_name
  , i.ext_id iid, i.ord i_ord, i.name i_name, i.type_id, max(it.descr) descr, max(cast(it.graded as int)) graded
  , c.load_id, ia.item_id, aq.ord aq_ord, aq.internal_id, a.id ass_id, a.ext_id ass_ext_id, aq.question_id, q.ext_id qext_id, max(q.prompt)
  , min(on_demand_sessions_start_ts) strt
  , max(on_demand_sessions_end_ts) fin
  , rank() OVER (PARTITION BY c.name, b.ext_id ORDER BY c.load_id) rnk
  , cume_dist() OVER (PARTITION BY c.name, b.ext_id ORDER BY c.load_id) cd
  --, count(distinct aq.internal_id) as q_cnt
   
  from coursera_structure.course c

  left join coursera_structure.branch b on b.course_id=c.id
  left join coursera_structure.module m on m.branch_id = b.id
  left join coursera_structure.lesson l on l.module_id = m.id
  left join coursera_structure.item i on i.lesson_id = l.id
  left join coursera_structure.item_assessment ia on ia.item_id=i.id
  join coursera_structure.assessment a on a.id=ia.assessment_id
  left join coursera_structure.assessment_question aq on aq.assessment_id=a.id 
  left join coursera_structure.question q on aq.question_id=q.id
  left join csess_event s on s.branch_ext_id=b.ext_id
  left join coursera_structure.item_type it on it.id=i.type_id

  group by c.id, c.name, b.ext_id, m.ext_id, m.ord, m.name, l.ext_id, l.ord, l.name
  , i.ext_id, i.ord, i.name, i.type_id, c.load_id, ia.item_id, aq.ord,  aq.internal_id, a.id, a.ext_id, aq.question_id, q.ext_id     --a.id,
  
  order by c.name, b.ext_id, m_ord, l_ord, i_ord, aq.ord, aq.internal_id, c.id, c.load_id
  ) as x
 where graded = 1 and x.cd=1 and cname='Algorithmic Toolbox' 
