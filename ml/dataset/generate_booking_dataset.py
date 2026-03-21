import os
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

# ===============================
# FIREBASE INIT (WORKS LOCALLY + GITHUB)
# ===============================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

SERVICE_KEY_PATH = os.path.abspath(
    os.path.join(BASE_DIR, "../../serviceAccountKey.json")
)

# 🔐 GitHub Actions support
if not os.path.exists(SERVICE_KEY_PATH):
    SERVICE_KEY_PATH = "serviceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_KEY_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

# ===============================
# FETCH BOOKINGS FROM FIRESTORE
# ===============================

rows = []

print("📡 Fetching bookings from Firestore...")

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
            timestamp = data["startTime"]

            # 🔥 IMPORTANT FIX: convert Timestamp → datetime
            dt = timestamp.to_datetime()

        except Exception as e:
            print(f"⚠️ Skipping invalid booking: {e}")
            continue

        rows.append({
            "studio_id": studio_id,
            "hour": dt.hour,
            "day_of_week": dt.weekday()
        })

print(f"✅ Total bookings fetched: {len(rows)}")

# ===============================
# CREATE DATAFRAME
# ===============================

if len(rows) == 0:
    print("⚠️ No bookings found. Creating empty dataset with headers.")

    df = pd.DataFrame(columns=["studio_id", "hour", "day_of_week"])

else:
    df = pd.DataFrame(rows)

# ===============================
# SAVE CSV
# ===============================

OUTPUT_PATH = os.path.abspath(
    os.path.join(BASE_DIR, "../data/studio_bookings.csv")
)

os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

df.to_csv(OUTPUT_PATH, index=False)

print(f"✅ Dataset saved at: {OUTPUT_PATH}")
print("✅ Dataset generation completed successfully")