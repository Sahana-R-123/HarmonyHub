import firebase_admin
from firebase_admin import credentials, firestore
import csv

# 🔑 Load service account key
cred = credentials.Certificate("../serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

studios = db.collection("studios")  # ✅ MISSING LINE FIXED

rows = []

for studio in studios.stream():
    studio_id = studio.id
    bookings_ref = studio.reference.collection("bookings")

    for booking in bookings_ref.stream():
        data = booking.to_dict()

        user_id = data.get("userId")
        if not user_id:
            continue

        selected = data.get("selectedInstruments", [])

        for item in selected:
            instrument_id = item.get("instrumentId")
            if not instrument_id:
                continue

            instrument_ref = (
                studio.reference
                .collection("instruments")
                .document(instrument_id)
                .get()
            )

            if instrument_ref.exists:
                instrument_type = instrument_ref.to_dict().get("type", "unknown")
            else:
                instrument_type = "unknown"

            rows.append([
                user_id,
                studio_id,
                instrument_type
            ])

# 💾 Write CSV
with open("../data/instrument_history.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["user_id", "studio_id", "instrument_type"])
    writer.writerows(rows)

print("✅ Dataset created successfully")