from roboflow import Roboflow

# Roboflow initialize karo with your API key
rf = Roboflow(api_key="PtSHbFKVTfBs9rfhab27")  # Apna API key yahan paste karo

# Indian License Plate project access karo
project = rf.workspace("indianlicenceplate").project("indianlicenceplate")

# Dataset download karo (YOLOv8 format mein)
dataset = project.version(1).download("yolov8")

print("Dataset downloaded successfully!")
print(f"Dataset location: {dataset.location}")