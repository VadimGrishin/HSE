drop table edu_first

create TEMPORARY  table edu_first as
select distinct
	substring(problem_id from 14 for position('+' in substring(problem_id from 14 for 100))-1) course, 
	substring(question_id from 1 for position('_' in substring(question_id from 1 for 100))-1) problem,
	max_grade, grade, success,
	input_type,
	question_id, question_txt,
	user_id, username,
	case when resp_correct then 1 else 0 end response_score
from openedu_event.sheet 
where attempts = 1
order by substring(problem_id from 14 for position('+' in substring(problem_id from 14 for 100))-1),
	substring(question_id from 1 for position('_' in substring(question_id from 1 for 100))-1),
	username, question_id
	

drop table edu_q

create table edu_q as
select course, problem,
    max_grade, grade, success,
	input_type,
	question_id, question_txt,
	user_id, username, response_score,
	variance(response_score) over (partition by  course, problem, question_id) question_var
	, count(*) OVER (PARTITION BY course, problem, user_id) k
	, rank() OVER (PARTITION BY course, problem ORDER BY grade, user_id ) rnk --, time_dlt desc
	, cume_dist() OVER (PARTITION BY course, problem ORDER BY grade, user_id ) cd  --, time_dlt desc
from edu_first 
 --where input_type = 'formulaequationinput'

select * from openedu_event.sheet where question_id  like '4dc723eb2efa4bc8b7aa14d400ee9f8f%' and user_id=1518871 order by course, problem, question_id, user_id

drop table edu_a

create  table edu_a as
select -- свертываем question_id
    course, problem, user_id,
    max(max_grade) max_grade, min(max_grade) minmax, 
	count(*) k,
	max(grade) grade, min(grade) min_grade, max(success) success,
	
    sum(response_score) resp_sum,
	sum(question_var) ssi2,
	variance(sum(response_score)) over (partition by course, problem) sx2
from edu_q	
group by course, problem, user_id	
	
select  course, problem, 
		count(*) cnt, count(distinct user_id) cnt_user,
		max(max_grade) max_grade, min(minmax) minmax, min(k) k_min, max(k) k_max, min(ssi2) ssi2, min(sx2) sx2
from edu_a
group by course, problem

select c.name cname, c.ext_id cid, ch.name chapter, s.name sequential, v.name vertical, i.name problem, cnt, cnt_user, max_grade, minmax, k_min, k_max, ssi2, sx2 
from openedu_structure.course c
	join openedu_structure.chapter ch on ch.course_id=c.id 
	join openedu_structure.sequential s on s.chapter_id=ch.id
	join openedu_structure.vertical v on v.sequential_id=s.id
	join openedu_structure.item i on i.vertical_id=v.id
	join
	(
		select  course, problem, 
			count(*) cnt, count(distinct user_id) cnt_user,
			max(max_grade) max_grade, min(minmax) minmax, min(k) k_min, max(k) k_max, min(ssi2) ssi2, min(sx2) sx2
		from edu_a
		group by course, problem
	) as lg 
	on lg.problem=i.ext_id
where i.item_type='problem'
order by cname, ch.id, s.id,v.id, i.id

-- heat:
select c.name cname, c.ext_id cid, ch.name chapter, s.name sequential, v.name vertical, i.name problem, q_num, question_txt,
       cnt, cnt_user, max_grade, minmax, k_min, k_max, 
	   tot_num, tot_denom, strong_num, strong_denom, weak_num, weak_denom
from openedu_structure.course c
	join openedu_structure.chapter ch on ch.course_id=c.id 
	join openedu_structure.sequential s on s.chapter_id=ch.id
	join openedu_structure.vertical v on v.sequential_id=s.id
	join openedu_structure.item i on i.vertical_id=v.id
	join
	(
		select  course, problem, question_id, max(question_txt) question_txt,
				cast(substring(question_id from position('_' in question_id)+1 for position('_' in substring(question_id from position('_' in question_id)+1 for 100))-1) as integer) - 1 q_num,
				count(*) cnt, count(distinct user_id) cnt_user,
				max(max_grade) max_grade, min(max_grade) minmax, min(k) k_min, max(k) k_max
				, sum(response_score) tot_num
				, count(distinct user_id) tot_denom 
				, sum(case when cd > 0.75 then response_score else 0 end) strong_num, sum(case when cd > 0.75 then 1 else 0 end) strong_denom
				, sum(case when cd < 0.25 then response_score else 0 end) weak_num, sum(case when cd < 0.25 then 1 else 0 end) weak_denom
		from edu_q
		group by course, problem, question_id
	) as lg 
	on lg.problem=i.ext_id
where i.item_type='problem'
order by cname, ch.id, s.id,v.id, i.id, q_num
 


