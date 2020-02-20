 select * from
 (
    select c.id cid, c.name cname
      , b.ext_id bid
      , m.ext_id mid, m.ord m_ord, m.name m_name
      , l.ext_id lid, l.ord l_ord, l.name l_name
      , i.ext_id iid, i.ord i_ord, i.name i_name, i.type_id, max(it.descr) descr, max(cast(it.graded as int)) graded
      , c.load_id, ia.item_id, aq.ord aq_ord, aq.internal_id, a.id ass_id, a.ext_id assessment_ext_id, aq.question_id, q.ext_id question_ext_id, max(q.prompt) prompt
      , min(on_demand_sessions_start_ts) strt
      , max(on_demand_sessions_end_ts) fin
      , max(aq.ord) OVER (PARTITION BY  b.ext_id, m.ord, l.ord, i.ord) max_aqord
       
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
    
       where it.graded = True and c.id=123

      group by c.id, c.name, b.ext_id, m.ext_id, m.ord, m.name, l.ext_id, l.ord, l.name
      , i.ext_id, i.ord, i.name, i.type_id, c.load_id, ia.item_id, aq.ord,  aq.internal_id, a.id, a.ext_id, aq.question_id, q.ext_id     
      
      order by c.name, b.ext_id, m_ord, l_ord, i_ord, aq.ord, aq.internal_id, c.id, c.load_id

  ) as struc

join

  ( 
    select  
      item_id, assessment_ext_id, hse_user_ext_id, (action_ts - action_start_ts) time_dlt 
      , sum(response_score)  resp_sum
      , rank() OVER (PARTITION BY item_id ORDER BY sum(response_score), (action_ts - action_start_ts) desc, hse_user_ext_id ) rnk 
      , cume_dist() OVER (PARTITION BY item_id ORDER BY sum(response_score), (action_ts - action_start_ts) desc, hse_user_ext_id ) cd
    from caq_event 
    join
       ( 
        select course_id, hse_user_ext_id, ia.item_id, assessment_ext_id, action_version, min(action_start_ts) action_start_ts
         from caq_event
          join coursera_structure.assessment a on a.ext_id=assessment_ext_id and a.load_id=81 --!!!!
          join coursera_structure.assessment_type at on at.id=a.type_id
          join coursera_structure.item_assessment ia on ia.assessment_id=a.id
        where course_id=123 and question_ext_id is not null and a.type_id=7 --7=summative
        group by course_id, hse_user_ext_id, ia.item_id, assessment_ext_id, action_version
       )   as x using(course_id, hse_user_ext_id, assessment_ext_id, action_start_ts, action_version)
    group by item_id, assessment_ext_id, hse_user_ext_id, (action_ts - action_start_ts)
  ) as user_range

using(item_id, assessment_ext_id)

order by  cname, bid, m_ord, l_ord, i_ord, aq_ord, user_range.cd
  --limit 1000



