import pandas as pd
from pathlib import Path

RAW_DIR = Path("data/raw")

DATE_COLUMNS = {
    "01_fund_master.csv": ["launch_date"],
    "02_nav_history.csv": ["date"],
    "03_aum_by_fund_house.csv": ["date"],
    "04_monthly_sip_inflows.csv": [], 
    "05_category_inflows.csv": [],
    "06_industry_folio_count.csv": [],
    "07_scheme_performance.csv": [],
    "08_investor_transactions.csv": ["transaction_date"],
    "09_portfolio_holdings.csv": ["portfolio_date"],
    "10_benchmark_indices.csv": ["date"],
}

def load_all_csvs():
    dataframes = {}
    for filename, date_cols in DATE_COLUMNS.items():
        path = RAW_DIR / filename
        df = pd.read_csv(path, parse_dates=date_cols)
        dataframes[filename] = df

        print(f"\n{'='*60}")
        print(f"FILE: {filename}")
        print(f"{'='*60}")
        print(f"Shape: {df.shape}")
        print(f"\nDtypes:\n{df.dtypes}")
        print(f"\nHead:\n{df.head()}")

    return dataframes

if __name__ == "__main__":
    dfs = load_all_csvs()