# **Payment Fraud Exposure Analysis- Revenue Integrity & Transaction Decisioning Audit**
This project evaluates transaction data to understand whether reported growth is reliable and whether fraud is affecting revenue integrity. It focuses on identifying risk patterns across users, time cohorts, and transaction segments.

The analysis is designed for a Payments / Monetization Operations context, where both growth quality and fraud exposure matter.

SQL queries? check them out here: [Fraud_detection_SQL](/Fraud_Detection_SQL/) 

# **Executive Background**

As transaction volumes scale, leadership needs confidence that reported growth reflects genuine customer activity and not artificial inflation driven by fraud or abusive behavior. In fast-moving payment systems, fraud does not only create direct financial loss, it also distorts core business metrics such as revenue growth, user expansion, and cohort performance.

This analysis was initiated in response to a set of executive concerns around growth quality and risk exposure across the payment system. The goal was to move beyond surface-level reporting and assess whether growth signals are trustworthy, whether fraud is materially present within operational flows, and how risk is distributed across different user segments and acquisition cohorts.

## The Business Questions:

1. Can we trust our growth?
2. Are newer cohorts becoming riskier?
3. Do we have fraudulent operations? Where? And how heavy are they accross segments?


## Context

**Domain:** Payments Operations / Fraud Analytics  
**Tools:** SQL (PostgreSQL), Power BI, Git Hub, VS code  
**Dataset:** Transactions dataset with fraud labels, user cohorts, device types, authentication methods, merchant data, geographic data, and risk scores  
**Scope:** Cohort lifecycle fraud analysis across full transaction history




# **Data Preparation**

## Data Cleaning & User Cohorting
- Removed duplicates in transaction records
- Handled missing or inconsistent values
- Created a new transactions table from the cleaned dataset
- created a user cohort table



```sql
with transactions_dataset as (
    select 
         *
    from 
        transactions_dataset
    where 
        transaction_amount > 0
)
-- CHECKING FOR DUPLICATES
,
dup_check as (
    select
         *,
        ROW_NUMBER ( ) over (partition by transaction_id, user_id, Transaction_Amount order by date)
    as  DUP_FLAG 
    from
         transactions_dataset
)
-- CREATING CLEAN TRANSACTION_DATASET TABLE
-- 99996 duplicates
-- created a temp table called (transactions_data_main), to contain my cleaned data set
select
     *
into 
    transactions_dataset_MAIN
from
     dup_check
where 
    DUP_FLAG =1

SELECT * 
FROM 
    transactions_dataset_MAIN



-- Created a temp table called (user_cohort) to contain my cohort month
SELECT
    user_id,
    min(date_trunc('month', date)) as Cohort_month
into 
    user_cohort
FROM 
    transactions_dataset_main
GROUP by 
    user_id
```

# Business questions and their answers

## **Question 1: Can we trust our growth?**
This question examines whether transaction growth reflects genuine user activity or is inflated by suspicious or fraudulent behavior.

Focus areas:

1. Share of fraud within total transaction volume
2. Impact of fraud on reported revenue / transaction growth
4. Distortion risk in key growth metrics

```sql
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
```
---
## Answer
![Gross TPV, Net TPV, Fraud TPV, Fraud rate](Fraud_Detection_SQL/assets/kpi.PNG) 
- Total Payment Value (TPV) of the daaset: $4,970,551
- Net TPV: $3,368,933
- Fraud TPV: $1,601,618
- Fraud Rate: 32.2%

#### A significant portion of reported payment volume is not safely monetizable.
We cannot measure our growth to be equal to our revenue.

For a FinTech Industry, although there isn't a written law, the red zone of fraud rates are anything greater than 1%. and we are experiencing a 32.2% fraud rate. This should be prioritized as CRITICAL.

---
## **Question 2: Are newer cohorts becoming riskier?**

This question delves into the first transaction of every user from the start of the year till the end, for the purpose of tracking fraudulent activities from each month to know if fraudulent activities are increasing with new acquisition of users.

```sql

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
    cohort_month,
    count(transaction_amount) as Total_transactions,
    sum(fraud_label) as fraud_transactions,
    round(sum(fraud_label)*1.0/ count(transaction_amount))
     as fraud_rate
from
    Cohort_index_data as ci  
join
    transactions_dataset_main tm
on 
     tm.user_id = ci.user_id
group by
    ci.Cohort_index, cohort_month
```
![Fraud Rates Accross Cohort Lifecycle](Fraud_Detection_SQL/assets/cohort.PNG)



*Fraud Detection Cohort Analysis Report, Showing the Progressive Rates of Fraud Across Cohort Lifecycle*

#### **User Acquisition Quality Over Time**


Cohort fraud rates remained consistently high, with the last generation showing a reduction in fraud intensity. but overall, the range is same.


 


Newer cohorts showed lower transaction volume due to shorter lifecycle maturity.

## **Question 3: Do we have fraudulent operations, where? and how heavy are they across segments?**

This question investigates the presence and distribution of fraud across different dimensions.

Focus areas:

#### Overall fraud rate in the system
- Fraud concentration by:
    1. Merchant Category
    1. Geography
    1. Devices
    1. Card Types

-  Identification of high-risk level caused by fraud rate.

## Answer:
### **1. Fraud Rate by merchants**

```sql
 with Fraud_t as(

SELECT

    merchant_category,
    sum(transaction_amount) as Gross_TPV,
    sum(case when fraud_label =1 then transaction_amount else 0 end ) as Fraud_TPV,
    sum(CASE WHEN fraud_label = 1 then transaction_amount else 0 end)
     * 1.00 / sum(transaction_amount) as Fraud_rate
     
FROM
    transactions_dataset_main
    GROUP by merchant_category
)
SELECT 
  *
from 
    fraud_t
order BY 
    Fraud_rate DESC;
``` 



- Electronics → ~32.7% fraud
- Travel → ~32.5% fraud
- Groceries → ~32.4% fraud
- Restaurants→ ~32.3% fraud
- Clothing → ~31.1% fraud


Fraud is uniform across categories, not concentrated.
It was structurally embedded across all merchant categories, indicating a system-level control failure rather than localized risk pockets.

If Electronics was 60% and Groceries 5%, we’d blame vertical risk.

But here?

The system is leaking everywhere equally.

### **2. Fraud Rate by Geography**

```sql
 with Fraud_t as(

SELECT

   location,
    sum(transaction_amount) as Gross_TPV,
    sum(case when fraud_label =1 then transaction_amount else 0 end ) as Fraud_TPV,
    sum(CASE WHEN fraud_label = 1 then transaction_amount else 0 end)
     * 1.00 / sum(transaction_amount)  as Fraud_rate
     
FROM
    transactions_dataset_main
    GROUP by location
)
SELECT 
  *
from 
    fraud_t
order BY 
    Fraud_rate DESC
```



- Tokyo → ~33.0%
- London → ~ 32.5%
- New York → ~ 32.5%
- Mumbai → ~ 31.6%
- Sydney → ~ 31.4%

Fraud exposure was consistent across both merchant categories and geographies, indicating the issue was not segment-specific but rooted in system-level controls.

  
---

---
#### Analysis Into System_level Controls

### **3. Fraud level in Authentication Methods**

```sql
with Fraud_t as(

SELECT

   authentication_method,
    sum(transaction_amount) as Gross_TPV,
    sum(case when fraud_label =1 then transaction_amount else 0 end ) as Fraud_TPV,
    sum(CASE WHEN fraud_label = 1 then transaction_amount else 0 end)
     * 1.00 / sum(transaction_amount)  as Fraud_rate
     
FROM
    transactions_dataset_main
GROUP by authentication_method
)
SELECT 
  *
from 
    fraud_t
order BY 
    Fraud_rate DESC
``` 


- Biometric → 32.6%
- OTP → 32.5%
- Password → 32.4%
- PIN → 31.3%

Authentication is present, but not effective.

The authentication methods showed minimal variance in fraud rates, indicating that authentication layers were not effectively differentiating between high- and low-risk transactions.

This pattern usually points to:

1. **Weak enforcement**
 
 Authentication may not be triggered based on risk
Everyone goes through similar flows regardless of danger level

2. **Post-authentication fraud**

Fraud happens after authentication succeeds
Meaning auth ≠ trust

3. **Risk engine not influencing auth**

High-risk transactions are not getting stricter checks

---
### **4. Fraud Rate by Device Type**


```sql
 with Fraud_t as(

SELECT

   device_type,
    sum(transaction_amount) as Gross_TPV,
    sum(case when fraud_label =1 then transaction_amount else 0 end ) as Fraud_TPV,
    sum(CASE WHEN fraud_label = 1 then transaction_amount else 0 end)
     * 1.00 / sum(transaction_amount)  as Fraud_rate
     
FROM
    transactions_dataset_main
    GROUP by device_type
)
SELECT 
  *
from 
    fraud_t
order BY 
    Fraud_rate DESC; 
```


- Mobile → 32.6% fraud
- Tablet → 32.2% fraud
- Laptop → 31.7% fraud

Across all devices, fraudulent activities seem to be on a high scale. The range being around 30% allthrough shows that it is not a question of which device is more fraud prone.  

This also cancels out the device types as the culprit to fraudulent activities. since they isn't any vertical scale.

---
### **5. Fraud Rate By Card Type**


```sql
 with Fraud_t as(

SELECT

   card_type,
    sum(transaction_amount) as Gross_TPV,
    sum(case when fraud_label =1 then transaction_amount else 0 end ) as Fraud_TPV,
    sum(CASE WHEN fraud_label = 1 then transaction_amount else 0 end)
     * 1.00 / sum(transaction_amount)  as Fraud_rate
     
FROM
    transactions_dataset_main
    GROUP by card_type
)
SELECT 
  *
from 
    fraud_t
order BY 
    Fraud_rate DESC;  
```



- Discover → 32.6% fraud
- Amex → 32.4% fraud
- Mastercard → 32.0% fraud
- Visa → 31.7% fraud

The same patterns continue across segments, fraudulent activities cut across all parties in each segments, and having same range of fraudulent activities. 

this is tailing towards the Risk Score engine.

**Does the risk score engine do it's job in predicting fraudulent activities?**

---
**And now to check if the risk engine itself detects fraudulent activities**
### 6. **Risk level Vs Fraud Rate**

```sql
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
```



*Risk Detection Engine Properly Detects Activities With High Risks*


- High Risk (risk score 8>) → 80.2% fraud
- Medium Risk (risk score 4>) → 20.2% fraud
- Low Risk (risk score <4)> → 19.7% fraud

The risk model works. The business is not using it properly.

The risk model demonstrated strong predictive power at the high-risk level (~80% fraud rate), but the persistence of high overall fraud suggests that risk signals are not being effectively enforced in transaction decisioning.

- The model clearly identifies danger (80% fraud is huge)
But the overall fraud rate is still ~32%

- That means high-risk transactions are still going through


This reinforced the finding that fraud exposure was system-wide rather than segment or cohort-specific.









**The big question is**

If 80% of high-risk transactions are fraud, and are spread though out the system, why are they not being blocked?

That’s not a data problem.

## That’s a decisioning problem.



# **FINAL DIAGNOSIS BEFORE EXECUTIVE RECOMMENDATIONS**


- **Merchant** → uniform
- **Geography** → uniform
- **Authentication** → uniform
- **Device Type** → Uniform
- **Card Type** → Uniform
- **Risk Score** → highly predictive
- **Cohort Fraud Rate** → Uniform

Despite strong fraud detection capabilities, the system exhibited a ~32% fraud exposure rate due to ineffective enforcement of risk signals. Fraud was uniformly distributed across all segments, indicating a systemic control failure at the transaction decisioning layer rather than localized risk pockets.



**This system is optimized for:**

- Maximizing transaction volume (TPV)

    At the cost of:

- Revenue quality and financial safety

It allows any kind of transactions as long as it passess throught the business. This gives false growth measures.



---
# Recommendations
---

### 1. **Implement Risk-Based Transaction Decisioning**
- **Problem**

The platform successfully identified high-risk transactions, but risky payments continued to pass through the system.

- **Recommendation**

Introduce automated decision rules tied directly to risk bands.

| Risk Band | Recommended Action |
|-----------|-------------------|
| Low Risk | Auto-approve |
| Medium Risk | Step-up authentication (OTP + review) |
| High Risk | Auto-decline or mandatory manual review |

- **Business Impact**

Reduce fraud exposure significantly

Improve net revenue quality

Prevent avoidable loss escalation

---
### 2. **Replace Static Authentication with Dynamic Authentication**
- **Problem**

Authentication methods showed similar fraud rates, indicating low effectiveness.

- **Recommendation**

Move from universal authentication applied equally to all transactions, to risk-triggered authentication calibrated to transaction risk level.

- Low risk → Frictionless checkout
- High risk → Biometric + OTP + review queue

- 
**Business Impact**

Better user experience for safe customers

Stronger protection against risky transactions

Higher conversion efficiency

--- 

### 3. **Strengthen Transaction-Level Controls Over User-Level Blocking**

- **Problem**

Fraud was widely distributed across users rather than concentrated among isolated bad actors.

- **Recommendation**

Since fraud was distributed across users rather than concentrated in isolated bad actors, simple blacklisting is insufficient.

Focus on:
- Transaction behavior analysis
- Velocity checks
- Adaptive risk scoring
- Anomaly detection at transaction level

- **Business Impact**

More scalable fraud prevention

Reduced false assumptions about “bad users”

Better long-term fraud resilience

---
4. **Establish a Revenue Integrity Function**

- **Problem**

Revenue growth and fraud management were operating independently.

- **Recommendation**

Create cross-functional alignment between Revenue Operations, Payments Operations, Risk & Fraud, Product, and Finance — focused on balancing growth with revenue quality.

- **Business Impact**

Better strategic coordination

Reduced leakage

Sustainable monetization growth

---
# **Final Executive Conclusion**

The platform’s primary challenge was not the inability to detect fraud, but the inability to operationalize risk intelligence effectively.

Despite strong fraud detection signals, weak enforcement mechanisms allowed high-risk transactions to continue flowing through the payment system, creating significant revenue leakage and reducing overall revenue quality.

---

# **Closing**

This analysis demonstrated how transaction growth can mask underlying revenue quality issues, and highlighted the importance of integrating risk intelligence directly into operational payment decisioning.


---

*Part of the Emmanuel Bitrus Payments & Revenue Operations Portfolio*
*→ [Back to Portfolio](https://lorenferatacado.my.canva.site/bitrusemmanuel-salesops-portfolio)*
