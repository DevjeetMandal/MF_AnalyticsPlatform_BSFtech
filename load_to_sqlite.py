from sqlalchemy import create_engine
import pandas as pd

engine = create_engine("sqlite:///bluestock_mf.db")

# ---- Build dim_date from the full date range across all your data ----
all_dates = pd.date_range("2022-01-01", "2026-12-31", freq="D")
dim_date = pd.DataFrame({"full_date": all_dates})
dim_date["date_id"] = dim_date["full_date"].dt.strftime("%Y%m%d").astype(int)
dim_date["year"] = dim_date["full_date"].dt.year
dim_date["month"] = dim_date["full_date"].dt.month
dim_date["month_name"] = dim_date["full_date"].dt.month_name()
dim_date["quarter"] = dim_date["full_date"].dt.quarter
dim_date["day_of_week"] = dim_date["full_date"].dt.day_name()
dim_date["is_weekend"] = dim_date["full_date"].dt.dayofweek.isin([5, 6]).astype(int)
dim_date = dim_date[["date_id", "full_date", "year", "month", "month_name",
                     "quarter", "day_of_week", "is_weekend"]]

# ---- Load each dataframe, mapping date -> date_id where needed ----
def to_date_id(date_series):
    return pd.to_datetime(date_series).dt.strftime("%Y%m%d").astype(int)

dim_fund = pd.read_csv("data/raw/01_fund_master.csv")

nav_clean = pd.read_csv("data/processed/nav_history_clean.csv")
nav_clean["date_id"] = to_date_id(nav_clean["date"])
fact_nav = nav_clean[["amfi_code", "date_id", "nav"]]

txn_clean = pd.read_csv("data/processed/investor_transactions_clean.csv")
txn_clean["date_id"] = to_date_id(txn_clean["transaction_date"])
fact_transactions = txn_clean.drop(columns=["transaction_date"])

perf_clean = pd.read_csv("data/processed/scheme_performance_clean.csv")
# Drop columns that already live in dim_fund (scheme_name, fund_house, category, plan)
# -- a star schema fact table should only carry the key (amfi_code) + the measures,
# not repeat descriptive attributes that belong to the dimension table.
# Also drop the flag_* QA columns from Task 3 -- those were for manual review during
# cleaning, not part of the fact_performance schema itself.
fact_performance = perf_clean.drop(columns=[
    "scheme_name", "fund_house", "category", "plan",
    "flag_bad_drawdown", "flag_bad_stddev", "flag_expense_out_of_range"
])

aum = pd.read_csv("data/raw/03_aum_by_fund_house.csv")
aum["date_id"] = to_date_id(aum["date"])
fact_aum = aum.drop(columns=["date"])

tables = {
    "dim_date": dim_date,
    "dim_fund": dim_fund,
    "fact_nav": fact_nav,
    "fact_transactions": fact_transactions,
    "fact_performance": fact_performance,
    "fact_aum": fact_aum,
}

for name, df in tables.items():
    df.to_sql(name, engine, if_exists="append", index=False)
    loaded = pd.read_sql(f"SELECT COUNT(*) AS n FROM {name}", engine)["n"][0]
    print(f"{name}: source rows={len(df)}, rows in DB={loaded}, match={len(df)==loaded}")
