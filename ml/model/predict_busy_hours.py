import pandas as pd

df = pd.read_csv("ml/data/studio_bookings.csv")

hourly_counts = (
    df.groupby(["studio_id","hour"])
    .size()
    .reset_index(name="booking_count")
)

print(hourly_counts.head())