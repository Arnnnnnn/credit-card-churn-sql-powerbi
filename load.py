import pandas as pd

df = pd.read_csv("BankChurners.csv")
print(df.shape)

df = df.loc[:, ~df.columns.str.startswith("Naive_Bayes")]
print(df.shape)

customers = df[["CLIENTNUM","Customer_Age","Gender","Dependent_count","Education_Level","Marital_Status","Income_Category"]]

accounts = df[["CLIENTNUM", "Attrition_Flag", "Card_Category", "Months_on_book","Total_Relationship_Count", "Credit_Limit"]]

activity = df[["CLIENTNUM", "Months_Inactive_12_mon", "Contacts_Count_12_mon","Total_Revolving_Bal", "Avg_Open_To_Buy", "Total_Amt_Chng_Q4_Q1","Total_Trans_Amt", "Total_Trans_Ct", "Total_Ct_Chng_Q4_Q1","Avg_Utilization_Ratio"]]

print(customers.shape, accounts.shape, activity.shape)

import sqlite3

con=sqlite3.connect("churn.db")
customers.to_sql("customers", con, if_exists="replace", index=False)
accounts.to_sql("accounts", con, if_exists="replace", index=False)
activity.to_sql("activity", con, if_exists="replace", index=False)

for t in ("customers", "accounts", "activity"):
    con.execute(f"CREATE INDEX IF NOT EXISTS idx_{t}_id ON {t}(CLIENTNUM)")
con.commit()

for t in ("customers", "accounts", "activity"):
    n = con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
    print(f"{t}: {n} rows")

rate = con.execute(
    "SELECT ROUND(100.0*SUM(Attrition_Flag='Attrited Customer')/COUNT(*),2) FROM accounts"
).fetchone()[0]
print(f"churn rate: {rate}%")
con.close()