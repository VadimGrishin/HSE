-- without time_delta
select                                  -- свертываем  hse_user_ext_id
  cid, cname
      , bid
      , mid, m_ord, m_name
      , lid, l_ord, l_name
      , iid, i_ord, i_name --, type_id, aq_ord
  , count(*) cnt
  , count(distinct hse_user_ext_id) user_cnt
  , max(max_aqord) max_aqord
  , min(reliab) mn_reliab
  , max(reliab) mx_reliab
  , avg(ssi2) ssi2
  , avg(sx2) sx2

from
(
  select                                -- свертываем question_ext_id
        cid, max(cname) cname
        , bid
        , mid, m_ord, max(m_name) m_name
        , lid, l_ord, max(l_name) l_name
        , iid, i_ord, max(i_name) i_name 
        , item_id, assessment_ext_id, hse_user_ext_id --, time_dlt 
        , sum(response_score)  resp_sum
        , sum(question_var) ssi2
        , count(*) k
        , max(max_aqord) max_aqord
        , variance(sum(response_score)) over (partition by assessment_ext_id) sx2
        , (1 - sum(question_var) / (variance(sum(response_score)) over (partition by assessment_ext_id) + 0.01)/ (1.01 - 1/count(*))) reliab

    from
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
    --      join -- если преподаватель поменял вопрос, то для каждого question.ord оставляем assessment самого свежего вопроса Здесь это не нужно, ура!!!
    --       (select assessment_id, ord, max(update_ts) update_ts from coursera_structure.assessment_question aq2
    --         join coursera_structure.question q2 on aq2.question_id=q2.id
    --         group by assessment_id, ord ) aqq on aqq.assessment_id=a.id and aqq.update_ts=q.update_ts
          left join csess_event s on s.branch_ext_id=b.ext_id
          left join coursera_structure.item_type it on it.id=i.type_id
        
           where it.graded = True and c.id=123
    
          group by c.id, c.name, b.ext_id, m.ext_id, m.ord, m.name, l.ext_id, l.ord, l.name
          , i.ext_id, i.ord, i.name, i.type_id, c.load_id, ia.item_id, aq.ord,  aq.internal_id, a.id, a.ext_id, aq.question_id, q.ext_id     
    
      ) as struc
    
    join
    
       ( 
          select  
            item_id, assessment_ext_id, question_ext_id, response_score, hse_user_ext_id --, (action_ts - action_start_ts) time_dlt 
            , variance(response_score) over(partition by item_id, assessment_ext_id, question_ext_id) question_var 
            
          from caq_event 
          join
             ( 
              select course_id, hse_user_ext_id, ia.item_id, min(action_start_ts) action_start_ts --, assessment_ext_id
               from caq_event
                join coursera_structure.assessment a on a.ext_id=assessment_ext_id and a.load_id=81 --!!!!
                join coursera_structure.assessment_type at on at.id=a.type_id
                join coursera_structure.item_assessment ia on ia.assessment_id=a.id
              where course_id=123 and question_ext_id is not null and a.type_id=7 --7=summative
              group by course_id, hse_user_ext_id, ia.item_id --, action_version  , assessment_ext_id
             )   as x using(course_id, hse_user_ext_id, action_start_ts) --, action_version , assessment_ext_id
         where question_ext_id is not null   -- рабочая гипотеза: есть акции, которые стартуют одновременно, но среди них не более одной, которая с вопросами-ответами
        ) as xx
    using(item_id, assessment_ext_id, question_ext_id)

  group by cid, bid, m_ord, mid, l_ord, lid, i_ord, iid, item_id, assessment_ext_id, hse_user_ext_id --, time_dlt
  order by cid, bid, m_ord, mid, l_ord, lid, i_ord, iid, item_id, assessment_ext_id, rank() OVER (PARTITION BY item_id ORDER BY sum(response_score), hse_user_ext_id ) --, time_dlt desc

  ) as user_range
 where user_range.k = max_aqord + 1 -- считаем браком курсеры тесты, на которые юзер ответил не полностью (ответов меньше чем вопросов), и выбрасываем их

--) as yy
group by cid, cname
      , bid
      , mid, m_ord, m_name
      , lid, l_ord, l_name
      , iid, i_ord, i_name --, type_id, aq_ord

order by cid, cname
      , bid
      , m_ord
      , l_ord
      , i_ord
    
