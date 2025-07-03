import os

# Path to the destination directory
dest_dir = "/Volumes/ExtremeSSD2/BBRF_round2/ORIGINAL_analysis/BehavioralData"

# Loop through all visible (non-dot) files in the directory
for filename in os.listdir(dest_dir):
    # Skip hidden/system files like .DS_Store or ._resource files
    if filename.startswith("._") or filename.startswith(".") or not filename.endswith(".xlsx"):
        continue

    # Rename if 'Sess' is in the filename
    if "Sess" in filename:
        new_filename = filename.replace("Sess", "Session")
        src = os.path.join(dest_dir, filename)
        dst = os.path.join(dest_dir, new_filename)
        if not os.path.exists(src):
            print(f"Skipping missing: {src}")
            continue
        os.rename(src, dst)
        print(f"Renamed: {filename} -> {new_filename}")
