﻿alter system set log_parser_stats = off;
alter system set log_planner_stats = off;
alter system set log_executor_stats = off;

-- снятие dead lock'ов
SELECT * FROM pg_class WHERE oid=12143  --relname='user_range_a';
SELECT * FROM pg_locks WHERE relation in (122359)--(101333)--(100821)--(100653)
SELECT pg_cancel_backend(3296);

-- Параметры конфигурации СУБД (кластера):
show config_file;  --C:/Program Files/PostgreSQL/12/data/postgresql.conf
Самым последним считывается файл postgresql.auto.conf. Этот файл всегда располагается в каталоге данных (PGDATA).
Этот файл не следует изменять вручную. Для его редактирования предназначена команда ALTER SYSTEM:  
				https://postgrespro.ru/docs/postgresql/10/sql-altersystem.html
-- после изменений конфига нужно (изменения некоторых параметров требует перезапуска сервера):
select pg_reload_conf();
select *  from pg_file_settings --Содержимое обоих файлов (postgresql.conf и postgresql.auto.conf) можно
								--увидеть через представление pg_file_settings.
select *  from pg_settings --актуальные значения параметров

SET work_mem TO '2041MB'; --4MB изменение в рамках сеанса


cluster таблица using индекс -- физическое переупорядочивание таблицы на диске

select * from coursera_event.sessmemb_event  where hse_user_ext_id like '%f0192bdf6aa947164d9f88dfcb6e840%'

select * from pg_prepared_statements

select * from pg_stat_activity where state = 'active'

select * from pg_class where relname='caq_event'
SELECT current_setting('block_size'); --8192:->
SELECT (relpages::float*8/1024)::int, * FROM pg_class WHERE relnamespace=100084 --oid=12143  --relname='user_range_a';
SELECT sum(relpages::float*8/1024/1024)::int FROM pg_class
select pg_size_pretty(pg_table_size('coursera_event.cqo_event'))
select pg_size_pretty(pg_table_size('data_mart.aud'))

SELECT table_name, pg_size_pretty( pg_total_relation_size( 'netris.' || table_name) ) 
FROM information_schema.tables 
	WHERE table_schema='netris' ORDER BY table_name;
				    

CREATE TEMP TABLE foo AS SELECT 1 AS id;
SELECT pg_size_pretty(pg_relation_size('pg_temp.foo'));

select * from pg_tables where schemaname = 'coursera_structure' 

SELECT * FROM pg_locks WHERE relation in (122359)--(101333)--(100821)--(100653)
SELECT pg_cancel_backend(6480);

SELECT * FROM pg_class WHERE relname='caq_event' --oid =12143
WHERE oid in (select distinct relation from pg_locks) 
and relkind='r'
and relfilenode>0

select current_setting('min_parallel_table_scan_size')

select current_setting('work_mem')
select current_setting('maintenance_work_mem') -- work_mem для задач поддержки, н-р, для индексации

select current_setting ('shared_buffers')
select current_setting ('synchronous_commit')

select current_setting('temp_file_limit')
select pg_size_pretty(pg_table_size('coursera_event.caq_event'))

select vacuum_count, autovacuum_count, * from pg_stat_all_tables where not relname~'^pg_.*'



Теперь, имея ID транзакции (скажем, он равен 200), попытаемся её остановить:

SELECT pg_cancel_backend(200);
Если она всё еще существует, значит по-хорошему не хочет, и придется ее прервать:

SELECT pg_terminate_backend(200);


select 3/4
select * from pg_stats where tablename='sessmemb_event' schemaname ='openedu_event' 'coursera_structure' order by schemaname, tablename -- вьюха для pg_statistic

select current_setting('default_statistics_target')
show default_statistics_target

select * from pg_statistic_ext -- надо устанавливать(CREATE STATSTICS), используется для анализа совместных распределений многих столбцов и иерархических полей

analyze -- обновить статистику по всей БД

select unnest(array[1, 2, 89]);
drop table my_table;
select 
1 aa, array[1, 1, 1] bb
into temp my_table
union
select 2 aa, array[4, 5, 6] bb;
select aa, unnest(bb) from my_table;

SELECT least(1,2,5)

select pg_relation_filepath('openedu_event.sheet_new')
select * from pg_tablespace

select * from moodle_event.sheet_moodle limit 1 where qa_id=2827627 order by qas_sequencenumber

  select 1 is not null

-- Создание сервера на ubuntu
CREATE EXTENSION postgres_fdw;

select * from pg_available_extensions;
CREATE SERVER ubunserver FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '192.168.202.95', dbname 'ubuntest', port '5432');

select * from pg_shadow;

CREATE USER MAPPING FOR postgres SERVER  ubunserver OPTIONS (user 'postgres', password 'quovadis');

 create FOREIGN  table ubtbl1(id integer,  name text) SERVER ubunserver;

select * from ubtbl1

insert into ubtbl1 values (2, 'Seryoga')

select * from moodle_event.user_range_qo where input_answer is not null
		    
		    
		    
		    
НАЧАЛО пример макрокода:
CREATE OR REPLACE FUNCTION prod_test.p_check()
	RETURNS TABLE (name varchar, foreign_table varchar, missed_rows varchar)
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
DECLARE rec RECORD;
p_code_1 VARCHAR = '';
p_code_2 VARCHAR = '';
p_exec VARCHAR;
p_indicator_links VARCHAR = 't_ind2group;t_ind2meas;t_ind2ter_meas;t_ind2terr_hierarchy;v_indicator2indicator_common;v_indicator2indicator_add';
p_measures_links VARCHAR = 't_measure_val;t_ind2meas';
p_indicator_gr_links VARCHAR = 't_ind2group';
p_types VARCHAR = 't_indicator';
p_terr_measures VARCHAR = 't_terr_measure_val;t_ind2ter_meas';
p_terr_type VARCHAR = 't_territory';
BEGIN
  CREATE OR REPLACE VIEW prod_test.v_indicator2indicator_common AS
  SELECT DISTINCT indicator_common AS indicator_id
  FROM prod_test.t_indicator2indicator;

  CREATE OR REPLACE VIEW prod_test.v_indicator2indicator_add AS
  SELECT DISTINCT indicator_additional AS indicator_id
  FROM prod_test.t_indicator2indicator;
 
  EXECUTE 'DROP TABLE IF EXISTS geo_temp.t_test;
           CREATE TABLE geo_temp.t_test(name VARCHAR, foreign_table VARCHAR, missed_rows VARCHAR);';

p_code_1 = 'INSERT INTO geo_temp.t_test
SELECT ''%table%'', ''%table_from_list%'', COALESCE(string_agg(%field%::VARCHAR, '','' ORDER BY %field%), '''') AS res
FROM prod_test.%table_from_list% fr
WHERE NOT EXISTS
(
 SELECT 1
 FROM prod_test.%table% pm
 WHERE fr.%field% = pm.%field%
);';

   FOR rec IN SELECT 't_indicator'::VARCHAR AS TABLE
                     ,'indicator_id'::VARCHAR AS field
                     ,regexp_split_to_table(p_indicator_links, ';')::VARCHAR AS table_from_list
			  UNION
			  SELECT 't_measure'::VARCHAR AS TABLE
                     ,'measure_id'::VARCHAR AS field
                     ,regexp_split_to_table(p_measures_links, ';')::VARCHAR AS table_from_list
              UNION
			  SELECT 't_indicator_group'::VARCHAR AS TABLE
                     ,'indicator_gr_id'::VARCHAR AS field
                     ,regexp_split_to_table(p_indicator_gr_links, ';')::VARCHAR AS table_from_list
              UNION
			  SELECT 't_indicator_type'::VARCHAR AS TABLE
                     ,'indicator_type_id'::VARCHAR AS field
                     ,regexp_split_to_table(p_types, ';')::VARCHAR AS table_from_list
              UNION
			  SELECT 't_terr_measure'::VARCHAR AS TABLE
                     ,'ter_measure_id'::VARCHAR AS field
                     ,regexp_split_to_table(p_terr_measures, ';')::VARCHAR AS table_from_list
              UNION
			  SELECT 't_territory_type'::VARCHAR AS TABLE
                     ,'ter_type_id'::VARCHAR AS field
                     ,regexp_split_to_table(p_terr_type, ';')::VARCHAR AS table_from_list
   	LOOP
   		p_code_2 = REPLACE(REPLACE(REPLACE(p_code_1, '%table%', rec.table), '%field%', rec.field), '%table_from_list%', rec.table_from_list);
   		EXECUTE p_code_2;
   	END LOOP;
   
   DROP VIEW IF EXISTS prod_test.v_indicator2indicator_common;
   DROP VIEW IF EXISTS prod_test.v_indicator2indicator_add; 
   RETURN QUERY SELECT * FROM geo_temp.t_test ORDER BY name;
END;

$$
;
КОНЕЦ пример макрокода:
