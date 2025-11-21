from ultralytics import YOLO
import cv2
import os

print("="*60)
print("🧪 TESTING VEHICLE DETECTION MODEL")
print("="*60 + "\n")

# Find model
model_paths = [
    'vehicle_model.pt',
    'runs/detect/indian_vehicles_auto4/weights/best.pt',
]

model_path = None
for path in model_paths:
    if os.path.exists(path):
        model_path = path
        print(f"✅ Found model: {path}")
        break

if not model_path:
    print("❌ Model not found!")
    print("\nTrain first:")
    print("   python train_vehicle_with_auto.py")
    exit()

# Load model
print("📦 Loading model...\n")
model = YOLO(model_path)

# Show classes
print("📊 Model can detect these vehicles:")
print("="*60)

classes = model.names
lmv = []
hmv = []
auto = []

for idx, name in classes.items():
    name_lower = name.lower()
    if 'auto' in name_lower or 'rickshaw' in name_lower:
        auto.append(f"{idx}: {name}")
    elif any(x in name_lower for x in ['car', 'bike', 'motorcycle', 'scooter']):
        lmv.append(f"{idx}: {name}")
    elif any(x in name_lower for x in ['bus', 'truck']):
        hmv.append(f"{idx}: {name}")

if auto:
    print("\n🛺 AUTO-RICKSHAW (LMV):")
    for cls in auto:
        print(f"   {cls}")

if lmv:
    print("\n🚗 LMV:")
    for cls in lmv:
        print(f"   {cls}")

if hmv:
    print("\n🚛 HMV:")
    for cls in hmv:
        print(f"   {cls}")

print("\n" + "="*60)

# Test on image
test_image = input("\n📷 Enter test image path (or press Enter to skip): ").strip()

if test_image and os.path.exists(test_image):
    print(f"\n🔍 Processing: {test_image}\n")
    
    # Run detection
    results = model(test_image, conf=0.3)
    
    print("📋 Detections:")
    print("="*60)
    
    detection_count = 0
    for r in results:
        for box in r.boxes:
            cls_id = int(box.cls[0])
            cls_name = model.names[cls_id]
            conf = float(box.conf[0])
            
            # Categorize
            name_lower = cls_name.lower()
            if 'auto' in name_lower or 'rickshaw' in name_lower:
                vehicle_type = "LMV (Auto-Rickshaw)"
                emoji = "🛺"
            elif any(x in name_lower for x in ['car', 'bike', 'motorcycle', 'scooter']):
                vehicle_type = "LMV"
                emoji = "🚗"
            elif any(x in name_lower for x in ['bus', 'truck']):
                vehicle_type = "HMV"
                emoji = "🚛"
            else:
                vehicle_type = "Unknown"
                emoji = "❓"
            
            detection_count += 1
            print(f"{emoji} {cls_name} → {vehicle_type} (conf: {conf:.2f})")
    
    if detection_count == 0:
        print("⚠  No vehicles detected")
        print("   Try lowering confidence threshold")
    
    print("\n" + "="*60)
    
    # Show result
    results[0].show()
    
    # Save result
    output_path = 'test_output.jpg'
    annotated = results[0].plot()
    cv2.imwrite(output_path, annotated)
    print(f"\n💾 Result saved: {output_path}")
    
elif test_image:
    print(f"\n❌ Image not found: {test_image}")

print("\n" + "="*60)
print("✅ TEST COMPLETE!")
print("="*60)
print("\n🎯 If results look good:")
print("   1. Update main.py line 11:")
print("      VEHICLE_MODEL = 'vehicle_model.pt'")
print("   2. Run detection:")
print("      python main.py image your_image.jpg")
print("="*60)