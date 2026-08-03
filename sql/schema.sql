-- schema.sql

CREATE TABLE dim_fund (
    amfi_code            INTEGER PRIMARY KEY,
    fund_house           TEXT NOT NULL,
    scheme_name          TEXT NOT NULL,
    category             TEXT NOT NULL,
    sub_category         TEXT,
    plan                 TEXT,
    launch_date          DATE,
    benchmark            TEXT,
    expense_ratio_pct    REAL,
    exit_load_pct        REAL,
    min_sip_amount       INTEGER,
    min_lumpsum_amount   INTEGER,
    fund_manager         TEXT,
    risk_category        TEXT,
    sebi_category_code   TEXT
);

CREATE TABLE dim_date (
    date_id       INTEGER PRIMARY KEY,   -- e.g. 20240115 for 2024-01-15
    full_date     DATE NOT NULL,
    year          INTEGER,
    month         INTEGER,
    month_name    TEXT,
    quarter       INTEGER,
    day_of_week   TEXT,
    is_weekend    INTEGER   -- 0/1, SQLite has no native boolean
);

CREATE TABLE fact_nav (
    nav_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    amfi_code     INTEGER NOT NULL,
    date_id       INTEGER NOT NULL,
    nav           REAL NOT NULL,
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code),
    FOREIGN KEY (date_id)   REFERENCES dim_date(date_id)
);

CREATE TABLE fact_transactions (
    transaction_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    investor_id         TEXT NOT NULL,
    amfi_code           INTEGER NOT NULL,
    date_id             INTEGER NOT NULL,
    transaction_type    TEXT NOT NULL,
    amount_inr          INTEGER NOT NULL,
    state               TEXT,
    city                TEXT,
    city_tier           TEXT,
    age_group           TEXT,
    gender              TEXT,
    annual_income_lakh  REAL,
    payment_mode        TEXT,
    kyc_status          TEXT,
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code),
    FOREIGN KEY (date_id)   REFERENCES dim_date(date_id)
);

CREATE TABLE fact_performance (
    amfi_code           INTEGER PRIMARY KEY,
    return_1yr_pct      REAL,
    return_3yr_pct      REAL,
    return_5yr_pct      REAL,
    benchmark_3yr_pct   REAL,
    alpha               REAL,
    beta                REAL,
    sharpe_ratio        REAL,
    sortino_ratio       REAL,
    std_dev_ann_pct     REAL,
    max_drawdown_pct    REAL,
    aum_crore           INTEGER,
    expense_ratio_pct   REAL,
    morningstar_rating  INTEGER,
    risk_grade          TEXT,
    FOREIGN KEY (amfi_code) REFERENCES dim_fund(amfi_code)
);

CREATE TABLE fact_aum (
    aum_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    date_id         INTEGER NOT NULL,
    fund_house      TEXT NOT NULL,
    aum_lakh_crore  REAL,
    aum_crore       INTEGER,
    num_schemes     INTEGER,
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id)
);