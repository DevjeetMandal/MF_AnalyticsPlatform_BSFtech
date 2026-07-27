import requests
import pandas as pd
from pathlib import Path

RAW_DIR = Path("data/raw")

SCHEMES = {
    125497: "hdfc_top100_direct",
    119551: "sbi_bluechip",
    120503: "icici_bluechip",
    118632: "nippon_large_cap",
    119092: "axis_bluechip",
    120841: "kotak_bluechip",
}

def fetch_nav(amfi_code: int) -> pd.DataFrame:
    url = f"https://api.mfapi.in/mf/{amfi_code}"
    response = requests.get(url, timeout=10)
    response.raise_for_status() 
    payload = response.json()

    nav_df = pd.DataFrame(payload["data"]) 
    nav_df["date"] = pd.to_datetime(nav_df["date"], format="%d-%m-%Y")
    nav_df["nav"] = nav_df["nav"].astype(float)
    nav_df["amfi_code"] = amfi_code
    nav_df["scheme_name"] = payload["meta"]["scheme_name"]

    return nav_df.sort_values("date").reset_index(drop=True)

if __name__ == "__main__":
    for code, tag in SCHEMES.items():
        print(f"Fetching {tag} ({code})...")
        df = fetch_nav(code)
        out_path = RAW_DIR / f"live_nav_{tag}_{code}.csv"
        df.to_csv(out_path, index=False)
        print(f"  Saved {len(df)} rows -> {out_path}")