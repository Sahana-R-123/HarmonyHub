import os
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
from sklearn.ensemble import RandomForestRegressor
from datetime import timezone, timedelta

# ===============================
# FIREBASE INIT
# ===============================

SERVICE_KEY = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__),
        "../../serviceAccountKey.json"
    )
)

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_KEY)
    firebase_admin.initialize_app(cred)

db = firestore.client()

# ===============================
# LOAD DATASET
# ===============================

DATA_PATH = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__),
        "../data/studio_bookings.csv"
    )
)

df = pd.read_csv(DATA_PATH)

# ✅ ===============================
# 🔥 TIMEZONE FIX (IST CONVERSION)
# ===============================
if "hour" in df.columns:
    # If dataset already has wrong hours, FIX THEM
    IST = timezone(timedelta(hours=5, minutes=30))

    if "startTime" in df.columns:
        df["startTime"] = pd.to_datetime(df["startTime"], utc=True)
        df["startTime"] = df["startTime"].dt.tz_convert(IST)

        df["hour"] = df["startTime"].dt.hour
        df["day_of_week"] = df["startTime"].dt.weekday

# ===============================

if df.empty:
    print("⚠️ No booking data found")
    exit()

# ===============================
# PROCESS PER STUDIO
# ===============================

for studio_id, studio_df in df.groupby("studio_id"):

    print(f"\n📊 Processing studio: {studio_id}")

    # ---------------------------
    # STEP 1: HOURLY COUNTS
    # ---------------------------
    hourly_counts = (
        studio_df.groupby("hour")
        .size()
        .reset_index(name="booking_count")
    )

    if hourly_counts.empty:
        continue

    # ===============================
    # 🔥 HYBRID LOGIC STARTS HERE
    # ===============================

    # --------------------------------
    # CASE 1: SMALL DATA → SMART LOGIC
    # --------------------------------
    if len(studio_df) < 30:

        print("⚡ Using SMART LOGIC (low data mode)")

        hourly_counts = (
            studio_df.groupby("hour")
            .size()
            .reset_index(name="booking_count")
        )

        print("📊 Raw hourly data:")
        print(hourly_counts)

        if hourly_counts.empty:
            print("⚠️ No booking data")
            continue

        hourly_counts = hourly_counts[hourly_counts["booking_count"] > 0]

        hourly_counts = hourly_counts.sort_values(
            "booking_count", ascending=False
        )

        top_n = min(3, len(hourly_counts))

        hours_list = hourly_counts.head(top_n)["hour"].astype(int).tolist()

        print("🚀 FINAL HOURS:", hours_list)

    # --------------------------------
    # CASE 2: ENOUGH DATA → ML MODEL
    # --------------------------------
    else:

        print("🤖 Using ML MODEL (high data mode)")

        hourly_counts["is_evening"] = hourly_counts["hour"].apply(
            lambda x: 1 if x >= 17 else 0
        )

        if "day_of_week" in studio_df.columns:
            day_map = (
                studio_df.groupby("hour")["day_of_week"]
                .agg(lambda x: x.mode()[0])
                .reset_index()
            )
            hourly_counts = pd.merge(hourly_counts, day_map, on="hour", how="left")
        else:
            hourly_counts["day_of_week"] = 0

        X = hourly_counts[["hour", "is_evening", "day_of_week"]]
        y = hourly_counts["booking_count"]

        model = RandomForestRegressor(
            n_estimators=100,
            random_state=42
        )

        model.fit(X, y)

        hourly_counts["predicted_bookings"] = model.predict(X)

        threshold = hourly_counts["booking_count"].quantile(0.75)

        busy_hours = hourly_counts[
            hourly_counts["predicted_bookings"] >= threshold
        ]

        hours_list = busy_hours["hour"].astype(int).tolist()

    # ===============================
    # STORE IN FIRESTORE
    # ===============================
    db.collection("studio_busy_hours").document(studio_id).set({
        "busyHours": hours_list,
        "updatedAt": firestore.SERVER_TIMESTAMP
    })

    print(f"✅ {studio_id} → {hours_list}")

print("\n🎉 All studio busy hours updated successfully")