"""
Splits the static Olist CSVs into monthly batches, simulating how a real
source system would deliver incremental files month by month.

orders.csv is bucketed by its own order_purchase_timestamp.
order_items / payments / reviews have no purchase date of their own, so each
row inherits its parent order's month via a join on order_id -- this keeps
all four tables' monthly batches aligned to the same order cohort.
"""

import pandas as pd
from pathlib import Path

RAW_DIR = Path("local_source_raw")
OUT_DIR = Path("local_source")

# --- Step 1: load orders and assign a year-month bucket to each row ---
orders = pd.read_csv(RAW_DIR / "olist_orders_dataset.csv")
orders["order_purchase_timestamp"] = pd.to_datetime(orders["order_purchase_timestamp"])
orders["year_month"] = orders["order_purchase_timestamp"].dt.strftime("%Y-%m")

# --- Step 2: write orders, split by month ---
for ym, group in orders.groupby("year_month"):
    month_dir = OUT_DIR / "orders" / ym
    month_dir.mkdir(parents=True, exist_ok=True)
    group.drop(columns=["year_month"]).to_csv(month_dir / f"orders_{ym}.csv", index=False)
    print(f"orders  {ym}: {len(group)} rows")

# --- Step 3: helper to split a child table using orders' month buckets ---
def split_child_table(filename: str, out_subfolder: str):
    child = pd.read_csv(RAW_DIR / filename)
    # bring in year_month by joining on order_id
    child = child.merge(orders[["order_id", "year_month"]], on="order_id", how="left")
    unmatched = child["year_month"].isna().sum()
    if unmatched:
        print(f"  WARNING: {unmatched} rows in {filename} had no matching order_id")
    for ym, group in child.groupby("year_month"):
        month_dir = OUT_DIR / out_subfolder / ym
        month_dir.mkdir(parents=True, exist_ok=True)
        group.drop(columns=["year_month"]).to_csv(
            month_dir / f"{out_subfolder}_{ym}.csv", index=False
        )
    print(f"{out_subfolder}: split into {child['year_month'].nunique()} months")

# --- Step 4: split the three child tables ---
split_child_table("olist_order_items_dataset.csv", "order_items")
split_child_table("olist_order_payments_dataset.csv", "payments")
split_child_table("olist_order_reviews_dataset.csv", "reviews")

print("\nDone. Check local_source/orders, order_items, payments, reviews for monthly subfolders.")