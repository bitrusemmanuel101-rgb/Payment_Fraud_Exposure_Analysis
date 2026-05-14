SELECT
    sum(Transaction_Amount) as TPV,
    sum(case WHEN fraud_label = 1 then Transaction_Amount else 0 end)
 as 
    Fraud_TPV,
    sum(case when fraud_label = 0 then transaction_amount else 0 end)
 as 
    Net_TPV,
    sum(case when fraud_label = 1 then transaction_amount else 0 end)
    * 1.0 / sum(Transaction_Amount) as fraud_rate
from
     transactions_dataset_main;
