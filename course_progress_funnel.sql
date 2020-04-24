-- вставка из вспомогательной таблицы
insert into csess_event - это мои служебные дела. можно считать csess_event=on_demand_sessions.csv. Не делать!!!
  (select *,  128 course_id
  from on_demand_sessions_discr_maths)

-- создание структуры (для конкретного бранча)
drop table if exists struc;

select c.id course_id, c.name cname
          , b.ext_id bid, coalesce(b.name, 'Original') bname
          , m.ext_id mid, m.ord m_ord, m.name m_name
          , l.ext_id lid, l.ord l_ord, l.name l_name
          , i.ext_id iid, i.ord i_ord, i.name i_name, i.type_id, max(it.descr) descr, max(cast(it.graded as int)) graded
          , c.load_id
          , min(on_demand_sessions_start_ts) strt -- справочная информация о начале версии (branch)
          , max(on_demand_sessions_end_ts) fin  -- справочная информация об окончании версии (branch)
into  struc
from  coursera_structure.course c
      left join coursera_structure.branch b on b.course_id=c.id 
      left join coursera_structure.module m on m.branch_id = b.id
      left join coursera_structure.lesson l on l.module_id = m.id
      left join coursera_structure.item i on i.lesson_id = l.id
      left join coursera_event.csess_event s on s.branch_ext_id=b.ext_id and s.course_id=c.id -- csess_event=on_demand_sessions.csv
      left join coursera_structure.item_type it on it.id=i.type_id
where c.id=125
group by c.id, c.name, b.ext_id, b.name, m.ext_id, m.ord, m.name, l.ext_id, l.ord, l.name
, i.ext_id, i.ord, i.name, i.type_id, c.load_id;

-- выбор пользователей для бранчей
drop table if exists progress;

SELECT 
    cp.hse_user_id
	, cp.course_id
	, s.course_branch_id  -- версии только тех курсов, в которых user участвовал (через  on_demand_session)
	, course_item_id
	, count(*) cnt -- количество взаимодействий с item'ом
	, min(course_progress_state_type_id) course_progress_min  -- минимальный успех в рамках item
	, max(course_progress_state_type_id) course_progress_max  -- максимальный успех в рамках item
into temp progress
FROM public.course_progress_pyth_bas cp
	join on_demand_session_memberships_pyth_bas sm on  cp.hse_user_id=sm.hse_user_id 
	join on_demand_sessions_pyth_bas s on s.on_demand_session_id=sm.on_demand_session_id
group by cp.hse_user_id, cp.course_id, s.course_branch_id, course_item_id; 

select * from progress

-- итог:
select struc.course_id, cname, bid, bname, min(strt) strt_session, m_ord, l_ord, i_ord, i_name
		, max(type_id) type_id, max(descr) type_descr, max(graded) graded -- справочная информация, полностью определяется ключом группы
		, sum(2 - course_progress_max) started    -- считаем результат только по максимальному успеху: 2-1=1(started), 2-2=0 (completed)
		, sum(course_progress_max - 1) completed  -- считаем результат только по максимальному успеху: 1-1=0(started), 2-1=1 (completed)
		, count(distinct hse_user_id) total  -- контрольная сумма должна равняться сумме 2-х предыдущих столбцов
		, sum(cnt) interact_cnt  -- общее количество взаимодействий
from struc
left join progress on struc.iid=progress.course_item_id and progress.course_branch_id=struc.bid
group by  struc.course_id, cname
      , bid, bname
      , m_ord
      , l_ord
      , i_ord, i_name
order by  struc.course_id, cname
      , bid
      , m_ord
      , l_ord
      , i_ord
	  
	  --, hse_user_id
	  --, course_progress_state_type_id


