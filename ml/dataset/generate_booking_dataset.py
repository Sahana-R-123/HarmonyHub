import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

# initialize firebase
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

docs = db.collection("bookings").stream()

rows = []

for doc in docs:
    data = doc.to_dict()

    timestamp = data["booking_time"]

    hour = timestamp.hour
    day = timestamp.weekday()

    rows.append({
        "studio_id": data["studio_id"],
        "hour": hour,
        "day_of_week": day
    })

df = pd.DataFrame(rows)

df.to_csv("ml/data/studio_bookings.csv", index=False)

print("Dataset created")