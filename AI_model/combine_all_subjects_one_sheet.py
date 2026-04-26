import os
import pandas as pd

source_folder = r"C:\Users\wiame\Desktop\Ashtme_project\bidmc_csv"
output_file = r"C:\Users\wiame\Desktop\Ashtme_project\all_numerics_combined.csv"

all_data = []  # list to store each subject's data

for file in os.listdir(source_folder):
    if file.endswith("_Numerics.csv"):
        df = pd.read_csv(os.path.join(source_folder, file))
        # add a column for subject ID (optional)
        subject_id = file.split("_")[1]  # e.g., "01" from "bidmc_01_Numerics.csv"
        df["subject_id"] = subject_id
        all_data.append(df)

# combine all subjects into a single dataframe
combined_df = pd.concat(all_data, ignore_index=True)

# save to CSV
combined_df.to_csv(output_file, index=False)
print("All Numerics CSV files combined into one ✅")