-- queries.sql : SQL analysis of credit card customer churn
-- Database: churn.db (built by load.py)
--   customers(CLIENTNUM, Customer_Age, Gender, Dependent_count, Education_Level, Marital_Status, Income_Category)
--   accounts (CLIENTNUM, Attrition_Flag, Card_Category, Months_on_book, Total_Relationship_Count, Credit_Limit)
--   activity (CLIENTNUM, Months_Inactive_12_mon, Contacts_Count_12_mon, Total_Revolving_Bal, Avg_Open_To_Buy,
--             Total_Amt_Chng_Q4_Q1, Total_Trans_Amt, Total_Trans_Ct, Total_Ct_Chng_Q4_Q1, Avg_Utilization_Ratio)
-- Churn = Attrition_Flag = 'Attrited Customer' (true = 1, false = 0 in SQLite, so SUM counts churners)
-- Overall churn rate: 16.07% (1,627 of 10,127 customers)


-- Q1: Churn rate by card category
-- Finding: Platinum looks highest (25%) but has only 20 customers, so it is a small sample.
-- Among the larger groups: Gold 18.1%, Blue 16.1% (9,436 customers, so it tracks the overall rate), Silver 14.77%.
SELECT Card_Category,
       COUNT(*) AS customers,
       SUM(Attrition_Flag = 'Attrited Customer') AS churned,
       ROUND(100.0 * SUM(Attrition_Flag = 'Attrited Customer') / COUNT(*), 2) AS churn_rate_pct
FROM accounts
GROUP BY Card_Category
ORDER BY churn_rate_pct DESC;


-- Q2: Churn rate for customers holding more than 4 products with the bank
-- Finding: 3,757 customers, 423 churned = 11.26%, below the overall 16.07%.
SELECT COUNT(*) AS customers,
       SUM(Attrition_Flag = 'Attrited Customer') AS churned,
       ROUND(100.0 * SUM(Attrition_Flag = 'Attrited Customer') / COUNT(*), 2) AS churn_rate_pct
FROM accounts
WHERE Total_Relationship_Count > 4;


-- Q3: Churn rate for customers holding 2 or fewer products
-- Finding: 2,153 customers, 579 churned = 26.89%, far above the overall rate.
-- Together with Q2: the fewer products a customer holds, the more likely they are to leave.
SELECT COUNT(*) AS customers,
       SUM(Attrition_Flag = 'Attrited Customer') AS churned,
       ROUND(100.0 * SUM(Attrition_Flag = 'Attrited Customer') / COUNT(*), 2) AS churn_rate_pct
FROM accounts
WHERE Total_Relationship_Count <= 2;


-- Q4: Churn rate by income category (JOIN customers + accounts)
-- Finding: churn barely changes with income (13.5% to 17.3%), so who the customer is matters
-- much less than what they do. The six customer counts add up to 10,127, so the JOIN lost no rows.
SELECT c.Income_Category,
       COUNT(*) AS customers,
       SUM(a.Attrition_Flag = 'Attrited Customer') AS churned,
       ROUND(100.0 * SUM(a.Attrition_Flag = 'Attrited Customer') / COUNT(*), 2) AS churn_rate_pct
FROM customers c
JOIN accounts a ON c.CLIENTNUM = a.CLIENTNUM
GROUP BY c.Income_Category
ORDER BY churn_rate_pct DESC;


-- Q5: Which income bands churn above the overall average? (CTE + HAVING)
-- WHERE filters rows before grouping; HAVING filters groups after the rate is calculated.
-- The CTE calculates the overall rate once (16.07%) so nothing is hard-coded.
-- Finding: $120K+ (17.33%), Less than $40K (17.19%) and Unknown (16.82%) are above average.
WITH overall AS (
    SELECT 100.0 * SUM(Attrition_Flag = 'Attrited Customer') / COUNT(*) AS rate
    FROM accounts
)
SELECT c.Income_Category,
       COUNT(*) AS customers,
       ROUND(100.0 * SUM(a.Attrition_Flag = 'Attrited Customer') / COUNT(*), 2) AS churn_rate_pct
FROM customers c
JOIN accounts a ON c.CLIENTNUM = a.CLIENTNUM
GROUP BY c.Income_Category
HAVING 100.0 * SUM(a.Attrition_Flag = 'Attrited Customer') / COUNT(*) > (SELECT rate FROM overall)
ORDER BY churn_rate_pct DESC;


-- Q6: Churn rate by age band (CASE WHEN)
-- CASE WHEN is SQL's if/else: conditions are checked top to bottom and the first true one wins.
-- Finding: age matters little. Churn peaks at about 17% in the 40s and 50s, and the small Under 30 group is lowest (8.72%).
SELECT CASE
           WHEN c.Customer_Age < 30 THEN 'Under 30'
           WHEN c.Customer_Age < 40 THEN '30s'
           WHEN c.Customer_Age < 50 THEN '40s'
           WHEN c.Customer_Age < 60 THEN '50s'
           ELSE '60+'
       END AS age_band,
       COUNT(*) AS customers,
       ROUND(100.0 * SUM(a.Attrition_Flag = 'Attrited Customer') / COUNT(*), 2) AS churn_rate_pct
FROM customers c
JOIN accounts a ON c.CLIENTNUM = a.CLIENTNUM
GROUP BY age_band
ORDER BY MIN(c.Customer_Age);


-- Q7: Does inactivity predict churn? (JOIN activity + accounts, HAVING)
-- HAVING COUNT(*) >= 100 drops tiny groups (the 0-month group has only 29 customers) so rates are not misleading.
-- Finding: churn climbs from 4.48% at 1 month inactive to 29.89% at 4 months, then eases to 17.98% at 5 and 15.32% at 6 months.
SELECT act.Months_Inactive_12_mon AS months_inactive,
       COUNT(*) AS customers,
       ROUND(100.0 * SUM(a.Attrition_Flag = 'Attrited Customer') / COUNT(*), 2) AS churn_rate_pct
FROM activity act
JOIN accounts a ON act.CLIENTNUM = a.CLIENTNUM
GROUP BY act.Months_Inactive_12_mon
HAVING COUNT(*) >= 100
ORDER BY act.Months_Inactive_12_mon;


-- Q8: Top 3 customers by transaction amount in each card category (window function RANK)
-- PARTITION BY restarts the ranking inside each card category. ORDER BY decides who ranks first.
-- A window function cannot be filtered in the same SELECT, so the CTE ranks first and the outer query keeps rank <= 3.
-- RANK gives tied customers the same rank, so a category can return more than 3 rows if there are ties.
-- Finding: top yearly spend is 18,484 (Blue), 17,628 (Silver), 16,712 (Platinum), 16,328 (Gold). No ties, so 3 rows per category.
WITH ranked AS (
    SELECT a.Card_Category,
           a.CLIENTNUM,
           act.Total_Trans_Amt,
           RANK() OVER (PARTITION BY a.Card_Category ORDER BY act.Total_Trans_Amt DESC) AS rnk
    FROM accounts a
    JOIN activity act ON a.CLIENTNUM = act.CLIENTNUM
)
SELECT Card_Category, rnk, CLIENTNUM, Total_Trans_Amt
FROM ranked
WHERE rnk <= 3
ORDER BY Card_Category, rnk;


-- Q9: Customers split into 10 equal groups by credit utilization, with churn rate in each (NTILE)
-- NTILE(10) sorts customers by utilization and cuts them into 10 groups of about 1,013.
-- Caution: at least a fifth of customers have utilization of exactly 0 (deciles 1 and 2 are entirely 0, decile 3 partly),
-- so these deciles are filled with ties and SQLite splits tied customers arbitrarily.
-- Read deciles 1 to 3 together (about 32% churn), not one by one.
-- Finding: churn is highest at zero or very low utilization, lowest in deciles 8 and 9 (6.52% and 6.03%)
-- and rises again at the top (decile 10: 13.24%).
WITH bucketed AS (
    SELECT act.Avg_Utilization_Ratio AS util,
           a.Attrition_Flag,
           NTILE(10) OVER (ORDER BY act.Avg_Utilization_Ratio) AS decile
    FROM activity act
    JOIN accounts a ON act.CLIENTNUM = a.CLIENTNUM
)
SELECT decile,
       COUNT(*) AS customers,
       ROUND(MIN(util), 3) AS min_util,
       ROUND(MAX(util), 3) AS max_util,
       ROUND(100.0 * SUM(Attrition_Flag = 'Attrited Customer') / COUNT(*), 2) AS churn_rate_pct
FROM bucketed
GROUP BY decile
ORDER BY decile;


-- Q10: Risk segments combining low activity and inactivity (CASE WHEN on two columns)
-- Low activity = 60 or fewer transactions in the year. Inactive = 3 or more months without activity.
-- Finding: customers who are both low activity and inactive churn at 43.73%, versus 2.52% for neither.
-- Low activity does most of the work: low activity alone is 25.56%, while inactivity alone (5.68%) is far less risky once transactions are normal.
SELECT CASE
           WHEN act.Total_Trans_Ct <= 60 AND act.Months_Inactive_12_mon >= 3 THEN 'Low activity + 3+ months inactive'
           WHEN act.Total_Trans_Ct <= 60 THEN 'Low activity only'
           WHEN act.Months_Inactive_12_mon >= 3 THEN '3+ months inactive only'
           ELSE 'Neither'
       END AS segment,
       COUNT(*) AS customers,
       ROUND(100.0 * SUM(a.Attrition_Flag = 'Attrited Customer') / COUNT(*), 2) AS churn_rate_pct
FROM activity act
JOIN accounts a ON act.CLIENTNUM = a.CLIENTNUM
GROUP BY segment
ORDER BY churn_rate_pct DESC;
