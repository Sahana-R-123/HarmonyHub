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
# FETCH BOOKINGS (FIXED ✅)
# ===============================

docs = db.collection_group("bookings").stream()

rows = []

for doc in docs:
    data = doc.to_dict()

    # Get studioId from path
    studio_id = doc.reference.parent.parent.id

    start_time = data.get("startTime")

    if not start_time:
        continue

    dt = start_time.to_datetime()

    rows.append({
        "studio_id": studio_id,
        "hour": dt.hour,
        "day_of_week": dt.weekday()
    })

# ===============================
# SAVE DATASET
# ===============================

df = pd.DataFrame(rows)

if df.empty:
    print("⚠️ No booking data found")
else:
    SAVE_PATH = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            "../data/studio_bookings.csv"
        )
    )

    os.makedirs(os.path.dirname(SAVE_PATH), exist_ok=True)

    df.to_csv(SAVE_PATH, index=False)
    print("✅ Dataset created:", SAVE_PATH)