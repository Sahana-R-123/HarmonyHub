import os
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

# ===============================
# FIREBASE INIT (FILE-BASED, SAFE)
# ===============================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_KEY_PATH = os.path.join(
    os.path.dirname(BASE_DIR),  # ml/
    "..",                       # project root
    "serviceAccountKey.json"
)

SERVICE_KEY_PATH = os.path.abspath(SERVICE_KEY_PATH)

if not os.path.exists(SERVICE_KEY_PATH):
    raise FileNotFoundError(f"Service account key not found at {SERVICE_KEY_PATH}")

if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_KEY_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

# ===============================
# LOAD DATASET
# ===============================

DATA_PATH = os.path.join(
    os.path.dirname(BASE_DIR),
    "data",
    "instrument_history.csv"
)

df = pd.read_csv(DATA_PATH)

# ✅ Normalize instrument names
df["instrument_type"] = df["instrument_type"].str.strip().str.lower()

# ✅ Remove invalid instrument types
df = df[~df["instrument_type"].isin(["unknown", "other"])]

if df.empty:
    print("⚠️ No valid instrument data found. Exiting.")
    exit(0)

# ===============================
# STEP 1: STUDIO POPULARITY
# ===============================

studio_counts = (
    df.groupby(["studio_id", "instrument_type"])
    .size()
    .reset_index(name="studio_count")
)

studio_counts["studio_score"] = studio_counts.groupby("studio_id")["studio_count"].transform(
    lambda x: x / x.sum()
)

# ===============================
# STEP 2: USER HISTORY
# ===============================

user_counts = (
    df.groupby(["user_id", "instrument_type"])
    .size()
    .reset_index(name="user_count")
)

user_counts["user_score"] = user_counts.groupby("user_id")["user_count"].transform(
    lambda x: x / x.sum()
)

# ===============================
# STEP 3: MERGE SCORES
# ===============================

merged = pd.merge(
    df,
    user_counts[["user_id", "instrument_type", "user_score"]],
    on=["user_id", "instrument_type"],
    how="left"
)

merged = pd.merge(
    merged,
    studio_counts[["studio_id", "instrument_type", "studio_score"]],
    on=["studio_id", "instrument_type"],
    how="left"
)

merged["studio_score"] = merged["studio_score"].fillna(0)

merged["final_score"] = (
    0.7 * merged["user_score"] +
    0.3 * merged["studio_score"]
)

# ===============================
# STEP 4: TOP-2 PER USER PER STUDIO
# ===============================

recommendations = (
    merged
    .sort_values(
        ["user_id", "studio_id", "final_score"],
        ascending=[True, True, False]
    )
    .drop_duplicates(["user_id", "studio_id", "instrument_type"])  # ✅ prevent duplicates
    .groupby(["user_id", "studio_id"])
    .head(2)
)

# ===============================
# STEP 5: PUSH TO FIRESTORE (STUDIO-AWARE)
# ===============================

for (user_id, studio_id), group in recommendations.groupby(["user_id", "studio_id"]):

    instruments = group["instrument_type"].tolist()

    db.collection("instrument_recommendations") \
        .document(str(user_id)) \
        .collection("studios") \
        .document(str(studio_id)) \
        .set({
            "topInstruments": instruments,
            "updatedAt": firestore.SERVER_TIMESTAMP
        })

print("✅ Instrument recommendations generated & stored successfully")