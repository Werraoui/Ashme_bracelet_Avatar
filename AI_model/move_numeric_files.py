import os
import shutil

source_folder = r"C:\Users\wiame\Desktop\Ashtme_project\bidmc_csv"
destination_folder = r"C:\Users\wiame\Desktop\Ashtme_project\data"

# create destination folder if it doesn't exist
os.makedirs(destination_folder, exist_ok=True)

for file in os.listdir(source_folder):
    if file.endswith("_Numerics.csv"):
        src_path = os.path.join(source_folder, file)
        dst_path = os.path.join(destination_folder, file)
        shutil.copy(src_path, dst_path)

print("Done: Only Numerics files copied ")