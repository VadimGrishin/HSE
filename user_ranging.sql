select  item_id, assessment_ext_id, hse_user_ext_id, resp_sum, (action_ts - action_start_ts) time_dlt 
  , rank() OVER (PARTITION BY item_id ORDER BY resp_sum, (action_ts - action_start_ts) desc, hse_user_ext_id ) rnk 
  , cume_dist() OVER (PARTITION BY item_id ORDER BY resp_sum, (action_ts - action_start_ts) desc, hse_user_ext_id ) cd
  , question_ext_id, response_score
  
from caq_event 

join
(
  select  item_id, assessment_ext_id, hse_user_ext_id, min(action_start_ts) action_start_ts, sum(response_score) resp_sum

  from caq_event
    join coursera_structure.assessment a on a.ext_id=assessment_ext_id
    join coursera_structure.assessment_type at on at.id=a.type_id 
    join coursera_structure.item_assessment ia on ia.assessment_id=a.id

  where course_id=123 and question_ext_id is not null and a.type_id=7
  group by item_id, assessment_ext_id, hse_user_ext_id
  
  )   as x using(hse_user_ext_id, assessment_ext_id, action_start_ts)

where caq_event.course_id=123 and question_ext_id is not null 

order by  item_id, assessment_ext_id, rnk 
