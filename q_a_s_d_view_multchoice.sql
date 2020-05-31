
drop table if exists last_step;
create table last_step as
SELECT
    quiza.userid,
    quiza.quiz,
    quiza.id AS quizattemptid,
    quiza.attempt,
    quiza.sumgrades,
    qu.preferredbehaviour,
    qa.slot,
    qa.behaviour,
    qa.questionid,
    qa.variant,
    qa.maxmark,
    qa.minfraction,
    qa.flagged,
    -- qas.sequencenumber,
    -- qas.state,
    -- qas.fraction,
    -- qas.userid userid2,
    qas.questionattemptid,
    max(qas.id) attemptstepid,

    qa.questionsummary,
    qa.rightanswer,
    qa.responsesummary
 
FROM mdl_quiz_attempts quiza
JOIN mdl_question_usages qu ON qu.id = quiza.uniqueid
JOIN mdl_question_attempts qa ON qa.questionusageid = qu.id
JOIN mdl_question_attempt_steps qas ON qas.questionattemptid = qa.id
JOIN mdl_question_attempt_step_data qasd ON qasd.attemptstepid = qas.id and (qasd.name like 'choice%' or qasd.name='answer')
-- WHERE quiza.userid=199
group by quiza.userid, quiza.id, quiza.attempt, qa.slot, qas.questionattemptid
ORDER BY quiza.userid, quiza.id, quiza.attempt, qa.slot;

select  * from last_step_options2 limit 1000  group by questionattemptid, name;

drop table if exists last_step_options2;
create table last_step_options2 as
SELECT
    quiza.userid,
    -- quiza.quiz,
    quiza.uniqueid AS qzauniqid,
    -- quiza.attempt,
    -- quiza.sumgrades,
    -- qu.preferredbehaviour,
    -- qa.slot,
    -- qa.behaviour,
    qa.questionid,
    -- qa.variant,
    -- qa.maxmark,
    -- qa.minfraction,
    -- qa.flagged,
    -- qas.sequencenumber,
    qas.state,
    -- qas.fraction,
   -- timestamptz 'epoch' + qas.timecreated * INTERVAL '1 second',  // OR FROM_UNIXTIME(qas.timecreated) IF you are ON MySQL.
    -- qas.userid userid2,
    qas.questionattemptid,
    qasd.attemptstepid,
    qasd.name,
    qasd.value,
    case when (qasd.name like 'choice%') then SPLIT_STR(qasd2.value, ',', cast(right(qasd.name, 1) as unsigned)+1) 
		when (qasd.name='answer')  then SPLIT_STR(qasd2.value, ',', qasd.value+1)
		else 0 
    end stem,
    case when (qasd.name like 'choice%') then qasd.value 
		when (qasd.name='answer' and q_aw2.id>0) then   1
		else 0
    end choice,
    q_aw2.fraction option_val,
    q_aw2.answer option_txt
    -- qasd2.value stem_str,
    -- qasd2.value choice_str,
    -- qa.questionsummary,
    -- qa.rightanswer,
    -- qa.responsesummary
 
FROM mdl_quiz_attempts quiza
JOIN mdl_question_usages qu ON qu.id = quiza.uniqueid
JOIN mdl_question_attempts qa ON qa.questionusageid = qu.id
JOIN mdl_question_attempt_steps qas ON qas.questionattemptid = qa.id
join last_step ls on ls.attemptstepid=qas.id 
 JOIN mdl_question_attempt_step_data qasd ON qasd.attemptstepid = qas.id  and (qasd.name like 'choice%' or qasd.name='answer')
join mdl_question_attempts qa2 ON qa2.id = qa.id
join mdl_question_attempt_steps qas2 on qas2.questionattemptid=qa2.id   -- and qas2.sequencenumber=0  --
join mdl_question_attempt_step_data qasd2 ON qasd2.attemptstepid = qas2.id and qasd2.name='_order'
left join mdl_question_answers q_aw on q_aw.question=qa.questionid and qasd.name='answer'
left join mdl_question_answers q_aw2 on q_aw2.id=case when (qasd.name like 'sub%' or qasd.name like 'choice%') then SPLIT_STR(qasd2.value, ',', cast(right(qasd.name, 1) as unsigned)+1) 
	when (qasd.name='answer')  then SPLIT_STR(qasd2.value, ',', qasd.value+1)
	else 0 
end
 
-- WHERE quiza.userid=199 -- quiza.id=188 
ORDER BY quiza.userid, quiza.id, quiza.attempt, qa.slot, qas.sequencenumber, qasd.name;

limit 10000; -- quiza.id=17 and quiza.userid=12     questionid=23

select name, value, count(*) from mdl_question_attempt_step_data where name='answer' group by name, value;

select * from
(SELECT
    quiza.userid,
    quiza.quiz,
    quiza.id AS quizattemptid,
    quiza.attempt,
    quiza.sumgrades,
    qu.preferredbehaviour,
    qa.slot,
    qa.behaviour,
    qa.questionid,
    qa.variant,
    qa.maxmark,
    qa.minfraction,
    qa.flagged,
    qas.sequencenumber,
    qas.state,
    qas.fraction,
    qas.userid userid2,
    qas.questionattemptid,
    qasd.attemptstepid,
    qasd.name,
    qasd.value,
    qa.questionsummary,
    qa.rightanswer,
    qa.responsesummary
 
FROM mdl_quiz_attempts quiza
JOIN mdl_question_usages qu ON qu.id = quiza.uniqueid
JOIN mdl_question_attempts qa ON qa.questionusageid = qu.id
JOIN mdl_question_attempt_steps qas ON qas.questionattemptid = qa.id
LEFT JOIN mdl_question_attempt_step_data qasd ON qasd.attemptstepid = qas.id) as q
where name='answer' and value='ARPANET'