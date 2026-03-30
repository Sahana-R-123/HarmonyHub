import os
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import timezone, timedelta   # ✅ ADDED

# ===============================
# FIREBASE INIT
# ===============================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

SERVICE_KEY_PATH = os.path.abspath(
    os.path.join(BASE_DIR, "../../serviceAccountKey.json")
)

if not os.path.exists(SERVICE_KEY_PATH):
    SERVICE_KEY_PATH = "serviceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_KEY_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

# ===============================
# FETCH BOOKINGS (FIXED ✅)
# ===============================

print("📡 Fetching bookings using collection_group...")

docs = db.collection_group("bookings").stream()

rows = []

# ✅ IST timezone
IST = timezone(timedelta(hours=5, minutes=30))

for doc in docs:
    data = doc.to_dict()

    try:
        studio_id = doc.reference.parent.parent.id
    except:
        continue

    if "startTime" not in data:
        print("❌ Missing startTime")
        continue

    try:
        dt = data["startTime"]

        # ✅ 🔥 CONVERT TO IST (MAIN FIX)
        dt = dt.astimezone(IST)

    except Exception as e:
        print("❌ Timestamp error:", e)
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
    print("⚠️ No bookings found → creating empty dataset")
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

print("✅ Dataset saved successfully")