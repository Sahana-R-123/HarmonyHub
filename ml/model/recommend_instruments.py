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

# Remove unknown instruments
df = df[df["instrument_type"] != "unknown"]

if df.empty:
    print("⚠️ No valid instrument data found. Exiting.")
    exit(0)

# ===============================
# STEP 1: GLOBAL POPULARITY
# ===============================

global_counts = (
    df["instrument_type"]
    .value_counts()
    .reset_index()
)

global_counts.columns = ["instrument_type", "global_count"]
global_counts["global_score"] = (
    global_counts["global_count"] / global_counts["global_count"].sum()
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
    user_counts,
    global_counts[["instrument_type", "global_score"]],
    on="instrument_type",
    how="left"
)

merged["final_score"] = (
    0.7 * merged["user_score"] + 0.3 * merged["global_score"]
)

# ===============================
# STEP 4: TOP-2 PER USER
# ===============================

recommendations = (
    merged
    .sort_values(["user_id", "final_score"], ascending=[True, False])
    .groupby("user_id")
    .head(2)
)

# ===============================
# STEP 5: PUSH TO FIRESTORE
# ===============================

for user_id, group in recommendations.groupby("user_id"):
    db.collection("instrument_recommendations").document(str(user_id)).set({
        "topInstruments": group["instrument_type"].tolist(),
        "updatedAt": firestore.SERVER_TIMESTAMP
    })

print("✅ Instrument recommendations generated & stored successfully")