-- проверка того, что sumgrades==sum(fraction):
select qza.quiz qzid, qza.userid, qza.attempt, qza.state quizstate, qza.sumgrades, sum(fraction) over (partition by qza.quiz, qza.userid) sumfraction
	, qsta.questionid qstid, qsta.questionusageid, qsta.questionsummary, qsta.rightanswer, qsta.responsesummary
    , qstas.state, fraction, attm_time
    -- , cm.* 
from mdl_quiz_attempts qza 
  join mdl_question_attempts qsta on qza.uniqueid=qsta.questionusageid
  join (
	select questionattemptid, state, fraction, FROM_UNIXTIME(timecreated, '%Y-%m-%d %H:%i:%s') attm_time
    from mdl_question_attempt_steps 
    where  state like 'grade%' or state='gaveup'
  )  qstas on qstas.questionattemptid=qsta.id
where qza.attempt=1;



drop table if exists user_range_q;
drop table if exists user_range_a;

CREATE TABLE user_range_q AS
select c.id course_id, c.shortname cname, cs.id mid, cs.name m_name, qz.id quizid, qz.name quizname
	, slt.slot aq_ord, qst.id qid, qst.questiontext
	-- , qza.attempt, qza.state quizstate, qza.sumgrades
    , qza.sumgrades
	, qsta.id questionattemptid, qsta.questionusageid, qsta.questionsummary, qsta.rightanswer, qsta.responsesummary
    , qstas.state, fraction response_score, attm_time
    ,  count(*) over (partition by c.id, cs.id, qz.id, userid) k_q
				, max(slt.slot) over (partition by c.id, cs.id, qz.id, userid) max_aqord 

				, dense_rank() OVER (PARTITION BY c.id, cs.id, qz.id ORDER BY qza.sumgrades, userid) rnk 
				, cume_dist() OVER (PARTITION BY c.id, cs.id, qz.id ORDER BY qza.sumgrades, userid) cd 
                , qza.userid
                , variance(fraction) over(partition by c.id, cs.id, qz.id, qst.id) question_var
from mdl_course_modules cm
  join mdl_course c on c.id=cm.course
  join mdl_course_sections cs on cs.id=cm.section
  join mdl_quiz qz on qz.id=cm.instance and qz.attempts>0 -- оставляем только обязательные
  join mdl_quiz_slots slt on slt.quizid=qz.id
  join mdl_question qst on qst.id=slt.questionid
  join mdl_quiz_attempts qza on qza.quiz=qz.id
  join mdl_question_attempts qsta on qsta.questionid=qst.id and qza.uniqueid=qsta.questionusageid
  join (
	select questionattemptid, state, fraction, FROM_UNIXTIME(timecreated, '%Y-%m-%d %H:%i:%s') attm_time
    from mdl_question_attempt_steps 
    where  state like 'grade%' or state='gaveup'
  )  qstas on qstas.questionattemptid=qsta.id
where module=25 and qza.attempt=1 -- and c.id=4
order by cm.course, cs.id, instance, dense_rank() OVER (PARTITION BY c.id, cs.id, qz.id ORDER BY qza.sumgrades, userid), slt.slot;

select * from user_range_q where questionattemptid=2766;

drop index user_range_q_qa_idx on user_range_q;
drop index last_step_options_qa_idx on last_step_options;

create unique index user_range_q_qa_idx on user_range_q (questionattemptid);
create index last_step_options_qa_idx on last_step_options (questionattemptid);

drop table if exists user_range_qo;

create table user_range_qo as
	select urq.*, lso.name, lso.stem, lso.choice, lso.option_val, lso.option_txt from user_range_q urq
	join last_step_options lso on urq.questionattemptid=lso.questionattemptid limit 200000;

select * from user_range_qo order by userid, questionattemptid, name;

CREATE TABLE  user_range_a AS
select course_id, max(cname) cname, mid, max(m_name) m_name, quizid, max(quizname) quizname  -- свертываем question_ext_id
 , userid
 
 , sum(response_score) resp_sum
 , max(sumgrades)
 
	, sum(question_var) ssi2
	, count(*) k_a
	, max(max_aqord) max_aqord
	, variance(sum(response_score)) over (partition by course_id, mid, quizid) sx2
	, (1 - sum(question_var) / (variance(sum(response_score)) over (partition by course_id, mid, quizid) + 0.001))/ (1 - 1/(count(*)+0.001)) reliab
from user_range_q
group by course_id, mid, quizid, userid  
order by course_id, mid, quizid
		   , rank() OVER (PARTITION BY course_id, mid, quizid ORDER BY sum(response_score), userid);


select * from user_range_a where quizid=109;

select                                 
		  3 platform_id
		  , course_id, cname
		  , mid, m_name
		  , quizid
          , quizname
		  , count(*) cnt
		  , count(distinct userid) cnt_user
		  , max(max_aqord) max_aqord1
		  , min(k_a) k_min
		  , max(k_a) k_max
		  , min(reliab) mn_reliab
		  , max(reliab) mx_reliab
		  , avg(ssi2) ssi2
		  , avg(sx2)  sx2
		from user_range_a
		group by course_id, cname
			  , mid, m_name
			  , quizid, quizname
		order by course_id, cname
			  , mid
			  , quizid; 



select                                  -- свертываем  hse_user_ext_id у user_range_q
			  3 platform_id
			  , course_id, max(cname) cname
			  , mid, m_name
			  , quizid, quizname
			  , aq_ord
			  , qid
			  , max(questiontext) prompt
			  , min(k_q) k_min
			  , max(k_q) k_max
			  , max(max_aqord) max_aqord1
			  , count(*) cnt
			  , sum(response_score) tot_num
			  , count(distinct userid) tot_denom 
			  -- , sum(response_score) / count(*) p
			  , sum(case when cd > 0.75 then response_score else 0 end) stong_num, sum(case when cd > 0.75 then 1 else 0 end) strong_denom
			  , sum(case when cd < 0.25 then response_score else 0 end) weak_num, sum(case when cd < 0.25 then 1 else 0 end) weak_denom
		from user_range_q
		group by course_id, cname
			  , mid, m_name
			  , quizid, quizname
			  , aq_ord
			  , qid
		order by course_id, cname
			  , mid, m_name
			  , quizid, quizname
			  , aq_ord
			  , qid;


select  
			    3 platform_id
			    , course_id, max(cname) cname
				, mid, m_name
		 		, quizid, quizname
				, k_q, max_aqord, aq_ord -- , response_score
				, qid questionid, max(questiontext) prompt
                  -- , name
                , case when substring(name, 1, 6)='answer' then 'radio'
				  else 'checkbox'
                end answ_type
                , case when substring(name, 1, 6)='answer' then  q_aw.id 
                       else stem
                end option_id
		 		   -- , choice
                   -- , userid, cd
                , case when substring(name, 1, 6)='answer' then  q_aw.fraction 
                       else option_val
                end option_val
                   -- , option_txt
                   -- , q_aw.id=stem, q_aw.id q_aw_id,  q_aw.answer, q_aw.fraction
                , max(case when substring(name, 1, 6)='answer' then q_aw.answer else option_txt end) display
				, count(*) cnt
				, count(distinct userid) user_cnt
				, sum(case when cd<0.25 then ((name='answer' and q_aw.id=stem) or (name like 'choice%' and choice=1)) else 0 end) weak_num
				, sum(case when cd<0.25 then 1 else 0 end) weak_denom
				, sum(case when cd>0.75 then ((name='answer' and q_aw.id=stem) or (name like 'choice%' and choice=1)) else 0 end) strong_num
				, sum(case when cd>0.75 then 1 else 0 end) strong_denom

		from user_range_qo 
         left join mdl_question_answers q_aw on q_aw.question=qid and name='answer'
		group by course_id, mid, m_name, quizid, quizname, k_q, max_aqord, aq_ord, qid, substring(name, 1, 6)
        , case when substring(name, 1, 6)='answer' then  q_aw.id 
                       else stem
                end
        , case when substring(name, 1, 6)='answer' then  q_aw.fraction 
                       else option_val
                end 
		order by course_id, mid, quizid
        -- , cd
        , qid, aq_ord
        , case when substring(name, 1, 6)='answer' then  q_aw.id 
                       else stem
                end;
        limit 1000;











select c.shortname, cs.name section, qz.id quizid, qz.name test, slt.slot, qst.questiontext, qst.id qstid
		, qza.userid, qza.attempt, qza.state quizstate, qza.sumgrades
	, qsta.questionusageid, qsta.questionsummary, qsta.rightanswer, qsta.responsesummary
    , qstas.state, fraction, attm_time
    -- , cm.* 
from mdl_course_modules cm
  join mdl_course c on c.id=cm.course
  join mdl_course_sections cs on cs.id=cm.section
  join mdl_quiz qz on qz.id=cm.instance and qz.attempts>0 -- оставляем только обязательные
  join mdl_quiz_slots slt on slt.quizid=qz.id
  join mdl_question qst on qst.id=slt.questionid
  join mdl_quiz_attempts qza on qza.quiz=qz.id
  join mdl_question_attempts qsta on qsta.questionid=qst.id and qza.uniqueid=qsta.questionusageid
  join (
	select questionattemptid, state, fraction, FROM_UNIXTIME(timecreated, '%Y-%m-%d %H:%i:%s') attm_time
    from mdl_question_attempt_steps 
    where  state like 'grade%' or state='gaveup'
  )  qstas on qstas.questionattemptid=qsta.id
where module=25 and qza.attempt=1 and c.id=4
order by cm.course, cs.id, instance, userid, slt.slot;