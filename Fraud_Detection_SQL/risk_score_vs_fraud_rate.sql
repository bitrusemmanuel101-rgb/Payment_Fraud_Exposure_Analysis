
select 
    
    CASE
        WHEN risk_score >= 0.8 then 'High Risk'
        WHEN risk_score >=0.4 then 'Medium Risk'
        else 'Low Risk' end as Risk_band,
    sum(case when fraud_label = 1 then Transaction_Amount end) *1.00 /
    sum(transaction_amount) as fraud_rate
from 
    transactions_dataset_main

GROUP BY
    risk_band
ORDER BY
    fraud_rate DESC