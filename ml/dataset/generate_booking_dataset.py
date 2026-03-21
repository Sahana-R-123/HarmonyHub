import os
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

# ===============================
# FIREBASE INIT
# ===============================

SERVICE_KEY_PATH = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__),
        "../../serviceAccountKey.json"
    )
)

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_KEY_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

# ===============================
# FETCH BOOKINGS
# ===============================

rows = []

studios = db.collection("studios").stream()

for studio in studios:
    studio_id = studio.id

    bookings = studio.reference.collection("bookings").stream()

    for booking in bookings:
        data = booking.to_dict()

        # ✅ Ensure startTime exists
        if "startTime" not in data:
            continue

        try:
            dt = data["startTime"]   # ✅ FIXED HERE
        except:
            continue

        rows.append({
            "studio_id": studio_id,
            "hour": dt.hour,
            "day_of_week": dt.weekday()
        })

# ===============================
# CREATE DATAFRAME
# ===============================

df = pd.DataFrame(rows)

print(f"✅ Total bookings fetched: {len(df)}")

if df.empty:
    print("⚠️ No bookings found. Dataset will be empty.")

# ===============================
# SAVE CSV
# ===============================

OUTPUT_PATH = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__),
        "../data/studio_bookings.csv"
    )
)

os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

df.to_csv(OUTPUT_PATH, index=False)

print("✅ Dataset saved successfully")