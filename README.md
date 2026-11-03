# Credit Card Customer Churn: SQL Analysis and Power BI Dashboard

An end-to-end analysis of which credit card customers leave a bank and what they do before leaving, built with **SQL (SQLite + Python)** and **Power BI**.

## Business problem

A bank manager is worried that more and more customers are closing their credit card accounts. The goal is to find out **who is leaving and what warning signs show up first**, so the bank can contact at-risk customers early and offer better service.

## Dataset

- **File:** `BankChurners.csv` (Kaggle: *Credit Card customers*)
- **Size:** 10,127 customers
- **Churn rate:** 16.07% (1,627 attrited customers), so the data is imbalanced
- **Contents:** demographics (age, gender, education, income), card details (category, credit limit, products held) and behaviour (transactions, inactive months, contacts, utilization)
- **Cleaning:** the last two `Naive_Bayes_Classifier...` columns were dropped. They are pre-computed model outputs and would leak the answer.

## Tools

| Tool | Used for |
|---|---|
| SQLite | Database and all analysis queries |
| Python (pandas, sqlite3) | Loading the CSV, splitting tables, running queries |
| Power BI | Interactive dashboard |
| Git / GitHub | Version control |

## Project structure

```
Credit Card Customers/
├── BankChurners.csv          # raw data
├── load.py                   # builds churn.db from the CSV
├── queries.sql               # 10 analysis queries, each with its finding
├── run.py                    # runs the queries and prints results
├── dashboard/
│   ├── Churn-PowerBi.pbix    # Power BI file
│   └── Churn-PowerBi.pdf     # exported dashboard
├── .gitignore
└── README.md
```

## Database design

`load.py` splits the single wide CSV into three tables, all keyed on `CLIENTNUM`, so the analysis uses real joins:

| Table | What it holds |
|---|---|
| `customers` | Who they are: age, gender, dependents, education, marital status, income |
| `accounts` | Their card: attrition flag, card category, months on book, products held, credit limit |
| `activity` | What they do: inactive months, contacts, revolving balance, transactions, utilization |

## Questions answered

`queries.sql` holds 10 queries, each with a comment explaining the SQL concept and the finding. Overall churn is 16.07%, and each answer below should be read against that.

### Q1. Which card category has the highest churn?
**Concepts:** `GROUP BY`, conditional aggregation
**Answer:** Platinum looks highest at 25% (5 of 20 customers), but that is too small a sample to act on. Among the larger groups, Gold is next at 18.1% (116 customers), then Blue at 16.1% (9,436 customers) and Silver at 14.77% (555 customers). Blue makes up most of the portfolio, so its rate sits almost exactly on the overall 16.07%.

### Q2. Do customers who hold more than 4 products with the bank churn less?
**Concepts:** `WHERE`
**Answer:** Yes. 3,757 customers hold more than 4 products, and 423 of them churned, a rate of **11.26%**, below the overall average.

### Q3. Do customers who hold 2 or fewer products churn more?
**Concepts:** `WHERE`
**Answer:** Yes. 2,153 customers hold 2 or fewer products, and 579 churned, a rate of **26.89%**. Together with Q2: the fewer products a customer holds, the more likely they are to leave.

### Q4. Does income affect churn?
**Concepts:** `JOIN` (customers + accounts)
**Answer:** Barely. Churn ranges only from 13.5% to 17.3% across income categories. The six group counts add up to 10,127, so the join lost no rows.

### Q5. Which income bands churn above the overall average?
**Concepts:** CTE, `HAVING`, subquery
**Answer:** $120K+ (17.33%), Less than $40K (17.19%) and Unknown (16.82%). The CTE calculates the overall rate once, so nothing is hard-coded.

### Q6. Does age affect churn?
**Concepts:** `CASE WHEN`
**Answer:** Only slightly. Churn peaks at about 17% for customers in their 40s and 50s, and the small Under 30 group is lowest.

### Q7. Does months of inactivity predict churn?
**Concepts:** `JOIN`, `HAVING COUNT(*) >= 100`
**Answer:** Yes. Churn climbs from **4.48%** at 1 inactive month to **29.89%** at 4 months, then eases at 5 and 6 months. Groups under 100 customers (such as the 29 customers with 0 months) are excluded so the rates are not misleading.

### Q8. Who are the top 3 customers by transaction amount in each card category?
**Concepts:** window function (`RANK`, `PARTITION BY`), CTE
**Answer:** The biggest spenders per category have yearly transaction totals of 18,484 (Blue), 17,628 (Silver), 16,712 (Platinum) and 16,328 (Gold). This works as a ready-made VIP list for retention outreach. There were no ties in the top 3, so each category returns exactly 3 rows.

### Q9. How does churn change with credit utilization?
**Concepts:** `NTILE(10)`, CTE
**Answer:** The pattern is U-shaped. Churn is highest at zero or very low utilization, lowest in the middle (deciles 8 and 9) and rises again at the top. At least a fifth of customers have exactly zero utilization, so deciles 1 to 3 hold many ties and are best read together (about 32% churn). For reference, decile 10 (utilization above 0.7) churns at 13.24%, and deciles 8 and 9 are lowest at 6.52% and 6.03%.

### Q10. Which combination of behaviours marks the highest-risk customers?
**Concepts:** `CASE WHEN` on two columns
**Answer:** Customers with 60 or fewer transactions in the year *and* 3 or more inactive months churn at **43.73%**, versus **2.52%** for customers with neither. Low activity does most of the work: low activity alone gives 25.56%, while inactivity alone is only 5.68%.

## Key findings

Overall churn rate is **16.07%**.

1. **Behaviour matters far more than demographics.** Churn barely changes across income bands (13.5% to 17.3%) and age bands (peaks at about 17% in the 40s and 50s). What customers *do* separates leavers from stayers.
2. **Customers with fewer products leave more.** Those holding 2 or fewer products churn at **26.89%** (2,153 customers), while those holding more than 4 churn at **11.26%** (3,757 customers).
3. **Inactivity is a warning sign.** Churn rises from **4.48%** at 1 inactive month to **29.89%** at 4 inactive months, then eases at 5 and 6 months.
4. **Low activity plus inactivity is the strongest signal.** Customers with 60 or fewer transactions in the year *and* 3 or more inactive months churn at **43.73%**, versus **2.52%** for customers with neither. Low transaction count drives most of this: low activity alone gives 25.56%, while inactivity alone (with normal transaction levels) is only 5.68%.
5. **Credit utilization is U-shaped.** Churn is highest at zero or very low utilization (about 32% across the lowest three deciles), lowest in the middle (deciles 8 and 9) and rises again at the top.
6. **Card category matters little.** Platinum shows the highest churn (25%) but has only 20 customers, so it is too small a sample to act on. Gold (18.1%), Blue (16.1%) and Silver (14.77%) sit close to the overall rate.

## Power BI dashboard

[View the dashboard (PDF)](dashboard/Churn-PowerBi.pdf)

*Credit Card Churn: Who Leaves and Why* includes a churn rate KPI card, slicers for card category and income category, and three charts showing churn rate by number of transactions, by months inactive and by number of contacts.

## Recommendations

- **Build an early-warning list** of customers with low transaction counts and 3 or more inactive months. This segment churns at about 44%, so outreach here has the best chance of saving customers.
- **Encourage cross-selling** to customers holding 1 or 2 products. Holding more products is linked to much lower churn.
- **Target reactivation offers** at customers with zero or very low card utilization.
- **Do not base retention campaigns on income or age**, since churn barely differs across those groups.

## Limitations

- This is a descriptive analysis. It shows which groups churn more, not why, and does not build a predictive model.
- Relationships are correlations. For example, fewer products may signal low engagement rather than cause churn.
- At least a fifth of customers have exactly zero utilization, so the utilization deciles contain many ties. The lowest three deciles are best read together.
- Small groups (such as Platinum cardholders) give unreliable rates.

## How to run

```bash
pip install pandas
python load.py     # creates churn.db from BankChurners.csv
python run.py      # runs the queries and prints results
```

Requires Python 3.8+. SQLite ships with Python, so no database install is needed.

## Author

**Aryan Khanna**
MBA (Finance), University of Delhi · [GitHub](https://github.com/Arnnnnnn/)
