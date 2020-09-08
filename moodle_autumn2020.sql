CREATE OR REPLACE FUNCTION array_sort (ANYARRAY)
RETURNS ANYARRAY LANGUAGE SQL
AS $$
SELECT ARRAY(SELECT unnest($1) ORDER BY 1)
$$;

252494 

select steps, sgnt, count(*) cnt, max(qa_id), min(qa_id) qa_id from 
(
select qa_id, count(distinct qas_id) steps, array_sort(array_agg(concat(cast(qas_sequencenumber as text),':', qasd_name))) sgnt  
	from moodle_event.sheet_moodle group by qa_id
) x
group by steps, sgnt
order by cnt desc

select count(*), max(index), count(distinct index) from moodle_event.sheet_moodle

-- user_range_qo
CREATE TABLE moodle_event.user_range_qo
tablespace openeduevent as
select 
	s.*, s2.qasd_value qasd_order
	, case when (s.qasd_name like 'choice%') then SPLIT_PART(s2.qasd_value, ',', cast(substring(s.qasd_name, 7) as integer)+1)::integer  
		when (s.qasd_name='answer')  then q_aw.id  
		else 0 
    end stem
    , case when (s.qasd_name like 'choice%') then s.qasd_value::integer 
		when (s.qasd_name='answer' and q_aw2.id>0) then   (q_aw.id=q_aw2.id)::integer
		else 0
    end choice
	, q_aw.id stem_id, q_aw.answer stem_answer, q_aw.fraction stem_fraction
	, q_aw2.id choice_id, q_aw2.answer choice_answer, q_aw2.fraction choice_fraction
	, s3.response_score finish_score 
from moodle_event.sheet_moodle s
join -- 942 344 
	( -- 519 467  last step:
		select qa_id, max(qas_id) qas_id from moodle_event.sheet_moodle where (qasd_name like 'sub%' or qasd_name like 'choice%' or qasd_name='answer' or qas_state='gaveup')
		group by qa_id
	) last_step using(qa_id, qas_id)
-- join -- +: 903 121 
-- 	(
-- 		select distinct qa_id from moodle_event.sheet_moodle where (qasd_name='_order')
-- 	) ordr using(qa_id)
left join moodle_event.sheet_moodle s2 on s.qa_id=s2.qa_id and s2.qasd_name='_order'  -- 903121
left join moodle_event.sheet_moodle s3 on s.qa_id=s3.qa_id and s3.qasd_name='-finish' -- 903121
left join moodle_event.mdl_question_answers q_aw on q_aw.question=s.qid and s.qasd_name='answer'
left join moodle_event.mdl_question_answers q_aw2 on q_aw2.id=case 
	when (s.qasd_name like 'choice%') then SPLIT_PART(s2.qasd_value, ',', cast(substring(s.qasd_name, 7) as integer)+1)::integer 
	when (s.qasd_name='answer' and s2.qasd_name='_order')  then SPLIT_PART(s2.qasd_value, ',', cast(s.qasd_value as integer)+1)::integer 
	else 0 
end
order by s.index


select * from moodle_event.user_range_qo
where qid=83783  --252460 
order by index

update moodle_event.user_range_qo
set choice= ((qasd_value='0' and stem_answer='Неверно') 
			 or (qasd_value='1' and stem_answer='Верно')
			 or (qasd_value=stem_answer))::integer   -- Возможно надо сделать UPPER
where qasd_order is null

alter table moodle_event.user_range_qo
add column input_answer text

create table inp as
select 
	  qasd_id
	  , case when  sum( (qasd_value=stem_answer)::integer )=0
		   then max(qasd_value) 
		   else null
	   end input_answer
from moodle_event.user_range_qo
where qasd_order is null and not stem_answer like '%ерно'
group by qasd_id
having sum( (qasd_value=stem_answer)::integer )=0

update moodle_event.user_range_qo  urqo
set input_answer=
	(select input_answer from inp		
	 where urqo.qasd_id=inp.qasd_id
	)
where urqo.qasd_order is null and not stem_answer like '%ерно'	

alter table moodle_event.user_range_qo
add column option_val double precision,
add column display text

update moodle_event.user_range_qo  urqo
set option_val = case when qasd_name like 'choice%' then choice_fraction
			  	      -- when qasd_name='answer' and input_answer is null then stem_fraction
			   	      else stem_fraction
				end, 
	display = case when qasd_name like 'choice%' then choice_answer
			      -- when qasd_name='answer' and input_answer is null then stem_answer
			  else stem_answer
	          end 

alter table moodle_event.user_range_qo
add column qas_indicator integer

drop table indic

create table indic as
select distinct index, stem_id, choice_id, floor(cume_dist() OVER (PARTITION BY qas_id ORDER BY index, stem_id, choice_id)) qas_indicator
from  moodle_event.user_range_qo

select * from indic where stem_id = 293284 order by index, stem_id limit 100

select * from moodle_event.user_range_qo where qas_id = 2879818

create index ind_qasd_stem on indic(index, stem_id, choice_id, qas_indicator) TABLESPACE openeduevent

update moodle_event.user_range_qo  urqo
set qas_indicator = (select qas_indicator from indic where indic.index=urqo.index and coalesce(indic.stem_id, 0)=coalesce(urqo.stem_id, 0)  and coalesce(indic.choice_id, 0)=coalesce(urqo.choice_id, 0))


CREATE TABLE moodle_event.user_range_q
tablespace openeduevent as
select *
	,  count(*) over (partition by course_id, partnerid, groupid, mid, qz_id, userid) k_q
	, max(aq_ord) over (partition by course_id, partnerid, groupid, mid, qz_id, userid) max_aqord 
	, dense_rank() OVER (PARTITION BY course_id, partnerid, groupid, mid, qz_id ORDER BY sumgrades, userid) rnk 
	, cume_dist() OVER (PARTITION BY course_id, partnerid, groupid, mid, qz_id ORDER BY sumgrades, userid) cd 
	, variance(response_score) over(partition by course_id, partnerid, groupid, mid, qz_id, qid) question_var 
from
(
	select distinct course_id, partnerid, groupid, mid, qz_id, aq_ord, qid
		, case when qasd_name like 'choice%' then 'checkbox'
			   when qasd_name='answer' and qasd_order is not null then 'radio'
			   else null
		  end qtype
		, qa_id, questionsummary, rightanswer, responsesummary
		, qza_id, userid, sumgrades
		, qas_id, qas_state, qas_sequencenumber, finish_score response_score, qas_attm_time
	from moodle_event.user_range_qo ur_qo
	where ur_qo.attempt=1
) for_usr_q


CREATE TABLE moodle_event.user_range_a
tablespace openeduevent AS
select course_id, partnerid, groupid, mid,  qz_id  -- свертываем question_ext_id
	 , userid
	 , sum(response_score) resp_sum
	 , max(sumgrades) sumgrades
	 , sum(question_var) ssi2
	 , count(*) k_a
	 , max(max_aqord) max_aqord
	 , variance(sum(response_score)) over (partition by course_id, partnerid, groupid, mid, qz_id) sx2
	 , (1 - sum(question_var) / (variance(sum(response_score)) over (partition by course_id, partnerid, groupid, mid, qz_id) + 0.001))/ (1 - 1/(count(*)+0.001)) reliab
from moodle_event.user_range_q
group by course_id, partnerid, groupid, mid, qz_id, userid  

--str:
select                                 
		  3 platform_id
		  , course_id , c.fullname cname
		  , partnerid, groupid
		  , mid , m.section, m.name m_name
		  , qz_id quizid, q.name quizname
		  , count(*) cnt
		  , count(distinct userid) cnt_user
		  , max(max_aqord) max_aqord1
		  , min(k_a) k_min
		  , round(avg(k_a), 2) k_avg
		  , max(k_a) k_max
		  , min(reliab) mn_reliab
		  , max(reliab) mx_reliab
		  , avg(ssi2) ssi2
		  , avg(sx2)  sx2
from moodle_event.user_range_a ura
		join moodle_event.mdl_course c on ura.course_id=c.id
		join moodle_event.mdl_course_sections m on ura.mid=m.id
		join moodle_event.mdl_quiz q on	ura.qz_id=q.id	
group by course_id, c.fullname, partnerid, groupid 
	  , mid, m.section, m.name --, m_name
	  , qz_id, q.name -- , quizname
order by course_id, partnerid, groupid --, cname
	  , mid, qz_id

-- heat:
select                                  -- свертываем  hse_user_ext_id у user_range_q
			  3 platform_id
			  , course_id , c.fullname cname
			  , partnerid, groupid
			  , mid , m.section, m.name m_name
			  , qz_id , qz.name quizname
			  , aq_ord
			  , qid
			  , max(questiontext) prompt
			  , min(k_q) k_min
			  , max(k_q) k_max
			  , max(max_aqord) max_aqord1
			  , count(*) cnt
			  , sum(response_score) tot_num
			  , count(distinct userid) tot_denom 
			  , sum(case when cd > 0.75 then response_score else 0 end) stong_num, sum(case when cd > 0.75 then 1 else 0 end) strong_denom
			  , sum(case when cd < 0.25 then response_score else 0 end) weak_num, sum(case when cd < 0.25 then 1 else 0 end) weak_denom
from moodle_event.user_range_q urq
		join moodle_event.mdl_course c on urq.course_id=c.id
		join moodle_event.mdl_course_sections m on urq.mid=m.id
		join moodle_event.mdl_quiz qz on	urq.qz_id=qz.id	
		join moodle_event.mdl_question q on	urq.qid=q.id
group by course_id, c.fullname
	  , partnerid, groupid
	  , mid, m.section, m.name
	  , qz_id, qz.name
	  , aq_ord
	  , qid
order by course_id --, cname
	  , partnerid, groupid
	  , mid --, m_name
	  , qz_id --, quizname
	  , aq_ord
	  , qid

-- aud:
select  
			    3 platform_id
			    , usrqo.course_id , max(c.fullname) cname
				, usrqo.partnerid,  usrqo.groupid
				, usrqo.mid, max(m.section) section, max(m.name) m_name
		 		, usrqo.qz_id, max(qz.name) quizname
				-- , k_q, max_aqord
				, usrqo.aq_ord 
				, usrqo.qid, max(questiontext) prompt
				, case when qasd_name like 'choice%' then 'checkbox'
			  		   when qasd_name='answer' and qasd_order is not null then 'radio'
					   when qasd_name='answer' and qasd_order is null and stem_answer like '%ерно' then 'option'
					   when qasd_name='answer' and qasd_order is null and not stem_answer like '%ерно' then 'text'
			   		  else null
		  		end qtype
				, stem option_id
			    , option_val
				, min(usrqo.qas_state) min_state, max(usrqo.qas_state) max_state
                , max(display) display
				, count(*) cnt
				, sum(choice) tot_num -- количество выборов опций
				, sum(qas_indicator * finish_score) tot_num2 -- количество реальных баллов за вопрос, выставленных системой
				, count(distinct usrqo.userid) user_cnt
				, max(rnk) max_rnk
				, sum(case when cd<=0.25 then choice  else 0 end) weak_num
				, sum(case when cd<=0.25 then qas_indicator * finish_score  else 0 end) weak_num2
				, sum(case when cd<=0.25 then 1 else 0 end) weak_denom
				, sum(case when cd>0.75 then choice else 0 end) strong_num
				, sum(case when cd>0.75 then qas_indicator * finish_score else 0 end) strong_num2
				, sum(case when cd>0.75 then 1 else 0 end) strong_denom
				 
		from moodle_event.user_range_qo usrqo
          join moodle_event.user_range_q usrq using(qas_id)
		  join moodle_event.mdl_course c on usrqo.course_id=c.id
		  join moodle_event.mdl_course_sections m on usrqo.mid=m.id
		  join moodle_event.mdl_quiz qz on	usrqo.qz_id=qz.id	
		  join moodle_event.mdl_question q on	usrqo.qid=q.id
		group by usrqo.course_id, usrqo.partnerid,  usrqo.groupid, usrqo.mid
		, usrqo.qz_id
		-- , k_q, max_aqord - позволяет выделить юзеров, не ответивших на все вопросы теста в отдельную группу
		, usrqo.aq_ord, usrqo.qid
		, case when qasd_name like 'choice%' then 'checkbox'
			  		   when qasd_name='answer' and qasd_order is not null then 'radio'
					   when qasd_name='answer' and qasd_order is null and stem_answer like '%ерно' then 'option'
					   when qasd_name='answer' and qasd_order is null and not stem_answer like '%ерно' then 'text'
			   		  else null
		  end -- qtype
        , stem
        , option_val
		order by usrqo.course_id, usrqo.partnerid,  usrqo.groupid, usrqo.mid, usrqo.qz_id
        , usrqo.qid, usrqo.aq_ord
        , stem









-- aud 2 попытка вывести все набранные тексты:
select  
			    3 platform_id
			    , usrqo.course_id , max(c.fullname) cname
				, usrqo.partnerid,  usrqo.groupid
				, usrqo.mid, max(m.section) section, max(m.name) m_name
		 		, usrqo.qz_id, max(qz.name) quizname
				-- , k_q, max_aqord
				, usrqo.aq_ord -- , response_score
				, usrqo.qid, max(questiontext) prompt
                  -- , name
				, case when qasd_name like 'choice%' then 'checkbox'
			  		   when qasd_name='answer' and qasd_order is not null then 'radio'
					   when qasd_name='answer' and qasd_order is null and stem_answer like '%ерно' then 'option'
					   when qasd_name='answer' and qasd_order is null and not stem_answer like '%ерно' then 'text'
			   		  else null
		  		end qtype
--                 , case when substring(name, 1, 6)='answer' then 'radio'
-- 				  else 'checkbox'
--                 end answ_type
--                 , case when substring(name, 1, 6)='answer' then  q_aw.id 
--                        else stem
--                 end option_id
				   -- , case when input_answer is null then stem else null end option_id
				   , option_val
				   , display
				   --, choice
--                 , case when substring(name, 1, 6)='answer' then  q_aw.fraction 
--                        else option_val
--                 end option_val
				, input_answer figment
				, min(usrqo.qas_state) min_state, max(usrqo.qas_state) max_state
                --, max(case when substring(name, 1, 6)='answer' then q_aw.answer else option_txt end) display
				, count(*) cnt
				, sum(choice) tot_num
				, count(distinct usrqo.userid) user_cnt
				, max(rnk) max_rnk
				, sum(case when cd<=0.25 then choice  else 0 end) weak_num
				, sum(case when cd<=0.25 then 1 else 0 end) weak_denom
				, sum(case when cd>0.75 then choice else 0 end) strong_num
				, sum(case when cd>0.75 then 1 else 0 end) strong_denom

		from moodle_event.user_range_qo usrqo
          join moodle_event.user_range_q usrq using(qas_id)
		  join moodle_event.mdl_course c on usrqo.course_id=c.id
		  join moodle_event.mdl_course_sections m on usrqo.mid=m.id
		  join moodle_event.mdl_quiz qz on	usrqo.qz_id=qz.id	
		  join moodle_event.mdl_question q on	usrqo.qid=q.id
		group by usrqo.course_id, usrqo.partnerid,  usrqo.groupid, usrqo.mid
		--, m_name
		, usrqo.qz_id
		--, quizname
		-- , k_q, max_aqord
		, usrqo.aq_ord, usrqo.qid
		, case when qasd_name like 'choice%' then 'checkbox'
			  		   when qasd_name='answer' and qasd_order is not null then 'radio'
					   when qasd_name='answer' and qasd_order is null and stem_answer like '%ерно' then 'option'
					   when qasd_name='answer' and qasd_order is null and not stem_answer like '%ерно' then 'text'
			   		  else null
		  end -- qtype
        -- , stem
		--, choice
        , option_val
		, display
		, input_answer -- figment  
		order by usrqo.course_id, usrqo.partnerid,  usrqo.groupid, usrqo.mid, usrqo.qz_id
        -- , cd
        , usrqo.qid, usrqo.aq_ord



select * from moodle_event.user_range_q where qid=82607
order by course_id, partnerid, groupid, qz_id, cd, userid, aq_ord
"platform_id"	"course_id"	"mid"	"qz_id"	"aq_ord"	"qid"	"k_min"	"k_max"	"max_aqord1"	"cnt"	"tot_num"	"tot_denom"	"stong_num"	"strong_denom"	"weak_num"	"weak_denom"
3					1570	16386	5116		10		82607		14		14		14			103			93			103			27			28				14			21

order by course_id, partnerid, groupid, qz_id, sumgrades desc, userid --, aq_ord
offset 10746 

select * from moodle_event.mdl_question_answers where id in(507169,507166,507165,507168,507167)

select qza_id, count(distinct aq_ord) from moodle_event.user_range_qo where qz_id=5188
group by qza_id
order by userid, aq_ord













































-- 531 955 
select distinct qa_id, qas_id from moodle_event.sheet_moodle where (qasd_name like 'choice%' or qasd_name='answer')


select steps, sgnt, count(*) cnt, max(qa_id), min(qa_id) qa_id from 
(
select qa_id, count(distinct qas_id) steps, array_sort(array_agg(concat(cast(qas_sequencenumber as text),':', qasd_name))) sgnt  
	from (
			select * from moodle_event.sheet_moodle -- 1 977 671
			join
			( -- 519 467
				select distinct qa_id from moodle_event.sheet_moodle where (qasd_name like 'choice%' or qasd_name='answer')
			) answerchoice using(qa_id)	
			join -- +: 1 892 234, отдельно:1 900 936(соответствует попыткам без "тела") 
			(
				select distinct qa_id from moodle_event.sheet_moodle where (qasd_name='_order')
			) ordr using(qa_id)			  
	) s
	group by qa_id
) x
group by steps, sgnt
order by cnt desc





