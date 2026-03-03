import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

# 🔑 Firebase init
cred = credentials.Certificate("../serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

# 📥 Load dataset
df = pd.read_csv("../data/instrument_history.csv")

# ❌ Remove unknown instruments (optional but recommended)
df = df[df["instrument_type"] != "unknown"]

# ===============================
# STEP 1: GLOBAL POPULARITY
# ===============================
global_counts = (
    df["instrument_type"]
    .value_counts()
    .reset_index()
)
global_counts.columns = ["instrument_type", "global_count"]

# Normalize
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

# Normalize per user
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

# Weighted score
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
    recs = group["instrument_type"].tolist()

    db.collection("instrument_recommendations").document(user_id).set({
        "topInstruments": recs
    })

print("✅ Instrument recommendations generated & stored")