from ultralytics import YOLO
import os
import yaml
import shutil
import torch

# ============================================
# GPU MEMORY & ENVIRONMENT FIXES (NEW ✅)
# ============================================

# Prevent CUDA fragmentation
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

# Clear any leftover GPU cache
torch.cuda.empty_cache()

# ============================================
# CONFIG
# ============================================

DATASET_PATH = "Indian-Vehicles/data.yaml"
MODEL_NAME = "yolov8n.pt"  # Use yolov8s.pt for slightly better accuracy
EPOCHS = 100
BATCH_SIZE = 4              # 🔽 Reduced from 16 to 4 (fits 8GB GPU)
IMAGE_SIZE = 512            # 🔽 Kept moderate, works well on 8GB GPUs
PROJECT_NAME = "indian_vehicles_auto"

print("=" * 60)
print("🚗 TRAINING: INDIAN VEHICLE DETECTION MODEL")
print("=" * 60)
print(f"Dataset: indian-vehicle (vehicle-ojgci)")
print(f"Base Model: {MODEL_NAME}")
print(f"Epochs: {EPOCHS}")
print(f"Batch Size: {BATCH_SIZE}")
print("=" * 60 + "\n")

# ============================================
# VALIDATION
# ============================================

if not os.path.exists(DATASET_PATH):
    print("❌ Dataset not found!")
    print(f"Expected location: {DATASET_PATH}\n")
    print("Run first: python download_indian_dataset.py")
    exit()

print(f"✅ Dataset found: {DATASET_PATH}\n")

# Check GPU
if torch.cuda.is_available():
    device = 0
    gpu_name = torch.cuda.get_device_name(0)
    total_mem = torch.cuda.get_device_properties(0).total_memory / 1024**3
    print(f"🎮 GPU detected: {gpu_name}")
    print(f"💾 GPU Memory: {total_mem:.1f} GB\n")

    if total_mem <= 8:
        print("⚙️ Adjusting settings for 8GB GPU (optimized memory mode)...")
        BATCH_SIZE = 4
        IMAGE_SIZE = 512
else:
    device = "cpu"
    print("⚠  No GPU detected - using CPU")
    print("⏱  Training will be slower (2-4 hours)\n")
    BATCH_SIZE = 2  # Reduce batch size for CPU

# ============================================
# SHOW DATASET INFO
# ============================================

print("📊 Dataset Information:")
print("=" * 60)

with open(DATASET_PATH, "r") as f:
    data = yaml.safe_load(f)

if "names" in data:
    classes = data["names"]
    print(f"Total Classes: {len(classes)}\n")

    lmv_classes, hmv_classes, auto_classes = [], [], []

    for idx, name in enumerate(classes):
        print(f"{idx}: {name}")
        name_lower = name.lower()
        if "auto" in name_lower or "rickshaw" in name_lower:
            auto_classes.append(f"{idx}:{name}")
        elif any(x in name_lower for x in ["car", "bike", "motorcycle", "scooter", "bicycle"]):
            lmv_classes.append(f"{idx}:{name}")
        elif any(x in name_lower for x in ["bus", "truck", "lorry"]):
            hmv_classes.append(f"{idx}:{name}")

    if auto_classes:
        print("🛺 Auto-Rickshaw Classes (→ LMV):")
        for cls in auto_classes:
            print(f"   {cls}")

    if lmv_classes:
        print("\n🚗 LMV Classes:")
        for cls in lmv_classes[:5]:
            print(f"   {cls}")
        if len(lmv_classes) > 5:
            print(f"   ... and {len(lmv_classes)-5} more")

    if hmv_classes:
        print("\n🚛 HMV Classes:")
        for cls in hmv_classes:
            print(f"   {cls}")

print("\n" + "=" * 60)

# ============================================
# TRAINING
# ============================================

print("\n🚀 STARTING TRAINING...")
print("=" * 60)
print("⏱  Estimated time:")
if device == 0:
    print("   • GPU: 30–90 minutes")
else:
    print("   • CPU: 2–4 hours")
print("\n💾 Model will auto-save every epoch")
print("📊 Training plots will be generated")
print("⚡ Press Ctrl+C to stop training")
print("=" * 60 + "\n")

if __name__ == "__main__":
    try:
        # Load base model
        print(f"📦 Loading base model: {MODEL_NAME}...")
        model = YOLO(MODEL_NAME)
        print("✅ Model loaded\n")

        # Start training
        print("🎓 Training started...\n")

        results = model.train(
            data=DATASET_PATH,
            epochs=EPOCHS,
            imgsz=IMAGE_SIZE,
            batch=BATCH_SIZE,
            name=PROJECT_NAME,
            patience=20,
            save=True,
            save_period=10,
            plots=True,
            device=device,
            workers=2,           # 🔽 Fewer workers = less memory
            cache=False,
            amp=True,            # ✅ Mixed precision (FP16)
            half=True,           # ✅ Force half-precision
            optimizer="auto",
            close_mosaic=10,
            hsv_h=0.015,
            hsv_s=0.7,
            hsv_v=0.4,
            degrees=10.0,
            translate=0.1,
            scale=0.5,
            shear=0.0,
            perspective=0.0,
            flipud=0.0,
            fliplr=0.5,
            mosaic=1.0,
            mixup=0.0,
            copy_paste=0.0,
        )

        print("\n" + "=" * 60)
        print("✅ TRAINING COMPLETED!")
        print("=" * 60)

        best_model = f"runs/detect/{PROJECT_NAME}/weights/best.pt"
        last_model = f"runs/detect/{PROJECT_NAME}/weights/last.pt"

        if os.path.exists(best_model):
            shutil.copy(best_model, "vehicle_model.pt")

            print("\n📁 Model Locations:")
            print(f"   1. {best_model}")
            print(f"   2. vehicle_model.pt (easy access)")

            print("\n📊 Training Results:")
            print(f"   • Results: runs/detect/{PROJECT_NAME}/results.png")
            print(f"   • Confusion Matrix: runs/detect/{PROJECT_NAME}/confusion_matrix.png")
            print(f"   • F1 Curve: runs/detect/{PROJECT_NAME}/F1_curve.png")
            print(f"   • PR Curve: runs/detect/{PROJECT_NAME}/PR_curve.png")

        print("\n🎯 NEXT STEPS:")
        print("=" * 60)
        print("1. Test model:")
        print("   python test_vehicle_model.py")
        print("\n2. Update main.py (line 11):")
        print("   VEHICLE_MODEL = 'vehicle_model.pt'")
        print("\n3. Run detection:")
        print("   python main.py image test_auto.jpg")
        print("=" * 60)

    except KeyboardInterrupt:
        print("\n\n⚠  Training interrupted by user")
        print("💾 Partial model saved in: runs/detect/")

    except Exception as e:
        print(f"\n❌ Training failed: {e}")
        import traceback
        traceback.print_exc()

    finally:
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            print("\n🧹 GPU memory cleared")
