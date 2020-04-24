-- FUNCTION: data_mart.app0_ins(integer)

-- DROP FUNCTION data_mart.app0_ins(integer);

CREATE OR REPLACE FUNCTION data_mart.app0_ins(
	load_id integer)
    RETURNS text
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
    
AS $BODY$DECLARE
	xcourse_id int;
	xstr_cnt int; xheat_cnt int; xaud_cnt int;
	xstr text; 	xheat text; xaud text; ret_val text;
	text_var1 text; text_var2 text; text_var3 text;
	time_steps text; time_point text;
	--time_steps timestamp; struc_time timestamp; first_attempt_time timestamp; user_range_q_time timestamp;
	--user_range_a_time timestamp; user_range_q_o_time timestamp; 
	--str_time timestamp; heat_time timestamp; aud_time timestamp; fin_time timestamp; 
BEGIN
  --SET enable_seqscan TO off;
  
  select id from coursera_structure.course c 
     where c.load_id =app0_ins.load_id into xcourse_id;
  
  xstr = ' | coursera_str: -';
  xheat = ' | coursera_heat: -';
  xaud = ' | coursera_aud: -';
  
  select count(*) from data_mart.str_ where course_id = xcourse_id into xstr_cnt;
  select count(*) from data_mart.heat where course_id = xcourse_id into xheat_cnt;
  select count(*) from data_mart.aud where course_id = xcourse_id into xaud_cnt;
  
  -- если чего-то не хватает, делаем основную работу по созданию вспомогательных таблиц ***************
  if (xstr_cnt * xheat_cnt * xaud_cnt = 0) then
  
    RAISE NOTICE 'quit0 %', clock_timestamp();
		drop table if exists struc;
		drop table if exists first1;
		drop table if exists first2;
		drop table if exists first_attempt;
		drop table if exists user_range_a; 
		drop table if exists user_range_q;
		drop table if exists user_range_q_o;
		
		select cast(clock_timestamp() as text) into time_point;
		time_steps = '*start:         ' || time_point; 
		
		CREATE TABLE  struc AS
		-- struc
		select c.id course_id, c.name cname
				  , b.ext_id bid
				  , m.ext_id mid, m.ord m_ord, m.name m_name
				  , l.ext_id lid, l.ord l_ord, l.name l_name
				  , i.ext_id iid, i.ord i_ord, i.name i_name, i.type_id, max(it.descr) descr, max(cast(it.graded as int)) graded
				  , c.load_id, ia.item_id, aq.ord aq_ord, aq.internal_id, a.id ass_id, a.ext_id assessment_ext_id, aq.question_id qid 
				  , q.ext_id question_ext_id, max(q.prompt) prompt, min(q.update_ts) q_update_ts
				  , min(on_demand_sessions_start_ts) strt
				  , max(on_demand_sessions_end_ts) fin
				  , max(aq.ord) OVER (PARTITION BY  b.ext_id, m.ord, l.ord, i.ord, a.id) max_aqord
		--into temporary table struc
		from  coursera_structure.course c
			  left join coursera_structure.branch b on b.course_id=c.id
			  left join coursera_structure.module m on m.branch_id = b.id
			  left join coursera_structure.lesson l on l.module_id = m.id
			  left join coursera_structure.item i on i.lesson_id = l.id
			  left join coursera_structure.item_assessment ia on ia.item_id=i.id
			  left join coursera_structure.assessment a on a.id=ia.assessment_id
			  left join coursera_structure.assessment_question aq on aq.assessment_id=a.id 
			  left join coursera_structure.question q on aq.question_id=q.id
			  left join coursera_event.csess_event s on s.branch_ext_id=b.ext_id
			  left join coursera_structure.item_type it on it.id=i.type_id
		where it.graded = True and c.id=xcourse_id --49
		group by c.id, c.name, b.ext_id, m.ext_id, m.ord, m.name, l.ext_id, l.ord, l.name
		, i.ext_id, i.ord, i.name, i.type_id, c.load_id, ia.item_id, aq.ord,  aq.internal_id, a.id, a.ext_id, aq.question_id, q.ext_id;
        
		select cast(clock_timestamp() as text) into time_point;
        time_steps = time_steps || '*struc:         ' || time_point;
		RAISE NOTICE 'struc %', clock_timestamp();
		
	-- first attempt block:
		CREATE TABLE first1 AS
		select course_id, hse_user_ext_id, ia.item_id, action_start_ts, min(action_ts) action_ts --, assessment_ext_id
		from coursera_event.caq_event
			join coursera_structure.assessment a on a.ext_id=assessment_ext_id and a.load_id=app0_ins.load_id --90 --!!!!
			join coursera_structure.assessment_type at on at.id=a.type_id
			join coursera_structure.item_assessment ia on ia.assessment_id=a.id
		where course_id=xcourse_id and question_ext_id is not null and a.type_id=7 --7=summative
		group by course_id, hse_user_ext_id, ia.item_id, action_start_ts; --, action_version  , assessment_ext_id
	RAISE NOTICE 'first1 %', clock_timestamp();
		
		CREATE TABLE first2 AS
		select course_id, hse_user_ext_id, item_id, min(action_start_ts) action_start_ts, min(action_ts) action_ts
		from first1
		group by course_id, hse_user_ext_id, item_id;
		
		RAISE NOTICE 'first2 %', clock_timestamp();
		
		CREATE TABLE first_attempt AS 
		select  
					item_id, assessment_ext_id, question_ext_id, response_score, hse_user_ext_id --, (action_ts - action_start_ts) time_dlt 
					, sum(response_score) over (partition by item_id, assessment_ext_id, hse_user_ext_id) resp_sum
					, variance(response_score) over(partition by item_id, assessment_ext_id, question_ext_id) question_var
					, response_ext_id          
		from coursera_event.caq_event 
			join first2 using(course_id, hse_user_ext_id, action_ts, action_start_ts)
		where question_ext_id is not null;
		
		select cast(clock_timestamp() as text) into time_point;
		time_steps = time_steps || '*first_attempt: ' || time_point;
	RAISE NOTICE 'first_attempt %', clock_timestamp();
	-- end of first attempt block

        CREATE TABLE user_range_q AS
		-- user_range_q
		select                                -- ранжируем юзеров в рамках item'ов, при этом не свертываем question_ext_id
				struc.course_id,  cname
				, bid, strt, fin
				, mid, m_ord,  m_name
				, lid, l_ord,  l_name
				, iid, i_ord,  i_name 
				, aq_ord
				, struc.item_id
				, struc.assessment_ext_id
				, struc.question_ext_id
				, struc.q_update_ts
				, qid
				, prompt
				, hse_user_ext_id
				, response_score
				, first_attempt.response_ext_id

				-- нужно для контроля сбоев:
				, count(*) over (partition by struc.course_id, bid, m_ord, mid, l_ord, lid, i_ord, iid, struc.item_id, struc.assessment_ext_id, hse_user_ext_id) k_q
				, max(max_aqord) over (partition by struc.course_id, bid, m_ord, mid, l_ord, lid, i_ord, iid, struc.item_id, struc.assessment_ext_id, hse_user_ext_id) max_aqord --, struc.assessment_ext_id

				, rank() OVER (PARTITION BY struc.item_id ORDER BY resp_sum, hse_user_ext_id ) rnk --, time_dlt desc
				, cume_dist() OVER (PARTITION BY struc.item_id ORDER BY resp_sum, hse_user_ext_id ) cd  --, time_dlt desc
		--into user_range_q
		from struc
		join first_attempt using(item_id, assessment_ext_id, question_ext_id);
		
		select cast(clock_timestamp() as text) into time_point;
		time_steps = time_steps || '*user_range_q:  ' || time_point;
	RAISE NOTICE 'user_range_q %', clock_timestamp();

		CREATE TABLE  user_range_a AS
		-- user_range_a
		select                                -- свертываем question_ext_id
			struc.course_id, max(cname) cname
			, bid
			, mid, m_ord, max(m_name) m_name
			, lid, l_ord, max(l_name) l_name
			, iid, i_ord, max(i_name) i_name 
			, item_id, assessment_ext_id, hse_user_ext_id 
			, sum(response_score)  resp_sum
			, sum(question_var) ssi2
			, count(*) k_a
			, max(max_aqord) max_aqord
			, variance(sum(response_score)) over (partition by assessment_ext_id) sx2
			, (1 - sum(question_var) / (variance(sum(response_score)) over (partition by assessment_ext_id) + 0.001))/ (1 - 1/(count(*)+0.001)) reliab
		--into user_range_a
		from struc
		join first_attempt using(item_id, assessment_ext_id, question_ext_id)
		group by course_id, bid, m_ord, mid, l_ord, lid, i_ord, iid, item_id, assessment_ext_id, hse_user_ext_id --, time_dlt
		order by course_id, bid, m_ord, mid, l_ord, lid, i_ord, iid, item_id, assessment_ext_id
				   , rank() OVER (PARTITION BY item_id ORDER BY sum(response_score), hse_user_ext_id );
				   
	   select cast(clock_timestamp() as text) into time_point;
	   time_steps = time_steps || '*user_range_a:  ' || time_point;
	 RAISE NOTICE 'user_range_a %', clock_timestamp();
				   
	   CREATE TABLE user_range_q_o AS
		select  
				user_range_q.course_id
				, bid
				, m_ord, m_name
				, l_ord, l_name
				, i_ord, iid, i_name
				, iid subiid, i_ord subi_ord, i_name subi_name
				, k_q, max_aqord + 1 max_aqord1, aq_ord --, response_score
				, question_ext_id, q_option.ext_id q_o_ext_id --, question.type_id q_type_id на будущее для других дистракторов
				, q_option.index q_o_index, q_option.correct q_o_correct, display
				, hse_user_ext_id
				, cd 
				, selected
		from user_range_q
			join coursera_structure.question on question.ext_id=user_range_q.question_ext_id 
												and question.load_id=app0_ins.load_id --84 --
			join coursera_structure.q_option on q_option.question_id=question.id -- пока только чекбоксы и радиокнопки
			left join coursera_event.cqo_event qoe on user_range_q.course_id=qoe.course_id 
											and user_range_q.response_ext_id=qoe.response_ext_id 
											and qoe.option_ext_id =q_option.ext_id;
			
			select cast(clock_timestamp() as text) into time_point;
			time_steps = time_steps || '*user_range_q_o:' || time_point;
		RAISE NOTICE 'user_range_q_o %', clock_timestamp();
	
  end if;  -- if (xstr_cnt * xheat_cnt * xaud_cnt = 0)
  
  drop table if exists quit1;
  -- *********************************************************************************************
  if (xstr_cnt = 0) then
  drop table if exists ifstr;
 
  	insert into data_mart.str_(
	    platform_id, course_id, cname, bid, mid, m_ord, m_name, lid, l_ord, l_name, iid, i_ord, i_name
	    , subiid, subi_ord, subi_name, assessment_ext_id, cnt, cnt_user, max_aqord1, k_min, k_max
		, mn_reliab, mx_reliab, ssi2, sx2
	)
  		select                                 
		  1 platform_id
		  , course_id, cname
		  , bid
		  , mid, m_ord, m_name
		  , lid, l_ord, l_name
		  , iid, i_ord, i_name
		  , iid subiid, i_ord subi_ord, i_name subi_name
		  , assessment_ext_id
		  , count(*) cnt
		  , count(distinct hse_user_ext_id) cnt_user
		  , max(max_aqord)+1 max_aqord1
		  , min(k_a) k_min
		  , max(k_a) k_max
		  , min(reliab) mn_reliab
		  , max(reliab) mx_reliab
		  , avg(ssi2) ssi2
		  , avg(sx2)  sx2
		from user_range_a
		group by course_id, cname
			  , bid
			  , mid, m_ord, m_name
			  , lid, l_ord, l_name
			  , iid, i_ord, i_name
			  , assessment_ext_id
		order by course_id, cname
			  , bid
			  , m_ord
			  , l_ord
			  , i_ord
			  , assessment_ext_id; 
			  
	drop table if exists ifstr1;
	select cast(clock_timestamp() as text) into time_point;
	time_steps = time_steps || '*str_:' || time_point;
	
	select ' | str: ' || cast(count(*) as text) from data_mart.str_ where course_id = xcourse_id into xstr;
	
  end if; --if (xstr_cnt = 0)
  
  
  drop table if exists quit2;
  -- *********************************************************************************************
  if (xheat_cnt = 0) then
  drop table if exists ifheat;
  
  	insert into data_mart.heat
      	(select                                  -- свертываем  hse_user_ext_id у user_range_q
			  1 platform_id
			  , course_id, cname
			  , bid, max(strt) strt, max(fin) fin
			  , mid, m_ord, m_name
			  , lid, l_ord, l_name
			  , iid, i_ord, i_name 
			  , iid subiid, i_ord subi_ord, i_name subi_name
			  , aq_ord
			  , assessment_ext_id
			  , question_ext_id
			  , min(q_update_ts) q_update_ts
			  , max(prompt) prompt
			  , min(k_q) k_min
			  , max(k_q) k_max
			  , max(max_aqord)+1 max_aqord1
			  , count(*) cnt
			  , sum(response_score) tot_num
			  , count(distinct hse_user_ext_id) tot_denom 
			  --, sum(response_score) / count(*) p
			  , sum(case when cd > 0.75 then response_score else 0 end) stong_num, sum(case when cd > 0.75 then 1 else 0 end) strong_denom
			  , sum(case when cd < 0.25 then response_score else 0 end) weak_num, sum(case when cd < 0.25 then 1 else 0 end) weak_denom
		--into heat
		from user_range_q
		--where k_q = max_aqord + 1
		group by course_id, cname
			  , bid
			  , mid, m_ord, m_name
			  , lid, l_ord, l_name
			  , iid, i_ord, i_name 
			  , aq_ord
			  , assessment_ext_id
			  , question_ext_id
		order by course_id, cname
			  , bid
			  , m_ord
			  , l_ord
			  , i_ord
			  , aq_ord
			  , assessment_ext_id
			  , question_ext_id);
			  
		select cast(clock_timestamp() as text) into time_point;
		time_steps = time_steps || '*heat:' || time_point;
			  
		select ' | heat: ' || cast(count(*) as text) from data_mart.heat where course_id = xcourse_id into xheat;
		
  end if; --if (xheat_cnt = 0)
  
   drop table if exists quit3;
  
  -- ********************************************************************************************
  if (xaud_cnt = 0) then
  drop table if exists ifaud;
  
  	insert into data_mart.aud
  		(select  
			    1 platform_id
			    , xcourse_id
				, bid
				, m_ord, m_name
		 		, l_ord, l_name
				, i_ord, iid, i_name
				, iid subiid, i_ord subi_ord, i_name subi_name
				, k_q, max_aqord1, aq_ord --, response_score
				, question_ext_id, q_o_ext_id
		 		, q_o_index, q_o_correct, max(display) display
				, count(*) cnt
				, count(distinct hse_user_ext_id) user_cnt
				, sum(case when cd<0.25 and selected then 1 else 0 end) weak_num
				, sum(case when cd<0.25 then 1 else 0 end) weak_denom
				, sum(case when cd>0.75 and selected then 1 else 0 end) strong_num
				, sum(case when cd>0.75 then 1 else 0 end) strong_denom
		--into aud
		from user_range_q_o 
			--join coursera_structure.question on question.ext_id=user_range_q.question_ext_id and question.load_id=app0_ins.load_id 
			--left join coursera_structure.q_option on q_option.question_id=question.id 
			--left join coursera_event.cqo_event qoe on user_range_q.response_ext_id=qoe.response_ext_id 
									   --and substring(qoe.option_ext_id from 1 for 10)=substring(q_option.ext_id from 1 for 10)
									   --and qoe.course_id=xcourse_id
		group by course_id, bid, question_ext_id, q_o_ext_id, q_o_index, q_o_correct
				, m_ord, m_name, l_ord, l_name, i_ord, iid, i_name, k_q, max_aqord1, aq_ord --, response_score
		order by bid, m_ord, l_ord, i_ord, aq_ord, q_o_index); 
		
		select cast(clock_timestamp() as text) into time_point;
		time_steps = time_steps || '*aud: ' || time_point;
		
		select ' | aud: ' || cast(count(*) as text) from data_mart.aud where course_id = xcourse_id into xaud;
		
  end if;
  drop table if exists quit_end;
  select cast(clock_timestamp() as text) into time_point;
  time_steps = time_steps || '*fin: ' || time_point;
  
  --SET enable_seqscan TO on;
  return  xstr || xheat || xaud || time_steps;
  
EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS text_var1 = MESSAGE_TEXT,
                          text_var2 = PG_EXCEPTION_DETAIL,
                          text_var3 = PG_EXCEPTION_HINT;
	return  'app0_ins Error ' || text_var1 || ' | ' || text_var2 ||  ' | ' || text_var3;					  

END;$BODY$;

ALTER FUNCTION data_mart.app0_ins(integer)
    OWNER TO postgres;
