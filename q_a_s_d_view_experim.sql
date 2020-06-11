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
    qas.sequencenumber,
    qas.state,
    qas.fraction,
   -- timestamptz 'epoch' + qas.timecreated * INTERVAL '1 second',  // OR FROM_UNIXTIME(qas.timecreated) IF you are ON MySQL.
    qas.userid userid2,
    qas.questionattemptid,
    qas.id attemptstepid,
    qasd.attemptstepid attemptstepid_r,
    qasd.name,
    qasd.value,
    case when (qasd.name like 'sub%' or qasd.name like 'choice%') then SPLIT_STR(qasd2.value, ',', cast(right(qasd.name, 1) as unsigned)+1) else 0 end stem,
    case when qasd.name like 'sub%' then SPLIT_STR(qasd3.value, ',', qasd.value) else 0 end choice,
	q_aw.fraction option_val,
    q_aw.answer option_txt,
    -- qasd2.value stem_str,
    -- qasd3.value choice_str,
    qa.questionsummary,
    qa.rightanswer,
    qa.responsesummary
 
FROM mdl_quiz_attempts quiza
JOIN mdl_question_usages qu ON qu.id = quiza.uniqueid
JOIN mdl_question_attempts qa ON qa.questionusageid = qu.id
JOIN mdl_question_attempt_steps qas ON qas.questionattemptid = qa.id
LEFT JOIN mdl_question_attempt_step_data qasd ON qasd.attemptstepid = qas.id
join mdl_question_attempts qa2 ON qa2.id = qa.id
join mdl_question_attempt_steps qas2 on qas2.questionattemptid=qa2.id and qas2.sequencenumber=0
join mdl_question_attempt_step_data qasd2 ON qasd2.attemptstepid = qas2.id and qasd2.name in ('_stemorder', '_order')
left join mdl_question_attempt_step_data qasd3 ON qasd3.attemptstepid = qas2.id and qasd3.name='_choiceorder'
left join mdl_question_answers q_aw on q_aw.id=case when (qasd.name like 'sub%' or qasd.name like 'choice%') then SPLIT_STR(qasd2.value, ',', cast(right(qasd.name, 1) as unsigned)+1) 
	when (qasd.name='answer')  then SPLIT_STR(qasd2.value, ',', qasd.value+1)
	else 0 
end and q_aw.question = qa.questionid
 WHERE quiza.userid=199 -- quiza.id=188 
ORDER BY quiza.userid, quiza.id, quiza.attempt, qa.slot, qas.sequencenumber, qasd.name;


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
where name='answer' and value='ARPANET';

reset master;

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
    qas.sequencenumber,
    qas.state,
    qas.fraction,
   -- timestamptz 'epoch' + qas.timecreated * INTERVAL '1 second',  // OR FROM_UNIXTIME(qas.timecreated) IF you are ON MySQL.
    qas.userid userid2,
    qas.questionattemptid,
    qasd.attemptstepid,
    qasd.name,
    qasd.value,
    case when (qasd.name like 'choice%') then SPLIT_STR(qasd2.value, ',', cast(right(qasd.name, 1) as unsigned)+1) 
		when (qasd.name='answer')  then SPLIT_STR(qasd2.value, ',', qasd.value+1)
		else 0 
    end stem,
    qasd.value choice,
    q_aw.fraction option_val,
    q_aw.answer option_txt,
    qasd2.value stem_str,
    qasd2.value choice_str,
    qa.questionsummary,
    qa.rightanswer,
    qa.responsesummary
 
FROM mdl_quiz_attempts quiza
JOIN mdl_question_usages qu ON qu.id = quiza.uniqueid
JOIN mdl_question_attempts qa ON qa.questionusageid = qu.id
JOIN mdl_question_attempt_steps qas ON qas.questionattemptid = qa.id
LEFT JOIN mdl_question_attempt_step_data qasd ON qasd.attemptstepid = qas.id
join mdl_question_attempts qa2 ON qa2.id = qa.id
join mdl_question_attempt_steps qas2 on qas2.questionattemptid=qa2.id  and qas2.sequencenumber=0
join mdl_question_attempt_step_data qasd2 ON qasd2.attemptstepid = qas2.id -- and qasd2.name='_order'
left join mdl_question_answers q_aw on q_aw.id=case when (qasd.name like 'sub%' or qasd.name like 'choice%') then SPLIT_STR(qasd2.value, ',', cast(right(qasd.name, 1) as unsigned)+1) 
	when (qasd.name='answer')  then SPLIT_STR(qasd2.value, ',', qasd.value+1)
	else 0 
end
 
WHERE quiza.userid=199 -- quiza.id=188 
ORDER BY quiza.userid, quiza.id, quiza.attempt, qa.slot, qas.sequencenumber, qasd.name
limit 10000;