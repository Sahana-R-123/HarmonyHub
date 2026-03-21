import os
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
from sklearn.ensemble import RandomForestRegressor

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

if df.empty:
    print("⚠️ No booking data found")
    exit()

# ===============================
# TRAIN MODEL PER STUDIO
# ===============================

for studio_id, studio_df in df.groupby("studio_id"):

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

    # ---------------------------
    # STEP 2: FEATURE ENGINEERING
    # ---------------------------
    hourly_counts["is_evening"] = hourly_counts["hour"].apply(
        lambda x: 1 if x >= 17 else 0
    )

    # (Optional but powerful)
    if "day_of_week" in studio_df.columns:
        day_map = (
            studio_df.groupby("hour")["day_of_week"]
            .agg(lambda x: x.mode()[0])
            .reset_index()
        )
        hourly_counts = pd.merge(hourly_counts, day_map, on="hour", how="left")
    else:
        hourly_counts["day_of_week"] = 0

    # ---------------------------
    # STEP 3: TRAIN MODEL
    # ---------------------------
    X = hourly_counts[["hour", "is_evening", "day_of_week"]]
    y = hourly_counts["booking_count"]

    model = RandomForestRegressor(
        n_estimators=100,
        random_state=42
    )

    model.fit(X, y)

    # ---------------------------
    # STEP 4: PREDICT BOOKINGS
    # ---------------------------
    hourly_counts["predicted_bookings"] = model.predict(X)

    # ---------------------------
    # STEP 5: FIND BUSY HOURS
    # ---------------------------
    threshold = hourly_counts["booking_count"].quantile(0.75)

    busy_hours = hourly_counts[
        hourly_counts["predicted_bookings"] >= threshold
    ]

    hours_list = busy_hours["hour"].tolist()

    # ---------------------------
    # STEP 6: STORE IN FIRESTORE
    # ---------------------------
    db.collection("studio_busy_hours").document(studio_id).set({
        "busyHours": hours_list,
        "updatedAt": firestore.SERVER_TIMESTAMP
    })

    print(f"✅ {studio_id} → {hours_list}")

print("🎉 All studio busy hours updated successfully")