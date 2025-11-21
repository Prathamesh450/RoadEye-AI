from ultralytics import YOLO
import os

# ============================================
# CONFIG
# ============================================
DATASET_PATH = 'vehicle_dataset/data.yaml'  # Your vehicle dataset
EPOCHS = 100
BATCH_SIZE = 16
IMAGE_SIZE = 640

# ============================================
# CHECK DATASET
# ============================================
if not os.path.exists(DATASET_PATH):
    print(f"❌ Vehicle dataset not found!")
    print("\nDownload from:")
    print("https://universe.roboflow.com (search: indian vehicles auto)")
    exit()

print(f"✅ Dataset found: {DATASET_PATH}\n")

# ============================================
# TRAINING
# ============================================
print("="*60)
print("🚗 TRAINING VEHICLE DETECTION MODEL")
print("   (Including Auto-Rickshaw)")
print("="*60)
print(f"Epochs: {EPOCHS}")
print(f"Batch Size: {BATCH_SIZE}")
print(f"Classes: LMV, HMV, AUTO")
print("="*60 + "\n")

if __name__ == '_main_':
    try:
        # Load pretrained YOLOv8
        model = YOLO('yolov8n.pt')
        
        # Train on Indian vehicles
        results = model.train(
            data=DATASET_PATH,
            epochs=EPOCHS,
            imgsz=IMAGE_SIZE,
            batch=BATCH_SIZE,
            name='indian_vehicle_detection',
            patience=20,
            save=True,
            plots=True,
            device=0,
            workers=4,
            cache=False
        )
        
        print("\n" + "="*60)
        print("✅ VEHICLE MODEL TRAINED!")
        print("="*60)
        print("\n📁 Model saved at:")
        print("   runs/detect/indian_vehicle_detection/weights/best.pt")
        print("\n🎯 Update main.py:")
        print('   VEHICLE_MODEL = "runs/detect/indian_vehicle_detection/weights/best.pt"')
        print("="*60)
        
    except Exception as e:
        print(f"\n❌ Error: {e}")