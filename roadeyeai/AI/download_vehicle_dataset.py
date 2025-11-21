from roboflow import Roboflow
import os
import yaml
import shutil

# ============================================
# CONFIG - APNA API KEY YAHAN DALO
# ============================================

API_KEY = "PtSHbFKVTfBs9rfhab27"  # ← Replace with your Roboflow API key

# Dataset details
WORKSPACE = "vehicle-ojgci"
PROJECT = "indian-vehicle"
VERSION = 1

# ============================================
# DOWNLOAD
# ============================================

print("="*60)
print("📥 DOWNLOADING INDIAN VEHICLE DATASET")
print("="*60)
print(f"Dataset: {PROJECT}")
print(f"Source: https://universe.roboflow.com/{WORKSPACE}/{PROJECT}")
print("="*60 + "\n")

# Check API key
if API_KEY == "YOUR_API_KEY_HERE":
    print("⚠  API KEY NOT SET!\n")
    print("📝 How to get your API key:")
    print("1. Go to: https://app.roboflow.com")
    print("2. Login with Google")
    print("3. Profile Icon → Settings → Roboflow API")
    print("4. Copy 'Private API Key'")
    print("5. Paste it on line 12 of this script\n")
    print("="*60)
    
    proceed = input("\nDo you want to try manual download? (y/n): ").lower()
    if proceed == 'y':
        print("\n📥 MANUAL DOWNLOAD STEPS:")
        print("="*60)
        print("1. Open: https://universe.roboflow.com/vehicle-ojgci/indian-vehicle")
        print("2. Click 'Download Dataset' button")
        print("3. Login with Google (free)")
        print("4. Select format: YOLOv8")
        print("5. Download ZIP file")
        print("6. Extract to folder: 'indian_vehicles'")
        print("7. Run: python train_vehicle_with_auto.py")
        print("="*60)
    exit()

try:
    # Initialize Roboflow
    print("🔐 Authenticating with Roboflow...")
    rf = Roboflow(api_key=API_KEY)
    print("✅ API key validated\n")
    
    # Access project
    print(f"📂 Accessing project: {PROJECT}...")
    project = rf.workspace(WORKSPACE).project(PROJECT)
    print("✅ Project accessed\n")
    
    # Download dataset
    print(f"⬇  Downloading dataset version {VERSION}...")
    print("📦 Size: ~200-300 MB")
    print("⏱  Time: 2-5 minutes\n")
    
    dataset = project.version(VERSION).download("yolov8")
    
    # Move to clean folder name
    target_folder = 'indian_vehicles'
    if os.path.exists(target_folder):
        print(f"🗑  Removing old dataset...")
        shutil.rmtree(target_folder)
    
    print(f"📁 Moving to: {target_folder}/\n")
    shutil.move(dataset.location, target_folder)
    
    print("="*60)
    print("✅ DATASET DOWNLOADED SUCCESSFULLY!")
    print("="*60)
    
    # Show dataset info
    yaml_path = os.path.join(target_folder, 'data.yaml')
    
    print(f"\n📁 Location: {os.path.abspath(target_folder)}/")
    print("\n📂 Folder Structure:")
    print(f"   {target_folder}/")
    print(f"   ├── data.yaml")
    print(f"   ├── train/")
    print(f"   │   ├── images/")
    print(f"   │   └── labels/")
    print(f"   ├── valid/")
    print(f"   │   ├── images/")
    print(f"   │   └── labels/")
    print(f"   └── test/")
    print(f"       ├── images/")
    print(f"       └── labels/")
    
    # Read and display classes
    if os.path.exists(yaml_path):
        with open(yaml_path, 'r') as f:
            data = yaml.safe_load(f)
        
        print("\n📊 Dataset Classes:")
        if 'names' in data:
            classes = data['names']
            for idx, name in classes.items():
                # Categorize for display
                if 'auto' in name.lower() or 'rickshaw' in name.lower():
                    category = " → LMV (Auto-Rickshaw)"
                    emoji = "🛺"
                elif any(x in name.lower() for x in ['car', 'sedan', 'suv']):
                    category = " → LMV"
                    emoji = "🚗"
                elif any(x in name.lower() for x in ['bike', 'motorcycle', 'scooter']):
                    category = " → LMV"
                    emoji = "🏍"
                elif 'bus' in name.lower():
                    category = " → HMV"
                    emoji = "🚌"
                elif 'truck' in name.lower():
                    category = " → HMV"
                    emoji = "🚛"
                else:
                    category = ""
                    emoji = "📦"
                
                print(f"   {emoji} {idx}: {name}{category}")
        
        print(f"\n📝 Total classes: {len(classes)}")
    
    # Count images
    train_images = len([f for f in os.listdir(os.path.join(target_folder, 'train', 'images')) if f.endswith(('.jpg', '.png', '.jpeg'))])
    valid_images = len([f for f in os.listdir(os.path.join(target_folder, 'valid', 'images')) if f.endswith(('.jpg', '.png', '.jpeg'))])
    
    try:
        test_images = len([f for f in os.listdir(os.path.join(target_folder, 'test', 'images')) if f.endswith(('.jpg', '.png', '.jpeg'))])
    except:
        test_images = 0
    
    print(f"\n📈 Dataset Size:")
    print(f"   🎓 Training images: {train_images}")
    print(f"   ✅ Validation images: {valid_images}")
    if test_images > 0:
        print(f"   🧪 Test images: {test_images}")
    print(f"   📊 Total: {train_images + valid_images + test_images}")
    
    print("\n" + "="*60)
    print("✅ DATASET READY FOR TRAINING!")
    print("="*60)
    print("\n🎯 Next Step:")
    print("   python train_vehicle_with_auto.py")
    print("\n⏱  Training will take: 30-90 minutes (GPU)")
    print("="*60)

except Exception as e:
    print(f"\n❌ ERROR: {e}\n")
    print("="*60)
    print("🔧 TROUBLESHOOTING:")
    print("="*60)
    
    if "401" in str(e) or "Unauthorized" in str(e):
        print("\n🔑 API Key Issue:")
        print("   • Your API key is invalid or expired")
        print("   • Get new key: https://app.roboflow.com/settings/api")
        print("   • Update line 12 in this script")
    
    elif "404" in str(e) or "not found" in str(e):
        print("\n📂 Project Not Found:")
        print("   • Check workspace and project names")
        print("   • Verify: https://universe.roboflow.com/vehicle-ojgci/indian-vehicle")
    
    else:
        print(f"\n💥 Unknown Error: {e}")
    
    print("\n📥 ALTERNATIVE: Manual Download")
    print("="*60)
    print("1. Open: https://universe.roboflow.com/vehicle-ojgci/indian-vehicle")
    print("2. Click 'Download Dataset'")
    print("3. Login (Google account - free)")
    print("4. Format: YOLOv8")
    print("5. Download ZIP")
    print("6. Extract to 'indian_vehicles' folder")
    print("7. Run: python train_vehicle_with_auto.py")
    print("="*60)