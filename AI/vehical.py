# download_pretrained_vehicle_model.py
from huggingface_hub import hf_hub_download
import shutil
import os

print("📥 Downloading pretrained Indian vehicle model...")

# Download from Hugging Face
model_path = hf_hub_download(
    repo_id="keremberke/yolov8m-vehicle-detection",
    filename="best.pt"
)

# Copy to your project
os.makedirs('models', exist_ok=True)
shutil.copy(model_path, 'models/vehicle_detection.pt')

print(f"✅ Model downloaded: models/vehicle_detection.pt")
print("\nUpdate main.py:")
print('VEHICLE_MODEL = "models/vehicle_detection.pt"')