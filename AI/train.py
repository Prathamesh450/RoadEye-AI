from ultralytics import YOLO
import os

# ============================================
# CONFIG
# ============================================

DATASET_PATH = 'dataset/data.yaml'
EPOCHS = 50
BATCH_SIZE = 8  # Reduced to avoid memory issues
IMAGE_SIZE = 640

# ============================================
# VALIDATION
# ============================================

if not os.path.exists(DATASET_PATH):
    print(f"❌ ERROR: Dataset not found at {DATASET_PATH}")
    exit()

print(f"✅ Dataset found at: {DATASET_PATH}\n")

# ============================================
# TRAINING
# ============================================

print("="*60)
print("🚀 STARTING TRAINING...")
print("="*60)
print(f"Epochs: {EPOCHS}")
print(f"Batch Size: {BATCH_SIZE}")
print(f"Image Size: {IMAGE_SIZE}")
print(f"Device: GPU (CUDA)")
print("="*60 + "\n")

if __name__ == '__main__':  # IMPORTANT for multiprocessing
    try:
        # Load model
        model = YOLO('yolov8n.pt')
        
        # Train with optimized settings
        results = model.train(
            data=DATASET_PATH,
            epochs=EPOCHS,
            imgsz=IMAGE_SIZE,
            batch=BATCH_SIZE,
            name='indian_license_plate',
            patience=10,
            save=True,
            plots=True,
            device=0,
            workers=4,  # Reduced workers to avoid memory issues
            cache=False,  # Don't cache to save memory
            close_mosaic=10,
            verbose=True
        )
        
        print("\n" + "="*60)
        print("✅ TRAINING COMPLETED SUCCESSFULLY!")
        print("="*60)
        print("\n📁 Model location:")
        print("   runs/detect/indian_license_plate/weights/best.pt")
        print("\n🎯 Next step:")
        print("   python main.py image test.jpg")
        print("   python main.py video test.mp4")
        print("="*60)
        
    except Exception as e:
        print(f"\n❌ Training error: {e}")
    finally:
        # Cleanup
        import torch
        if torch.cuda.is_available():
            torch.cuda.empty_cache()