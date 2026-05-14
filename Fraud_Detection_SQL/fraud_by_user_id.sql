-- fraud by card type
with Fraud_t as(

SELECT
    user_id,
    sum(transaction_amount) as Gross_TPV,
    sum(case when fraud_label =1 then transaction_amount else 0 end ) as Fraud_TPV,
    sum(CASE WHEN fraud_label = 1 then transaction_amount else 0 end)
     * 1.00 / sum(transaction_amount) as Fraud_rate
     
FROM
    transactions_dataset_main
    GROUP by  user_id

)

SELECT 
  *
from fraud_t
order BY Fraud_rate DESC
limit 10;


