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
# ==========================
# FETCH BOOKINGS
# ==========================

docs = db.collection("bookings").stream()

rows = []

for doc in docs:

    data = doc.to_dict()

    timestamp = data.get("booking_time")

    if timestamp is None:
        continue

    hour = timestamp.hour
    day = timestamp.weekday()

    rows.append({
        "studio_id": data["studio_id"],
        "hour": hour,
        "day_of_week": day
    })

# ==========================
# SAVE DATASET
# ==========================

df = pd.DataFrame(rows)

output_path = os.path.join(
    os.path.dirname(__file__),
    "studio_bookings.csv"
)

df.to_csv(output_path, index=False)

print("Dataset created successfully")