



---Created a temp table called Cohort_index_table to contain my cohort index

select
    uc.cohort_month,
    t.user_id,
    date_trunc('month', t.date) as transaction_month,
    (
    extract(year from age(date_trunc('month', t.date), uc.cohort_month))*12 
    +
    extract(month from age(date_trunc('month', t.date), uc.cohort_month))
    ) as Cohort_index
into
    Cohort_index_data
from
    transactions_dataset_main as t 
join
    user_cohort as uc  
on
    t.user_id = uc.user_id
order by
    t.user_id, transaction_month ;

--- Calculated fraud rate by cohort index
select
    Cohort_index,
    count(transaction_amount) as Total_transactions,
    sum(fraud_label) as fraud_transactions,
    round(sum(fraud_label)*1.0/ count(transaction_amount)*100)
     as fraud_rate
from
    Cohort_index_data as ci  
join
    transactions_dataset_main tm
on 
     tm.user_id = ci.user_id
group by
    ci.Cohort_index;



