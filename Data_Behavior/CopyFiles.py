import os
import shutil

# Base and destination directories
base_dir = "/Volumes/ExtremeSSD2/BBRF_round2/ORIGINAL_analysis"
dest_dir = os.path.join(base_dir, "BehavioralData")

# Ensure destination directory exists
os.makedirs(dest_dir, exist_ok=True)

# Define sessions and conditions
sessions = ['Session1', 'Session2']
conditions = ['A', 'B', 'C', 'D', 'Sham']

# Get list of subject folders starting with "Sub"
subjects = [d for d in os.listdir(base_dir) if d.startswith("Sub") and os.path.isdir(os.path.join(base_dir, d))]

# Loop through subjects, sessions, and conditions
for subj in subjects:
    for i, sess in enumerate(sessions, start=1):
        for cond in conditions:
            filename = f"{subj}_Sess0{i}_{cond}.xlsx"
            source_path = os.path.join(base_dir, subj, sess, "Task", filename)
            dest_path = os.path.join(dest_dir, filename)

            if os.path.exists(source_path):
                shutil.copy2(source_path, dest_path)
                print(f"Copied: {filename}")
            else:
                print(f"Missing: {filename}")
