--
-- PostgreSQL database dump
--

-- Dumped from database version 12.1
-- Dumped by pg_dump version 12.1

-- Started on 2020-04-16 16:22:42

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 3337 (class 1262 OID 16393)
-- Name: test; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE test WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'Russian_Russia.1251' LC_CTYPE = 'Russian_Russia.1251';


ALTER DATABASE test OWNER TO postgres;

\connect test

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 22 (class 2615 OID 100084)
-- Name: coursera_event; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA coursera_event;


ALTER SCHEMA coursera_event OWNER TO postgres;

--
-- TOC entry 11 (class 2615 OID 90296)
-- Name: coursera_structure; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA coursera_structure;


ALTER SCHEMA coursera_structure OWNER TO postgres;

--
-- TOC entry 3338 (class 0 OID 0)
-- Dependencies: 11
-- Name: SCHEMA coursera_structure; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA coursera_structure IS 'Структура контента курсеры';


--
-- TOC entry 23 (class 2615 OID 100085)
-- Name: data_mart; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA data_mart;


ALTER SCHEMA data_mart OWNER TO postgres;

--
-- TOC entry 10 (class 2615 OID 16442)
-- Name: openedu_structure; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA openedu_structure;


ALTER SCHEMA openedu_structure OWNER TO postgres;

--
-- TOC entry 3339 (class 0 OID 0)
-- Dependencies: 10
-- Name: SCHEMA openedu_structure; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA openedu_structure IS 'Структура контента OpenEDU';


--
-- TOC entry 1 (class 3079 OID 90753)
-- Name: plpython3u; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpython3u WITH SCHEMA pg_catalog;


--
-- TOC entry 3340 (class 0 OID 0)
-- Dependencies: 1
-- Name: EXTENSION plpython3u; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpython3u IS 'PL/Python3U untrusted procedural language';


--
-- TOC entry 3 (class 3079 OID 98852)
-- Name: dblink; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;


--
-- TOC entry 3341 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION dblink; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';


--
-- TOC entry 375 (class 1255 OID 100776)
-- Name: app0_ins(integer); Type: FUNCTION; Schema: data_mart; Owner: postgres
--

CREATE FUNCTION data_mart.app0_ins(load_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$DECLARE
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

END;$$;


ALTER FUNCTION data_mart.app0_ins(load_id integer) OWNER TO postgres;

--
-- TOC entry 372 (class 1255 OID 100638)
-- Name: test_f(); Type: FUNCTION; Schema: data_mart; Owner: postgres
--

CREATE FUNCTION data_mart.test_f() RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
x int;
y int;
n int;
BEGIN
  x = 84;
  select id from coursera_structure.course c 
     where c.load_id =x into y;-- надо со временем 
	 				-- добавить join от course (мало ли что с guid'ом)
	 
  if not (y is null) then
    select count(*) from coursera_event.caq_event caq
	where caq.course_id = y into n;
  end if;
  
  return n;

END;$$;


ALTER FUNCTION data_mart.test_f() OWNER TO postgres;

--
-- TOC entry 373 (class 1255 OID 100641)
-- Name: test_f1(integer); Type: FUNCTION; Schema: data_mart; Owner: postgres
--

CREATE FUNCTION data_mart.test_f1(load_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
x int;
y int;
n int;
BEGIN
  x = 84;
  select id from coursera_structure.course c 
     where c.load_id =test_f1.load_id into y;-- надо со временем 
	 				-- добавить join от course (мало ли что с guid'ом)
	 
  if not (y is null) then
    select count(*) from coursera_event.caq_event caq
	where caq.course_id = y into n;
  end if;
  
  return n;

END;$$;


ALTER FUNCTION data_mart.test_f1(load_id integer) OWNER TO postgres;

--
-- TOC entry 374 (class 1255 OID 100642)
-- Name: test_f2(integer); Type: FUNCTION; Schema: data_mart; Owner: postgres
--

CREATE FUNCTION data_mart.test_f2(load_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
x int;
y int;
n int;
BEGIN
  select count(*) from coursera_structure.course c 
     where c.load_id =test_f2.load_id into y;
 
  return y;

END;$$;


ALTER FUNCTION data_mart.test_f2(load_id integer) OWNER TO postgres;

--
-- TOC entry 331 (class 1255 OID 16498)
-- Name: add_chapter(integer, character varying, character varying); Type: FUNCTION; Schema: openedu_structure; Owner: postgres
--

CREATE FUNCTION openedu_structure.add_chapter(course_id integer, ext_id character varying, name character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
x int;
BEGIN

  select id from openedu_structure.chapter 
     where chapter.ext_id=add_chapter.ext_id into x;-- надо со временем 
	 				-- добавить join от course (мало ли что с guid'ом)
	 
  if (x is null) then
    INSERT INTO  openedu_structure.chapter (course_id, ext_id, name)
		 VALUES (add_chapter.course_id, add_chapter.ext_id, add_chapter.name)
		 RETURNING id INTO x; 
  end if;
  
  return x;

END;
$$;


ALTER FUNCTION openedu_structure.add_chapter(course_id integer, ext_id character varying, name character varying) OWNER TO postgres;

--
-- TOC entry 3342 (class 0 OID 0)
-- Dependencies: 331
-- Name: FUNCTION add_chapter(course_id integer, ext_id character varying, name character varying); Type: COMMENT; Schema: openedu_structure; Owner: postgres
--

COMMENT ON FUNCTION openedu_structure.add_chapter(course_id integer, ext_id character varying, name character varying) IS 'Добавляет новую запись в таблицу openedu_structure, с внешним ключом course_id';


--
-- TOC entry 335 (class 1255 OID 16507)
-- Name: add_item(integer, character varying, character varying, character varying); Type: FUNCTION; Schema: openedu_structure; Owner: postgres
--

CREATE FUNCTION openedu_structure.add_item(vertical_id integer, ext_id character varying, item_type character varying, name character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
x int;
BEGIN

  select id from openedu_structure.item 
     where item.ext_id=add_item.ext_id into x; -- надо со временем 
	 				-- добавить join от course (мало ли что с guid'ом)
	 
  if (x is null) then
    INSERT INTO  openedu_structure.item (vertical_id, ext_id, item_type, name)
		 VALUES (add_item.vertical_id, add_item.ext_id, add_item.item_type, add_item.name)
		 RETURNING id INTO x; 
  end if;
  
  return x;

END;$$;


ALTER FUNCTION openedu_structure.add_item(vertical_id integer, ext_id character varying, item_type character varying, name character varying) OWNER TO postgres;

--
-- TOC entry 334 (class 1255 OID 16505)
-- Name: add_sequential(integer, character varying, character varying); Type: FUNCTION; Schema: openedu_structure; Owner: postgres
--

CREATE FUNCTION openedu_structure.add_sequential(chapter_id integer, ext_id character varying, name character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
x int;
BEGIN

  select id from openedu_structure.sequential 
     where sequential.ext_id=add_sequential.ext_id into x; -- надо со временем 
	 				-- добавить join от course (мало ли что с guid'ом)

  if (x is null) then
    INSERT INTO  openedu_structure.sequential (chapter_id, ext_id, name)
		 VALUES (add_sequential.chapter_id, add_sequential.ext_id, add_sequential.name)
		 RETURNING id INTO x; 
  end if;
  
  return x;

END;$$;


ALTER FUNCTION openedu_structure.add_sequential(chapter_id integer, ext_id character varying, name character varying) OWNER TO postgres;

--
-- TOC entry 333 (class 1255 OID 16506)
-- Name: add_vertical(integer, character varying, character varying); Type: FUNCTION; Schema: openedu_structure; Owner: postgres
--

CREATE FUNCTION openedu_structure.add_vertical(sequential_id integer, ext_id character varying, name character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
x int;
BEGIN

  select id from openedu_structure.vertical 
     where vertical.ext_id=add_vertical.ext_id into x; -- надо со временем 
	 				-- добавить join от course (мало ли что с guid'ом)
	 
  if (x is null) then
    INSERT INTO  openedu_structure.vertical (sequential_id, ext_id, name)
		 VALUES (add_vertical.sequential_id, add_vertical.ext_id, add_vertical.name)
		 RETURNING id INTO x; 
  end if;
  
  return x;

END;$$;


ALTER FUNCTION openedu_structure.add_vertical(sequential_id integer, ext_id character varying, name character varying) OWNER TO postgres;

--
-- TOC entry 313 (class 1255 OID 16488)
-- Name: find_course(character varying); Type: FUNCTION; Schema: openedu_structure; Owner: postgres
--

CREATE FUNCTION openedu_structure.find_course(ext_id character varying DEFAULT 0) RETURNS integer
    LANGUAGE sql STABLE
    AS $$select id from openedu_structure.course where course.ext_id=find_course.ext_id$$;


ALTER FUNCTION openedu_structure.find_course(ext_id character varying) OWNER TO postgres;

--
-- TOC entry 3343 (class 0 OID 0)
-- Dependencies: 313
-- Name: FUNCTION find_course(ext_id character varying); Type: COMMENT; Schema: openedu_structure; Owner: postgres
--

COMMENT ON FUNCTION openedu_structure.find_course(ext_id character varying) IS 'Поиск id курса по ext_id';


--
-- TOC entry 332 (class 1255 OID 16504)
-- Name: test(character varying); Type: FUNCTION; Schema: openedu_structure; Owner: postgres
--

CREATE FUNCTION openedu_structure.test(ext_id character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$declare
x int;

begin

  select id from openedu_structure.chapter 
     where chapter.ext_id=test.ext_id into x;
	 
  if (x is null) then
    return -1; 
  else
    return x;
  end if;

end;$$;


ALTER FUNCTION openedu_structure.test(ext_id character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 263 (class 1259 OID 98987)
-- Name: caq_event; Type: TABLE; Schema: coursera_event; Owner: postgres
--

CREATE TABLE coursera_event.caq_event (
    course_id integer,
    hse_user_ext_id character varying(50),
    assessment_ext_id character varying(50),
    action_ext_id character varying(50),
    actionbase_ext_id character varying(50),
    action_version integer,
    action_ts timestamp without time zone,
    action_start_ts timestamp(6) without time zone,
    question_ext_id character varying(50),
    response_score real,
    weight_resp_score real,
    response_ext_id character varying(50)
);


ALTER TABLE coursera_event.caq_event OWNER TO postgres;

--
-- TOC entry 3344 (class 0 OID 0)
-- Dependencies: 263
-- Name: TABLE caq_event; Type: COMMENT; Schema: coursera_event; Owner: postgres
--

COMMENT ON TABLE coursera_event.caq_event IS 'Событие ответа пользователя на вопрос assessment''а';


--
-- TOC entry 264 (class 1259 OID 99073)
-- Name: cqo_event; Type: TABLE; Schema: coursera_event; Owner: postgres
--

CREATE TABLE coursera_event.cqo_event (
    response_ext_id character varying(50),
    option_ext_id character varying(50),
    correct boolean,
    selected boolean,
    course_id integer
);


ALTER TABLE coursera_event.cqo_event OWNER TO postgres;

--
-- TOC entry 3345 (class 0 OID 0)
-- Dependencies: 264
-- Name: TABLE cqo_event; Type: COMMENT; Schema: coursera_event; Owner: postgres
--

COMMENT ON TABLE coursera_event.cqo_event IS 'Событие выбора / не_выбора пользователем опции вопроса assessment''а';


--
-- TOC entry 265 (class 1259 OID 99144)
-- Name: csess_event; Type: TABLE; Schema: coursera_event; Owner: postgres
--

CREATE TABLE coursera_event.csess_event (
    course_ext_id character varying(50),
    on_demand_session_id character varying(50),
    on_demand_sessions_start_ts timestamp without time zone,
    on_demand_sessions_end_ts timestamp without time zone,
    on_demand_sessions_enrollment_end_ts timestamp without time zone,
    branch_ext_id character varying(50),
    course_id integer
);


ALTER TABLE coursera_event.csess_event OWNER TO postgres;

--
-- TOC entry 276 (class 1259 OID 100163)
-- Name: event_id_seq; Type: SEQUENCE; Schema: coursera_event; Owner: postgres
--

CREATE SEQUENCE coursera_event.event_id_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_event.event_id_seq OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 100165)
-- Name: event; Type: TABLE; Schema: coursera_event; Owner: postgres
--

CREATE TABLE coursera_event.event (
    id integer DEFAULT nextval('coursera_event.event_id_seq'::regclass) NOT NULL,
    dest_name text NOT NULL,
    load_ts timestamp without time zone,
    load_id integer
);


ALTER TABLE coursera_event.event OWNER TO postgres;

--
-- TOC entry 275 (class 1259 OID 100148)
-- Name: sessmemb_event; Type: TABLE; Schema: coursera_event; Owner: postgres
--

CREATE TABLE coursera_event.sessmemb_event (
    course_ext_id character varying(50),
    on_demand_session_id character varying(50),
    hse_user_ext_id character varying(50) NOT NULL,
    on_demand_sessions_membership_start_ts timestamp without time zone,
    on_demand_sessions_membership_end_ts timestamp without time zone,
    course_id integer
);


ALTER TABLE coursera_event.sessmemb_event OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 90451)
-- Name: assessment; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.assessment (
    id integer NOT NULL,
    ext_id character varying(50) NOT NULL,
    type_id integer NOT NULL,
    update_ts timestamp without time zone,
    passing_fract double precision,
    load_id integer
);


ALTER TABLE coursera_structure.assessment OWNER TO postgres;

--
-- TOC entry 3346 (class 0 OID 0)
-- Dependencies: 260
-- Name: TABLE assessment; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.assessment IS 'Шапка теста';


--
-- TOC entry 259 (class 1259 OID 90449)
-- Name: assessment_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.assessment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.assessment_id_seq OWNER TO postgres;

--
-- TOC entry 3347 (class 0 OID 0)
-- Dependencies: 259
-- Name: assessment_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.assessment_id_seq OWNED BY coursera_structure.assessment.id;


--
-- TOC entry 256 (class 1259 OID 90429)
-- Name: assessment_question; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.assessment_question (
    assessment_id integer NOT NULL,
    question_id integer NOT NULL,
    internal_id character varying(50),
    cuepoint integer,
    ord integer,
    weight integer
);


ALTER TABLE coursera_structure.assessment_question OWNER TO postgres;

--
-- TOC entry 3348 (class 0 OID 0)
-- Dependencies: 256
-- Name: TABLE assessment_question; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.assessment_question IS 'Привязка вопросов к assessment''у. Internal_id объединяет один и тот же вопрос из разных branches';


--
-- TOC entry 251 (class 1259 OID 90398)
-- Name: assessment_type; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.assessment_type (
    id integer NOT NULL,
    descr character varying(50) NOT NULL
);


ALTER TABLE coursera_structure.assessment_type OWNER TO postgres;

--
-- TOC entry 3349 (class 0 OID 0)
-- Dependencies: 251
-- Name: TABLE assessment_type; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.assessment_type IS 'Типы тестов';


--
-- TOC entry 250 (class 1259 OID 90396)
-- Name: assessment_type_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.assessment_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.assessment_type_id_seq OWNER TO postgres;

--
-- TOC entry 3350 (class 0 OID 0)
-- Dependencies: 250
-- Name: assessment_type_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.assessment_type_id_seq OWNED BY coursera_structure.assessment_type.id;


--
-- TOC entry 240 (class 1259 OID 90345)
-- Name: branch; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.branch (
    id integer NOT NULL,
    course_id integer NOT NULL,
    created_ts timestamp without time zone,
    ext_id character varying(50),
    load_id integer,
    start_sess_ts timestamp without time zone,
    end_sess_ts timestamp without time zone,
    name character varying(255)
);


ALTER TABLE coursera_structure.branch OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 90299)
-- Name: course; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.course (
    id integer NOT NULL,
    ext_id character varying(50),
    slug character varying(150) NOT NULL,
    name text NOT NULL,
    descr text,
    load_id integer
);


ALTER TABLE coursera_structure.course OWNER TO postgres;

--
-- TOC entry 3351 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE course; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.course IS 'Курсы от Coursera';


--
-- TOC entry 239 (class 1259 OID 90343)
-- Name: course_branch_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.course_branch_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.course_branch_id_seq OWNER TO postgres;

--
-- TOC entry 3352 (class 0 OID 0)
-- Dependencies: 239
-- Name: course_branch_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.course_branch_id_seq OWNED BY coursera_structure.branch.id;


--
-- TOC entry 237 (class 1259 OID 90297)
-- Name: course_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.course_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.course_id_seq OWNER TO postgres;

--
-- TOC entry 3353 (class 0 OID 0)
-- Dependencies: 237
-- Name: course_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.course_id_seq OWNED BY coursera_structure.course.id;


--
-- TOC entry 246 (class 1259 OID 90375)
-- Name: item; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.item (
    id integer NOT NULL,
    lesson_id integer NOT NULL,
    ord integer,
    type_id integer,
    name character varying(255),
    optional boolean,
    ext_id character varying(50),
    load_id integer,
    branch_ext_id character varying(50),
    graded boolean
);


ALTER TABLE coursera_structure.item OWNER TO postgres;

--
-- TOC entry 3354 (class 0 OID 0)
-- Dependencies: 246
-- Name: TABLE item; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.item IS 'Основной элемент контента. Item внутри курса уникален и может использоваться для идентификации прогресса независимо от branch.';


--
-- TOC entry 249 (class 1259 OID 90392)
-- Name: item_assessment; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.item_assessment (
    item_id integer,
    assessment_id integer NOT NULL
);


ALTER TABLE coursera_structure.item_assessment OWNER TO postgres;

--
-- TOC entry 3355 (class 0 OID 0)
-- Dependencies: 249
-- Name: TABLE item_assessment; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.item_assessment IS 'Линк между item и assessment. Item внутри курса уникален и может использоваться для идентификации прогресса независимо от branch.';


--
-- TOC entry 245 (class 1259 OID 90373)
-- Name: item_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.item_id_seq OWNER TO postgres;

--
-- TOC entry 3356 (class 0 OID 0)
-- Dependencies: 245
-- Name: item_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.item_id_seq OWNED BY coursera_structure.item.id;


--
-- TOC entry 261 (class 1259 OID 90541)
-- Name: item_type; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.item_type (
    id integer NOT NULL,
    descr character varying(255),
    categ character varying(255),
    graded boolean
);


ALTER TABLE coursera_structure.item_type OWNER TO postgres;

--
-- TOC entry 3357 (class 0 OID 0)
-- Dependencies: 261
-- Name: TABLE item_type; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.item_type IS 'Типы базовых элементов курса';


--
-- TOC entry 244 (class 1259 OID 90364)
-- Name: lesson; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.lesson (
    id integer NOT NULL,
    module_id integer NOT NULL,
    ord integer,
    name text,
    ext_id character varying(50),
    load_id integer,
    branch_ext_id character varying(50)
);


ALTER TABLE coursera_structure.lesson OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 90362)
-- Name: lesson_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.lesson_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.lesson_id_seq OWNER TO postgres;

--
-- TOC entry 3358 (class 0 OID 0)
-- Dependencies: 243
-- Name: lesson_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.lesson_id_seq OWNED BY coursera_structure.lesson.id;


--
-- TOC entry 248 (class 1259 OID 90383)
-- Name: load; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.load (
    id integer NOT NULL,
    name text NOT NULL,
    load_ts timestamp without time zone
);


ALTER TABLE coursera_structure.load OWNER TO postgres;

--
-- TOC entry 3359 (class 0 OID 0)
-- Dependencies: 248
-- Name: TABLE load; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.load IS 'Наименование загрузки из файлового хранилища';


--
-- TOC entry 247 (class 1259 OID 90381)
-- Name: load_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.load_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.load_id_seq OWNER TO postgres;

--
-- TOC entry 3360 (class 0 OID 0)
-- Dependencies: 247
-- Name: load_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.load_id_seq OWNED BY coursera_structure.load.id;


--
-- TOC entry 242 (class 1259 OID 90353)
-- Name: module; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.module (
    id integer NOT NULL,
    branch_id integer NOT NULL,
    ord integer,
    descr text,
    ext_id character varying(50),
    load_id integer,
    branch_ext_id character varying(50),
    name text
);


ALTER TABLE coursera_structure.module OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 90351)
-- Name: module_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.module_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.module_id_seq OWNER TO postgres;

--
-- TOC entry 3361 (class 0 OID 0)
-- Dependencies: 241
-- Name: module_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.module_id_seq OWNED BY coursera_structure.module.id;


--
-- TOC entry 258 (class 1259 OID 90437)
-- Name: q_option; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.q_option (
    id integer NOT NULL,
    question_id integer NOT NULL,
    ext_id character varying(50),
    display text,
    feedback text,
    correct boolean,
    index integer,
    load_id integer
);


ALTER TABLE coursera_structure.q_option OWNER TO postgres;

--
-- TOC entry 3362 (class 0 OID 0)
-- Dependencies: 258
-- Name: TABLE q_option; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.q_option IS 'Опции ответов для вопроса assessment''а';


--
-- TOC entry 257 (class 1259 OID 90435)
-- Name: q_options_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.q_options_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.q_options_id_seq OWNER TO postgres;

--
-- TOC entry 3363 (class 0 OID 0)
-- Dependencies: 257
-- Name: q_options_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.q_options_id_seq OWNED BY coursera_structure.q_option.id;


--
-- TOC entry 253 (class 1259 OID 90410)
-- Name: question; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.question (
    id integer NOT NULL,
    ext_id character varying(50) NOT NULL,
    type_id integer NOT NULL,
    prompt text,
    update_ts timestamp without time zone,
    load_id integer
);


ALTER TABLE coursera_structure.question OWNER TO postgres;

--
-- TOC entry 3364 (class 0 OID 0)
-- Dependencies: 253
-- Name: TABLE question; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.question IS 'Один вопрос assessment''а';


--
-- TOC entry 252 (class 1259 OID 90408)
-- Name: question_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.question_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.question_id_seq OWNER TO postgres;

--
-- TOC entry 3365 (class 0 OID 0)
-- Dependencies: 252
-- Name: question_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.question_id_seq OWNED BY coursera_structure.question.id;


--
-- TOC entry 255 (class 1259 OID 90419)
-- Name: question_type; Type: TABLE; Schema: coursera_structure; Owner: postgres
--

CREATE TABLE coursera_structure.question_type (
    id integer NOT NULL,
    descr character varying(50) NOT NULL
);


ALTER TABLE coursera_structure.question_type OWNER TO postgres;

--
-- TOC entry 3366 (class 0 OID 0)
-- Dependencies: 255
-- Name: TABLE question_type; Type: COMMENT; Schema: coursera_structure; Owner: postgres
--

COMMENT ON TABLE coursera_structure.question_type IS 'Типы вопросов assessment''а';


--
-- TOC entry 254 (class 1259 OID 90417)
-- Name: question_type_id_seq; Type: SEQUENCE; Schema: coursera_structure; Owner: postgres
--

CREATE SEQUENCE coursera_structure.question_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coursera_structure.question_type_id_seq OWNER TO postgres;

--
-- TOC entry 3367 (class 0 OID 0)
-- Dependencies: 254
-- Name: question_type_id_seq; Type: SEQUENCE OWNED BY; Schema: coursera_structure; Owner: postgres
--

ALTER SEQUENCE coursera_structure.question_type_id_seq OWNED BY coursera_structure.question_type.id;


--
-- TOC entry 297 (class 1259 OID 101333)
-- Name: aud; Type: TABLE; Schema: data_mart; Owner: postgres
--

CREATE TABLE data_mart.aud (
    platform_id smallint,
    course_id integer,
    bid character varying(50),
    m_ord integer,
    m_name text,
    l_ord integer,
    l_name text,
    i_ord integer,
    iid character varying(50),
    i_name text,
    subiid character varying(50),
    subi_ord integer,
    subi_name text,
    k_q bigint,
    max_aqord integer,
    aq_ord integer,
    question_ext_id character varying(50),
    qo_ext_id character varying(50),
    qo_index integer,
    correct boolean,
    display text,
    cnt bigint,
    user_cnt bigint,
    weak_num bigint,
    weak_denom bigint,
    strong_num bigint,
    strong_denom bigint
);


ALTER TABLE data_mart.aud OWNER TO postgres;

--
-- TOC entry 296 (class 1259 OID 100821)
-- Name: heat; Type: TABLE; Schema: data_mart; Owner: postgres
--

CREATE TABLE data_mart.heat (
    platform_id smallint,
    course_id integer,
    cname text,
    bid character varying(50),
    strt timestamp without time zone,
    fin timestamp without time zone,
    mid character varying(50),
    m_ord integer,
    m_name text,
    lid character varying(50),
    l_ord integer,
    l_name text,
    iid character varying(50),
    i_ord integer,
    i_name text,
    subiid character varying(50),
    subi_ord integer,
    subi_name text,
    aq_ord integer,
    assessment_ext_id character varying(50),
    question_ext_id character varying(50),
    q_update_ts timestamp without time zone,
    prompt text,
    k_min bigint,
    k_max bigint,
    max_aqord1 integer,
    cnt bigint,
    tot_num real,
    tot_denom bigint,
    stong_num real,
    strong_denom bigint,
    weak_num real,
    weak_denom bigint
);


ALTER TABLE data_mart.heat OWNER TO postgres;

--
-- TOC entry 295 (class 1259 OID 100653)
-- Name: str_; Type: TABLE; Schema: data_mart; Owner: postgres
--

CREATE TABLE data_mart.str_ (
    platform_id smallint,
    course_id integer,
    cname text,
    bid character varying(50),
    mid character varying(50),
    m_ord integer,
    m_name text,
    lid character varying(50),
    l_ord integer,
    l_name text,
    iid character varying(50),
    i_ord integer,
    i_name text,
    subiid character varying(50),
    subi_ord integer,
    subi_name text,
    assessment_ext_id character varying(50),
    cnt bigint,
    cnt_user bigint,
    max_aqord1 integer,
    k_min bigint,
    k_max bigint,
    mn_reliab double precision,
    mx_reliab double precision,
    ssi2 double precision,
    sx2 double precision
);


ALTER TABLE data_mart.str_ OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16453)
-- Name: chapter; Type: TABLE; Schema: openedu_structure; Owner: postgres
--

CREATE TABLE openedu_structure.chapter (
    id integer NOT NULL,
    course_id integer NOT NULL,
    ext_id character varying(50) NOT NULL,
    name text
);


ALTER TABLE openedu_structure.chapter OWNER TO postgres;

--
-- TOC entry 3368 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE chapter; Type: COMMENT; Schema: openedu_structure; Owner: postgres
--

COMMENT ON TABLE openedu_structure.chapter IS 'Тема или неделя';


--
-- TOC entry 229 (class 1259 OID 16451)
-- Name: chapter_id_seq; Type: SEQUENCE; Schema: openedu_structure; Owner: postgres
--

CREATE SEQUENCE openedu_structure.chapter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE openedu_structure.chapter_id_seq OWNER TO postgres;

--
-- TOC entry 3369 (class 0 OID 0)
-- Dependencies: 229
-- Name: chapter_id_seq; Type: SEQUENCE OWNED BY; Schema: openedu_structure; Owner: postgres
--

ALTER SEQUENCE openedu_structure.chapter_id_seq OWNED BY openedu_structure.chapter.id;


--
-- TOC entry 226 (class 1259 OID 16412)
-- Name: course; Type: TABLE; Schema: openedu_structure; Owner: postgres
--

CREATE TABLE openedu_structure.course (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    ext_id character varying(50) NOT NULL,
    description text
);


ALTER TABLE openedu_structure.course OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 16477)
-- Name: item; Type: TABLE; Schema: openedu_structure; Owner: postgres
--

CREATE TABLE openedu_structure.item (
    id integer NOT NULL,
    vertical_id integer NOT NULL,
    ext_id character varying(50) NOT NULL,
    item_type character varying(30) NOT NULL,
    name text NOT NULL,
    body jsonb
);


ALTER TABLE openedu_structure.item OWNER TO postgres;

--
-- TOC entry 3370 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE item; Type: COMMENT; Schema: openedu_structure; Owner: postgres
--

COMMENT ON TABLE openedu_structure.item IS 'Терминальный контент (discussion, problem, video ...)';


--
-- TOC entry 235 (class 1259 OID 16475)
-- Name: item_id_seq; Type: SEQUENCE; Schema: openedu_structure; Owner: postgres
--

CREATE SEQUENCE openedu_structure.item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE openedu_structure.item_id_seq OWNER TO postgres;

--
-- TOC entry 3371 (class 0 OID 0)
-- Dependencies: 235
-- Name: item_id_seq; Type: SEQUENCE OWNED BY; Schema: openedu_structure; Owner: postgres
--

ALTER SEQUENCE openedu_structure.item_id_seq OWNED BY openedu_structure.item.id;


--
-- TOC entry 225 (class 1259 OID 16410)
-- Name: open_edu_course_id_seq; Type: SEQUENCE; Schema: openedu_structure; Owner: postgres
--

CREATE SEQUENCE openedu_structure.open_edu_course_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE openedu_structure.open_edu_course_id_seq OWNER TO postgres;

--
-- TOC entry 3372 (class 0 OID 0)
-- Dependencies: 225
-- Name: open_edu_course_id_seq; Type: SEQUENCE OWNED BY; Schema: openedu_structure; Owner: postgres
--

ALTER SEQUENCE openedu_structure.open_edu_course_id_seq OWNED BY openedu_structure.course.id;


--
-- TOC entry 232 (class 1259 OID 16461)
-- Name: sequential; Type: TABLE; Schema: openedu_structure; Owner: postgres
--

CREATE TABLE openedu_structure.sequential (
    id integer NOT NULL,
    chapter_id integer NOT NULL,
    ext_id character varying(50) NOT NULL,
    name text NOT NULL
);


ALTER TABLE openedu_structure.sequential OWNER TO postgres;

--
-- TOC entry 3373 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE sequential; Type: COMMENT; Schema: openedu_structure; Owner: postgres
--

COMMENT ON TABLE openedu_structure.sequential IS 'Подуровень под темой';


--
-- TOC entry 231 (class 1259 OID 16459)
-- Name: sequential_id_seq; Type: SEQUENCE; Schema: openedu_structure; Owner: postgres
--

CREATE SEQUENCE openedu_structure.sequential_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE openedu_structure.sequential_id_seq OWNER TO postgres;

--
-- TOC entry 3374 (class 0 OID 0)
-- Dependencies: 231
-- Name: sequential_id_seq; Type: SEQUENCE OWNED BY; Schema: openedu_structure; Owner: postgres
--

ALTER SEQUENCE openedu_structure.sequential_id_seq OWNED BY openedu_structure.sequential.id;


--
-- TOC entry 234 (class 1259 OID 16469)
-- Name: vertical; Type: TABLE; Schema: openedu_structure; Owner: postgres
--

CREATE TABLE openedu_structure.vertical (
    id integer NOT NULL,
    sequential_id integer NOT NULL,
    ext_id character varying(50) NOT NULL,
    name text NOT NULL
);


ALTER TABLE openedu_structure.vertical OWNER TO postgres;

--
-- TOC entry 3375 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE vertical; Type: COMMENT; Schema: openedu_structure; Owner: postgres
--

COMMENT ON TABLE openedu_structure.vertical IS 'Блок в основном окне справа';


--
-- TOC entry 233 (class 1259 OID 16467)
-- Name: vertical_id_seq; Type: SEQUENCE; Schema: openedu_structure; Owner: postgres
--

CREATE SEQUENCE openedu_structure.vertical_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE openedu_structure.vertical_id_seq OWNER TO postgres;

--
-- TOC entry 3376 (class 0 OID 0)
-- Dependencies: 233
-- Name: vertical_id_seq; Type: SEQUENCE OWNED BY; Schema: openedu_structure; Owner: postgres
--

ALTER SEQUENCE openedu_structure.vertical_id_seq OWNED BY openedu_structure.vertical.id;


--
-- TOC entry 302 (class 1259 OID 122298)
-- Name: assessment_actions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assessment_actions (
    assessment_action_id character varying(50),
    assessment_action_base_id character varying(50),
    assessment_id character varying(50),
    assessment_scope_id character varying(300),
    assessment_scope_type_id integer,
    assessment_action_version integer,
    assessment_action_ts timestamp without time zone,
    assessment_action_start_ts timestamp without time zone,
    guest_user_id character varying(50),
    hse_user_id character varying(50) NOT NULL
);


ALTER TABLE public.assessment_actions OWNER TO postgres;

--
-- TOC entry 284 (class 1259 OID 100281)
-- Name: assessment_actions_bayes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assessment_actions_bayes (
    assessment_action_id character varying(50),
    assessment_action_base_id character varying(50),
    assessment_id character varying(50),
    assessment_scope_id character varying(300),
    assessment_scope_type_id integer,
    assessment_action_version integer,
    assessment_action_ts timestamp without time zone,
    assessment_action_start_ts timestamp without time zone,
    guest_user_id character varying(50),
    ucsd_user_id character varying(50) NOT NULL
);


ALTER TABLE public.assessment_actions_bayes OWNER TO postgres;

--
-- TOC entry 287 (class 1259 OID 100306)
-- Name: assessment_actions_ml; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assessment_actions_ml (
    assessment_action_id character varying(50),
    assessment_action_base_id character varying(50),
    assessment_id character varying(50),
    assessment_scope_id character varying(300),
    assessment_scope_type_id integer,
    assessment_action_version integer,
    assessment_action_ts timestamp without time zone,
    assessment_action_start_ts timestamp without time zone,
    guest_user_id character varying(50),
    ucsd_user_id character varying(50) NOT NULL
);


ALTER TABLE public.assessment_actions_ml OWNER TO postgres;

--
-- TOC entry 272 (class 1259 OID 100026)
-- Name: assessment_actions_ne; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assessment_actions_ne (
    assessment_action_id character varying(50),
    assessment_action_base_id character varying(50),
    assessment_id character varying(50),
    assessment_scope_id character varying(300),
    assessment_scope_type_id integer,
    assessment_action_version integer,
    assessment_action_ts timestamp without time zone,
    assessment_action_start_ts timestamp without time zone,
    guest_user_id character varying(50),
    ucsd_user_id character varying(50) NOT NULL
);


ALTER TABLE public.assessment_actions_ne OWNER TO postgres;

--
-- TOC entry 304 (class 1259 OID 122321)
-- Name: assessment_response_options; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assessment_response_options (
    assessment_response_id character varying(50),
    assessment_option_id character varying(50),
    assessment_response_correct boolean,
    assessment_response_feedback character varying(20000),
    assessment_response_selected boolean
);


ALTER TABLE public.assessment_response_options OWNER TO postgres;

--
-- TOC entry 303 (class 1259 OID 122306)
-- Name: assessment_responses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assessment_responses (
    assessment_response_id character varying(50),
    assessment_id character varying(50),
    assessment_action_id character varying(50),
    assessment_action_version integer,
    assessment_question_id character varying(50),
    assessment_response_score real,
    assessment_response_weighted_score real
);


ALTER TABLE public.assessment_responses OWNER TO postgres;

--
-- TOC entry 285 (class 1259 OID 100289)
-- Name: assessment_responses_bayes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assessment_responses_bayes (
    assessment_response_id character varying(50),
    assessment_id character varying(50),
    assessment_action_id character varying(50),
    assessment_action_version integer,
    assessment_question_id character varying(50),
    assessment_response_score real,
    assessment_response_weighted_score real
);


ALTER TABLE public.assessment_responses_bayes OWNER TO postgres;

--
-- TOC entry 288 (class 1259 OID 100312)
-- Name: assessment_responses_ml; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assessment_responses_ml (
    assessment_response_id character varying(50),
    assessment_id character varying(50),
    assessment_action_id character varying(50),
    assessment_action_version integer,
    assessment_question_id character varying(50),
    assessment_response_score real,
    assessment_response_weighted_score real
);


ALTER TABLE public.assessment_responses_ml OWNER TO postgres;

--
-- TOC entry 273 (class 1259 OID 100037)
-- Name: assessment_responses_ne; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assessment_responses_ne (
    assessment_response_id character varying(50),
    assessment_id character varying(50),
    assessment_action_id character varying(50),
    assessment_action_version integer,
    assessment_question_id character varying(50),
    assessment_response_score real,
    assessment_response_weighted_score real
);


ALTER TABLE public.assessment_responses_ne OWNER TO postgres;

--
-- TOC entry 294 (class 1259 OID 100643)
-- Name: aud_; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aud_ (
    bid character varying(50),
    m_ord integer,
    m_name text,
    l_ord integer,
    l_name text,
    i_ord integer,
    iid character varying(50),
    i_name character varying(255),
    k_q bigint,
    max_aqord integer,
    aq_ord integer,
    question_ext_id character varying(50),
    ext_id character varying(50),
    index integer,
    correct boolean,
    display text,
    cnt bigint,
    user_cnt bigint,
    weak_num bigint,
    weak_denom bigint,
    strong_num bigint,
    strong_denom bigint
);


ALTER TABLE public.aud_ OWNER TO postgres;

--
-- TOC entry 286 (class 1259 OID 100292)
-- Name: course_progress_bayes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_progress_bayes (
    course_id character varying(50),
    course_item_id character varying(50),
    hse_user_id character varying(50) NOT NULL,
    course_progress_state_type_id integer,
    course_progress_ts timestamp without time zone
);


ALTER TABLE public.course_progress_bayes OWNER TO postgres;

--
-- TOC entry 280 (class 1259 OID 100226)
-- Name: course_progress_discr_maths; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_progress_discr_maths (
    course_id character varying(50),
    course_item_id character varying(50),
    hse_user_id character varying(50) NOT NULL,
    course_progress_state_type_id integer,
    course_progress_ts timestamp without time zone
);


ALTER TABLE public.course_progress_discr_maths OWNER TO postgres;

--
-- TOC entry 289 (class 1259 OID 100315)
-- Name: course_progress_ml; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_progress_ml (
    course_id character varying(50),
    course_item_id character varying(50),
    hse_user_id character varying(50) NOT NULL,
    course_progress_state_type_id integer,
    course_progress_ts timestamp without time zone
);


ALTER TABLE public.course_progress_ml OWNER TO postgres;

--
-- TOC entry 274 (class 1259 OID 100040)
-- Name: course_progress_ne; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_progress_ne (
    course_id character varying(50),
    course_item_id character varying(50),
    hse_user_id character varying(50) NOT NULL,
    course_progress_state_type_id integer,
    course_progress_ts timestamp without time zone
);


ALTER TABLE public.course_progress_ne OWNER TO postgres;

--
-- TOC entry 283 (class 1259 OID 100237)
-- Name: course_progress_pyth_bas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_progress_pyth_bas (
    course_id character varying(50),
    course_item_id character varying(50),
    hse_user_id character varying(50) NOT NULL,
    course_progress_state_type_id integer,
    course_progress_ts timestamp without time zone
);


ALTER TABLE public.course_progress_pyth_bas OWNER TO postgres;

--
-- TOC entry 307 (class 1259 OID 122993)
-- Name: first1; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.first1 (
    course_id integer,
    hse_user_ext_id character varying(50),
    item_id integer,
    action_start_ts timestamp(6) without time zone,
    action_ts timestamp without time zone
);


ALTER TABLE public.first1 OWNER TO postgres;

--
-- TOC entry 308 (class 1259 OID 122996)
-- Name: first2; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.first2 (
    course_id integer,
    hse_user_ext_id character varying(50),
    item_id integer,
    action_start_ts timestamp without time zone,
    action_ts timestamp without time zone
);


ALTER TABLE public.first2 OWNER TO postgres;

--
-- TOC entry 309 (class 1259 OID 122999)
-- Name: first_attempt; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.first_attempt (
    item_id integer,
    assessment_ext_id character varying(50),
    question_ext_id character varying(50),
    response_score real,
    hse_user_ext_id character varying(50),
    resp_sum real,
    question_var double precision,
    response_ext_id character varying(50)
);


ALTER TABLE public.first_attempt OWNER TO postgres;

--
-- TOC entry 293 (class 1259 OID 100592)
-- Name: heat_; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.heat_ (
    course_id integer,
    cname text,
    bid character varying(50),
    strt timestamp without time zone,
    fin timestamp without time zone,
    mid character varying(50),
    m_ord integer,
    m_name text,
    lid character varying(50),
    l_ord integer,
    l_name text,
    iid character varying(50),
    i_ord integer,
    i_name character varying(255),
    aq_ord integer,
    assessment_ext_id character varying(50),
    question_ext_id character varying(50),
    prompt text,
    k_min bigint,
    k_max bigint,
    max_aqord1 integer,
    cnt bigint,
    tot_num real,
    tot_denom bigint,
    p double precision,
    stong_num real,
    strong_denom bigint,
    weak_num real,
    weak_denom bigint
);


ALTER TABLE public.heat_ OWNER TO postgres;

--
-- TOC entry 305 (class 1259 OID 122327)
-- Name: on_demand_session_memberships; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.on_demand_session_memberships (
    course_id character varying(50),
    on_demand_session_id character varying(50),
    hse_user_id character varying(50) NOT NULL,
    on_demand_sessions_membership_start_ts timestamp without time zone,
    on_demand_sessions_membership_end_ts timestamp without time zone
);


ALTER TABLE public.on_demand_session_memberships OWNER TO postgres;

--
-- TOC entry 278 (class 1259 OID 100220)
-- Name: on_demand_session_memberships_discr_maths; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.on_demand_session_memberships_discr_maths (
    course_id character varying(50),
    on_demand_session_id character varying(50),
    hse_user_id character varying(50) NOT NULL,
    on_demand_sessions_membership_start_ts timestamp without time zone,
    on_demand_sessions_membership_end_ts timestamp without time zone
);


ALTER TABLE public.on_demand_session_memberships_discr_maths OWNER TO postgres;

--
-- TOC entry 270 (class 1259 OID 100017)
-- Name: on_demand_session_memberships_ne; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.on_demand_session_memberships_ne (
    course_id character varying(50),
    on_demand_session_id character varying(50),
    hse_user_id character varying(50) NOT NULL,
    on_demand_sessions_membership_start_ts timestamp without time zone,
    on_demand_sessions_membership_end_ts timestamp without time zone
);


ALTER TABLE public.on_demand_session_memberships_ne OWNER TO postgres;

--
-- TOC entry 281 (class 1259 OID 100231)
-- Name: on_demand_session_memberships_pyth_bas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.on_demand_session_memberships_pyth_bas (
    course_id character varying(50),
    on_demand_session_id character varying(50),
    hse_user_id character varying(50) NOT NULL,
    on_demand_sessions_membership_start_ts timestamp without time zone,
    on_demand_sessions_membership_end_ts timestamp without time zone
);


ALTER TABLE public.on_demand_session_memberships_pyth_bas OWNER TO postgres;

--
-- TOC entry 301 (class 1259 OID 122295)
-- Name: on_demand_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.on_demand_sessions (
    course_id character varying(50),
    on_demand_session_id character varying(50),
    on_demand_sessions_start_ts timestamp without time zone,
    on_demand_sessions_end_ts timestamp without time zone,
    on_demand_sessions_enrollment_end_ts timestamp without time zone,
    course_branch_id character varying(50)
);


ALTER TABLE public.on_demand_sessions OWNER TO postgres;

--
-- TOC entry 279 (class 1259 OID 100223)
-- Name: on_demand_sessions_discr_maths; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.on_demand_sessions_discr_maths (
    course_id character varying(50),
    on_demand_session_id character varying(50),
    on_demand_sessions_start_ts timestamp without time zone,
    on_demand_sessions_end_ts timestamp without time zone,
    on_demand_sessions_enrollment_end_ts timestamp without time zone,
    course_branch_id character varying(50)
);


ALTER TABLE public.on_demand_sessions_discr_maths OWNER TO postgres;

--
-- TOC entry 271 (class 1259 OID 100020)
-- Name: on_demand_sessions_ne; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.on_demand_sessions_ne (
    course_id character varying(50),
    on_demand_session_id character varying(50),
    on_demand_sessions_start_ts timestamp without time zone,
    on_demand_sessions_end_ts timestamp without time zone,
    on_demand_sessions_enrollment_end_ts timestamp without time zone,
    course_branch_id character varying(50)
);


ALTER TABLE public.on_demand_sessions_ne OWNER TO postgres;

--
-- TOC entry 282 (class 1259 OID 100234)
-- Name: on_demand_sessions_pyth_bas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.on_demand_sessions_pyth_bas (
    course_id character varying(50),
    on_demand_session_id character varying(50),
    on_demand_sessions_start_ts timestamp without time zone,
    on_demand_sessions_end_ts timestamp without time zone,
    on_demand_sessions_enrollment_end_ts timestamp without time zone,
    course_branch_id character varying(50)
);


ALTER TABLE public.on_demand_sessions_pyth_bas OWNER TO postgres;

--
-- TOC entry 292 (class 1259 OID 100586)
-- Name: str_; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.str_ (
    course_id integer,
    cname text,
    bid character varying(50),
    mid character varying(50),
    m_ord integer,
    m_name text,
    lid character varying(50),
    l_ord integer,
    l_name text,
    iid character varying(50),
    i_ord integer,
    i_name text,
    assessment_ext_id character varying(50),
    cnt bigint,
    count bigint,
    max_aqord1 integer,
    k_min bigint,
    k_max bigint,
    mn_reliab double precision,
    mx_reliab double precision,
    ssi2 double precision,
    sx2 double precision
);


ALTER TABLE public.str_ OWNER TO postgres;

--
-- TOC entry 306 (class 1259 OID 122987)
-- Name: struc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.struc (
    course_id integer,
    cname text,
    bid character varying(50),
    mid character varying(50),
    m_ord integer,
    m_name text,
    lid character varying(50),
    l_ord integer,
    l_name text,
    iid character varying(50),
    i_ord integer,
    i_name character varying(255),
    type_id integer,
    descr text,
    graded integer,
    load_id integer,
    item_id integer,
    aq_ord integer,
    internal_id character varying(50),
    ass_id integer,
    assessment_ext_id character varying(50),
    qid integer,
    question_ext_id character varying(50),
    prompt text,
    q_update_ts timestamp without time zone,
    strt timestamp without time zone,
    fin timestamp without time zone,
    max_aqord integer
);


ALTER TABLE public.struc OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16394)
-- Name: test_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_table (
    name character varying(100),
    qty double precision NOT NULL,
    id1 integer NOT NULL,
    qty1 double precision,
    qty2 double precision
);


ALTER TABLE public.test_table OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16434)
-- Name: test_table_id1_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.test_table_id1_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.test_table_id1_seq OWNER TO postgres;

--
-- TOC entry 3377 (class 0 OID 0)
-- Dependencies: 228
-- Name: test_table_id1_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_table_id1_seq OWNED BY public.test_table.id1;


--
-- TOC entry 227 (class 1259 OID 16428)
-- Name: test_table_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.test_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.test_table_id_seq OWNER TO postgres;

--
-- TOC entry 3378 (class 0 OID 0)
-- Dependencies: 227
-- Name: test_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_table_id_seq OWNED BY public.test_table.qty;


--
-- TOC entry 298 (class 1259 OID 122274)
-- Name: tmp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tmp (
    index bigint,
    id bigint,
    descr text,
    categ text,
    graded text
);


ALTER TABLE public.tmp OWNER TO postgres;

--
-- TOC entry 299 (class 1259 OID 122281)
-- Name: tmp1; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tmp1 (
    index bigint,
    id bigint,
    descr text
);


ALTER TABLE public.tmp1 OWNER TO postgres;

--
-- TOC entry 300 (class 1259 OID 122288)
-- Name: tmp2; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tmp2 (
    index bigint,
    id bigint,
    descr text
);


ALTER TABLE public.tmp2 OWNER TO postgres;

--
-- TOC entry 311 (class 1259 OID 123008)
-- Name: user_range_a; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_range_a (
    course_id integer,
    cname text,
    bid character varying(50),
    mid character varying(50),
    m_ord integer,
    m_name text,
    lid character varying(50),
    l_ord integer,
    l_name text,
    iid character varying(50),
    i_ord integer,
    i_name text,
    item_id integer,
    assessment_ext_id character varying(50),
    hse_user_ext_id character varying(50),
    resp_sum real,
    ssi2 double precision,
    k_a bigint,
    max_aqord integer,
    sx2 double precision,
    reliab double precision
);


ALTER TABLE public.user_range_a OWNER TO postgres;

--
-- TOC entry 310 (class 1259 OID 123002)
-- Name: user_range_q; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_range_q (
    course_id integer,
    cname text,
    bid character varying(50),
    strt timestamp without time zone,
    fin timestamp without time zone,
    mid character varying(50),
    m_ord integer,
    m_name text,
    lid character varying(50),
    l_ord integer,
    l_name text,
    iid character varying(50),
    i_ord integer,
    i_name character varying(255),
    aq_ord integer,
    item_id integer,
    assessment_ext_id character varying(50),
    question_ext_id character varying(50),
    q_update_ts timestamp without time zone,
    qid integer,
    prompt text,
    hse_user_ext_id character varying(50),
    response_score real,
    response_ext_id character varying(50),
    k_q bigint,
    max_aqord integer,
    rnk bigint,
    cd double precision
);


ALTER TABLE public.user_range_q OWNER TO postgres;

--
-- TOC entry 312 (class 1259 OID 123014)
-- Name: user_range_q_o; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_range_q_o (
    course_id integer,
    bid character varying(50),
    m_ord integer,
    m_name text,
    l_ord integer,
    l_name text,
    i_ord integer,
    iid character varying(50),
    i_name character varying(255),
    subiid character varying(50),
    subi_ord integer,
    subi_name character varying(255),
    k_q bigint,
    max_aqord1 integer,
    aq_ord integer,
    question_ext_id character varying(50),
    q_o_ext_id character varying(50),
    q_o_index integer,
    q_o_correct boolean,
    display text,
    hse_user_ext_id character varying(50),
    cd double precision,
    selected boolean
);


ALTER TABLE public.user_range_q_o OWNER TO postgres;

--
-- TOC entry 290 (class 1259 OID 100559)
-- Name: xcourse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.xcourse (
    x integer
);


ALTER TABLE public.xcourse OWNER TO postgres;

--
-- TOC entry 291 (class 1259 OID 100562)
-- Name: xload; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.xload (
    x integer
);


ALTER TABLE public.xload OWNER TO postgres;

--
-- TOC entry 3119 (class 2604 OID 90454)
-- Name: assessment id; Type: DEFAULT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.assessment ALTER COLUMN id SET DEFAULT nextval('coursera_structure.assessment_id_seq'::regclass);


--
-- TOC entry 3116 (class 2604 OID 90401)
-- Name: assessment_type id; Type: DEFAULT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.assessment_type ALTER COLUMN id SET DEFAULT nextval('coursera_structure.assessment_type_id_seq'::regclass);


--
-- TOC entry 3111 (class 2604 OID 90348)
-- Name: branch id; Type: DEFAULT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.branch ALTER COLUMN id SET DEFAULT nextval('coursera_structure.course_branch_id_seq'::regclass);


--
-- TOC entry 3110 (class 2604 OID 90302)
-- Name: course id; Type: DEFAULT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.course ALTER COLUMN id SET DEFAULT nextval('coursera_structure.course_id_seq'::regclass);


--
-- TOC entry 3114 (class 2604 OID 90378)
-- Name: item id; Type: DEFAULT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.item ALTER COLUMN id SET DEFAULT nextval('coursera_structure.item_id_seq'::regclass);


--
-- TOC entry 3113 (class 2604 OID 90367)
-- Name: lesson id; Type: DEFAULT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.lesson ALTER COLUMN id SET DEFAULT nextval('coursera_structure.lesson_id_seq'::regclass);


--
-- TOC entry 3115 (class 2604 OID 90386)
-- Name: load id; Type: DEFAULT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.load ALTER COLUMN id SET DEFAULT nextval('coursera_structure.load_id_seq'::regclass);


--
-- TOC entry 3112 (class 2604 OID 90356)
-- Name: module id; Type: DEFAULT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.module ALTER COLUMN id SET DEFAULT nextval('coursera_structure.module_id_seq'::regclass);


--
-- TOC entry 3118 (class 2604 OID 90440)
-- Name: q_option id; Type: DEFAULT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.q_option ALTER COLUMN id SET DEFAULT nextval('coursera_structure.q_options_id_seq'::regclass);


--
-- TOC entry 3117 (class 2604 OID 90413)
-- Name: question id; Type: DEFAULT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.question ALTER COLUMN id SET DEFAULT nextval('coursera_structure.question_id_seq'::regclass);


--
-- TOC entry 3106 (class 2604 OID 16456)
-- Name: chapter id; Type: DEFAULT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.chapter ALTER COLUMN id SET DEFAULT nextval('openedu_structure.chapter_id_seq'::regclass);


--
-- TOC entry 3105 (class 2604 OID 16415)
-- Name: course id; Type: DEFAULT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.course ALTER COLUMN id SET DEFAULT nextval('openedu_structure.open_edu_course_id_seq'::regclass);


--
-- TOC entry 3109 (class 2604 OID 16480)
-- Name: item id; Type: DEFAULT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.item ALTER COLUMN id SET DEFAULT nextval('openedu_structure.item_id_seq'::regclass);


--
-- TOC entry 3107 (class 2604 OID 16464)
-- Name: sequential id; Type: DEFAULT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.sequential ALTER COLUMN id SET DEFAULT nextval('openedu_structure.sequential_id_seq'::regclass);


--
-- TOC entry 3108 (class 2604 OID 16472)
-- Name: vertical id; Type: DEFAULT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.vertical ALTER COLUMN id SET DEFAULT nextval('openedu_structure.vertical_id_seq'::regclass);


--
-- TOC entry 3104 (class 2604 OID 99452)
-- Name: test_table qty; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_table ALTER COLUMN qty SET DEFAULT nextval('public.test_table_id_seq'::regclass);


--
-- TOC entry 3103 (class 2604 OID 16436)
-- Name: test_table id1; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_table ALTER COLUMN id1 SET DEFAULT nextval('public.test_table_id1_seq'::regclass);


--
-- TOC entry 3186 (class 2606 OID 100173)
-- Name: event event_pkey; Type: CONSTRAINT; Schema: coursera_event; Owner: postgres
--

ALTER TABLE ONLY coursera_event.event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);


--
-- TOC entry 3179 (class 2606 OID 90456)
-- Name: assessment assessment_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.assessment
    ADD CONSTRAINT assessment_pkey PRIMARY KEY (id);


--
-- TOC entry 3166 (class 2606 OID 90462)
-- Name: assessment_type assessment_type_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.assessment_type
    ADD CONSTRAINT assessment_type_pkey PRIMARY KEY (id);


--
-- TOC entry 3145 (class 2606 OID 90350)
-- Name: branch course_branch_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.branch
    ADD CONSTRAINT course_branch_pkey PRIMARY KEY (id);


--
-- TOC entry 3141 (class 2606 OID 90307)
-- Name: course course_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.course
    ADD CONSTRAINT course_pkey PRIMARY KEY (id);


--
-- TOC entry 3159 (class 2606 OID 90380)
-- Name: item item_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.item
    ADD CONSTRAINT item_pkey PRIMARY KEY (id);


--
-- TOC entry 3182 (class 2606 OID 90548)
-- Name: item_type item_type_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.item_type
    ADD CONSTRAINT item_type_pkey PRIMARY KEY (id);


--
-- TOC entry 3154 (class 2606 OID 90372)
-- Name: lesson lesson_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.lesson
    ADD CONSTRAINT lesson_pkey PRIMARY KEY (id);


--
-- TOC entry 3162 (class 2606 OID 90464)
-- Name: load load_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.load
    ADD CONSTRAINT load_pkey PRIMARY KEY (id);


--
-- TOC entry 3150 (class 2606 OID 90361)
-- Name: module module_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.module
    ADD CONSTRAINT module_pkey PRIMARY KEY (id);


--
-- TOC entry 3177 (class 2606 OID 90445)
-- Name: q_option q_options_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.q_option
    ADD CONSTRAINT q_options_pkey PRIMARY KEY (id);


--
-- TOC entry 3170 (class 2606 OID 90460)
-- Name: question question_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.question
    ADD CONSTRAINT question_pkey PRIMARY KEY (id);


--
-- TOC entry 3172 (class 2606 OID 90426)
-- Name: question_type question_type_pkey; Type: CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.question_type
    ADD CONSTRAINT question_type_pkey PRIMARY KEY (id);


--
-- TOC entry 3128 (class 2606 OID 16458)
-- Name: chapter chapter_pkey; Type: CONSTRAINT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.chapter
    ADD CONSTRAINT chapter_pkey PRIMARY KEY (id);


--
-- TOC entry 3138 (class 2606 OID 16482)
-- Name: item item_pkey; Type: CONSTRAINT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.item
    ADD CONSTRAINT item_pkey PRIMARY KEY (id);


--
-- TOC entry 3125 (class 2606 OID 16420)
-- Name: course open_edu_course_pkey; Type: CONSTRAINT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.course
    ADD CONSTRAINT open_edu_course_pkey PRIMARY KEY (id);


--
-- TOC entry 3132 (class 2606 OID 16466)
-- Name: sequential sequential_pkey; Type: CONSTRAINT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.sequential
    ADD CONSTRAINT sequential_pkey PRIMARY KEY (id);


--
-- TOC entry 3135 (class 2606 OID 16474)
-- Name: vertical vertical_pkey; Type: CONSTRAINT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.vertical
    ADD CONSTRAINT vertical_pkey PRIMARY KEY (id);


--
-- TOC entry 3122 (class 2606 OID 16441)
-- Name: test_table test_table_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_table
    ADD CONSTRAINT test_table_pkey PRIMARY KEY (id1);


--
-- TOC entry 3183 (class 1259 OID 122903)
-- Name: caq_use_ass_actstartts; Type: INDEX; Schema: coursera_event; Owner: postgres
--

CREATE INDEX caq_use_ass_actstartts ON coursera_event.caq_event USING btree (hse_user_ext_id, assessment_ext_id, action_start_ts);


--
-- TOC entry 3184 (class 1259 OID 100277)
-- Name: event_destname_loadid; Type: INDEX; Schema: coursera_event; Owner: postgres
--

CREATE UNIQUE INDEX event_destname_loadid ON coursera_event.event USING btree (load_id, dest_name);


--
-- TOC entry 3143 (class 1259 OID 90558)
-- Name: branch_ext_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE UNIQUE INDEX branch_ext_id ON coursera_structure.branch USING btree (load_id, ext_id);


--
-- TOC entry 3155 (class 1259 OID 90564)
-- Name: branch_item_ext_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE UNIQUE INDEX branch_item_ext_id ON coursera_structure.item USING btree (load_id, branch_ext_id, ext_id);


--
-- TOC entry 3151 (class 1259 OID 90563)
-- Name: branch_lesson_ext_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE UNIQUE INDEX branch_lesson_ext_id ON coursera_structure.lesson USING btree (load_id, branch_ext_id, ext_id);


--
-- TOC entry 3147 (class 1259 OID 90567)
-- Name: branch_module_ext_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE UNIQUE INDEX branch_module_ext_id ON coursera_structure.module USING btree (load_id, branch_ext_id, ext_id);


--
-- TOC entry 3139 (class 1259 OID 90557)
-- Name: course_ext_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE UNIQUE INDEX course_ext_id ON coursera_structure.course USING btree (load_id, ext_id);


--
-- TOC entry 3142 (class 1259 OID 90566)
-- Name: course_slug; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE UNIQUE INDEX course_slug ON coursera_structure.course USING btree (load_id, slug);


--
-- TOC entry 3173 (class 1259 OID 90522)
-- Name: fki_aq_assessment_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_aq_assessment_id ON coursera_structure.assessment_question USING btree (assessment_id);


--
-- TOC entry 3163 (class 1259 OID 90505)
-- Name: fki_assessment_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_assessment_id ON coursera_structure.item_assessment USING btree (assessment_id);


--
-- TOC entry 3180 (class 1259 OID 90511)
-- Name: fki_assessment_type_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_assessment_type_id ON coursera_structure.assessment USING btree (type_id);


--
-- TOC entry 3148 (class 1259 OID 90481)
-- Name: fki_branch_module; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_branch_module ON coursera_structure.module USING btree (branch_id);


--
-- TOC entry 3146 (class 1259 OID 90475)
-- Name: fki_course_branch; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_course_branch ON coursera_structure.branch USING btree (course_id);


--
-- TOC entry 3164 (class 1259 OID 90499)
-- Name: fki_item_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_item_id ON coursera_structure.item_assessment USING btree (item_id);


--
-- TOC entry 3156 (class 1259 OID 90554)
-- Name: fki_item_type_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_item_type_id ON coursera_structure.item USING btree (type_id);


--
-- TOC entry 3157 (class 1259 OID 90493)
-- Name: fki_lesson_item; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_lesson_item ON coursera_structure.item USING btree (lesson_id);


--
-- TOC entry 3152 (class 1259 OID 90487)
-- Name: fki_module_lesson; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_module_lesson ON coursera_structure.lesson USING btree (module_id);


--
-- TOC entry 3175 (class 1259 OID 90540)
-- Name: fki_qo_question_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_qo_question_id ON coursera_structure.q_option USING btree (question_id);


--
-- TOC entry 3174 (class 1259 OID 90528)
-- Name: fki_question_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_question_id ON coursera_structure.assessment_question USING btree (question_id);


--
-- TOC entry 3167 (class 1259 OID 90534)
-- Name: fki_question_type_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE INDEX fki_question_type_id ON coursera_structure.question USING btree (type_id);


--
-- TOC entry 3160 (class 1259 OID 90555)
-- Name: load_name; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE UNIQUE INDEX load_name ON coursera_structure.load USING btree (name);


--
-- TOC entry 3168 (class 1259 OID 90561)
-- Name: question_ext_id; Type: INDEX; Schema: coursera_structure; Owner: postgres
--

CREATE UNIQUE INDEX question_ext_id ON coursera_structure.question USING btree (load_id, ext_id);


--
-- TOC entry 3126 (class 1259 OID 16499)
-- Name: chapter_ext_id; Type: INDEX; Schema: openedu_structure; Owner: postgres
--

CREATE UNIQUE INDEX chapter_ext_id ON openedu_structure.chapter USING btree (ext_id);


--
-- TOC entry 3123 (class 1259 OID 16489)
-- Name: course_ext_id; Type: INDEX; Schema: openedu_structure; Owner: postgres
--

CREATE UNIQUE INDEX course_ext_id ON openedu_structure.course USING btree (ext_id);


--
-- TOC entry 3130 (class 1259 OID 90330)
-- Name: fki_chapter_id; Type: INDEX; Schema: openedu_structure; Owner: postgres
--

CREATE INDEX fki_chapter_id ON openedu_structure.sequential USING btree (chapter_id);


--
-- TOC entry 3129 (class 1259 OID 90324)
-- Name: fki_course_id; Type: INDEX; Schema: openedu_structure; Owner: postgres
--

CREATE INDEX fki_course_id ON openedu_structure.chapter USING btree (course_id);


--
-- TOC entry 3133 (class 1259 OID 90336)
-- Name: fki_sequential_id; Type: INDEX; Schema: openedu_structure; Owner: postgres
--

CREATE INDEX fki_sequential_id ON openedu_structure.vertical USING btree (sequential_id);


--
-- TOC entry 3136 (class 1259 OID 90342)
-- Name: fki_vertical_id; Type: INDEX; Schema: openedu_structure; Owner: postgres
--

CREATE INDEX fki_vertical_id ON openedu_structure.item USING btree (vertical_id);


--
-- TOC entry 3188 (class 1259 OID 122287)
-- Name: ix_tmp1_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_tmp1_index ON public.tmp1 USING btree (index);


--
-- TOC entry 3189 (class 1259 OID 122294)
-- Name: ix_tmp2_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_tmp2_index ON public.tmp2 USING btree (index);


--
-- TOC entry 3187 (class 1259 OID 122280)
-- Name: ix_tmp_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_tmp_index ON public.tmp USING btree (index);


--
-- TOC entry 3202 (class 2606 OID 90517)
-- Name: assessment_question aq_assessment_id; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.assessment_question
    ADD CONSTRAINT aq_assessment_id FOREIGN KEY (assessment_id) REFERENCES coursera_structure.assessment(id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 3200 (class 2606 OID 90500)
-- Name: item_assessment assessment_id; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.item_assessment
    ADD CONSTRAINT assessment_id FOREIGN KEY (assessment_id) REFERENCES coursera_structure.assessment(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3205 (class 2606 OID 90506)
-- Name: assessment assessment_type_id; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.assessment
    ADD CONSTRAINT assessment_type_id FOREIGN KEY (type_id) REFERENCES coursera_structure.assessment_type(id) NOT VALID;


--
-- TOC entry 3195 (class 2606 OID 90476)
-- Name: module branch_module; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.module
    ADD CONSTRAINT branch_module FOREIGN KEY (branch_id) REFERENCES coursera_structure.branch(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3194 (class 2606 OID 90470)
-- Name: branch course_branch; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.branch
    ADD CONSTRAINT course_branch FOREIGN KEY (course_id) REFERENCES coursera_structure.course(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3199 (class 2606 OID 90494)
-- Name: item_assessment item_id; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.item_assessment
    ADD CONSTRAINT item_id FOREIGN KEY (item_id) REFERENCES coursera_structure.item(id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 3198 (class 2606 OID 90549)
-- Name: item item_type_id; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.item
    ADD CONSTRAINT item_type_id FOREIGN KEY (type_id) REFERENCES coursera_structure.item_type(id) NOT VALID;


--
-- TOC entry 3197 (class 2606 OID 90488)
-- Name: item lesson_item; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.item
    ADD CONSTRAINT lesson_item FOREIGN KEY (lesson_id) REFERENCES coursera_structure.lesson(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3196 (class 2606 OID 90482)
-- Name: lesson module_lesson; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.lesson
    ADD CONSTRAINT module_lesson FOREIGN KEY (module_id) REFERENCES coursera_structure.module(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3204 (class 2606 OID 90535)
-- Name: q_option qo_question_id; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.q_option
    ADD CONSTRAINT qo_question_id FOREIGN KEY (question_id) REFERENCES coursera_structure.question(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3203 (class 2606 OID 90523)
-- Name: assessment_question question_id; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.assessment_question
    ADD CONSTRAINT question_id FOREIGN KEY (question_id) REFERENCES coursera_structure.question(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3201 (class 2606 OID 90529)
-- Name: question question_type_id; Type: FK CONSTRAINT; Schema: coursera_structure; Owner: postgres
--

ALTER TABLE ONLY coursera_structure.question
    ADD CONSTRAINT question_type_id FOREIGN KEY (type_id) REFERENCES coursera_structure.question_type(id) NOT VALID;


--
-- TOC entry 3191 (class 2606 OID 90325)
-- Name: sequential chapter_id; Type: FK CONSTRAINT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.sequential
    ADD CONSTRAINT chapter_id FOREIGN KEY (chapter_id) REFERENCES openedu_structure.chapter(id) NOT VALID;


--
-- TOC entry 3190 (class 2606 OID 90319)
-- Name: chapter course_id; Type: FK CONSTRAINT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.chapter
    ADD CONSTRAINT course_id FOREIGN KEY (course_id) REFERENCES openedu_structure.course(id) NOT VALID;


--
-- TOC entry 3192 (class 2606 OID 90331)
-- Name: vertical sequential_id; Type: FK CONSTRAINT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.vertical
    ADD CONSTRAINT sequential_id FOREIGN KEY (sequential_id) REFERENCES openedu_structure.sequential(id) NOT VALID;


--
-- TOC entry 3193 (class 2606 OID 90337)
-- Name: item vertical_id; Type: FK CONSTRAINT; Schema: openedu_structure; Owner: postgres
--

ALTER TABLE ONLY openedu_structure.item
    ADD CONSTRAINT vertical_id FOREIGN KEY (vertical_id) REFERENCES openedu_structure.vertical(id) NOT VALID;


-- Completed on 2020-04-16 16:22:43

--
-- PostgreSQL database dump complete
--

