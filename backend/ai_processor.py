"""
AI Processor Service - FIXED VERSION with Correct Indentation
Processes videos, detects HMVs, reports violations in real-time
"""

import os
import sys
import cv2
import csv
import time
import subprocess
import tempfile
from pathlib import Path
from collections import Counter
import torch
from ultralytics import YOLO
import easyocr
import requests
from datetime import datetime, timezone
import json


class AIProcessor:
    def __init__(
        self,
        vehicle_model_path="yolov8n.pt",
        plate_model_path="plate_model.pt",
    ):
        """Initialize AI models"""
        self.vehicle_model_path = vehicle_model_path
        self.plate_model_path = plate_model_path
        self.vehicle_model = None
        self.plate_model = None
        self.ocr_reader = None
        self.backend_url = os.environ.get("BACKEND_URL", "http://10.121.197.110:5000")

        # Track reported violations to avoid duplicates within same session
        self.reported_violations = set()

        print("🤖 Initializing AI Processor...")
        self._load_models()

    def _load_models(self):
        """Load YOLO and OCR models"""
        try:
            print(f"\n📦 Checking model paths:")
            print(f"Vehicle model: {os.path.abspath(self.vehicle_model_path)}")
            print(f"Plate model: {os.path.abspath(self.plate_model_path)}")

            if not os.path.exists(self.vehicle_model_path):
                raise FileNotFoundError(
                    f"Vehicle model not found: {self.vehicle_model_path}"
                )

            print("🤖 Loading vehicle detection model...")
            self.vehicle_model = YOLO(self.vehicle_model_path)
            print(f"✅ Vehicle model loaded: {type(self.vehicle_model).__name__}")

            if Path(self.plate_model_path).exists():
                print("\n📦 Loading license plate model...")
                self.plate_model = YOLO(self.plate_model_path)
                print(f"✅ Plate model loaded: {type(self.plate_model).__name__}")
            else:
                print(f"\n⚠️ Plate model not found: {self.plate_model_path}")
                self.plate_model = None

            print("\n📦 Loading OCR reader...")
            gpu_available = torch.cuda.is_available()
            print(f"GPU available: {gpu_available}")
            self.ocr_reader = easyocr.Reader(["en"], gpu=gpu_available, verbose=False)
            print("✅ OCR reader initialized")

            print("\n✅ All models loaded successfully!")

        except Exception as e:
            print(f"\n❌ Error loading models: {e}")
            import traceback

            traceback.print_exc()
            raise

    def _get_class_id_sets(self):
        """Get LMV and HMV class IDs from model"""
        class_names = self.vehicle_model.model.names
        normalize = lambda n: str(n).lower().replace(" ", "").strip()

        LMV_CLASSES = {
            "car",
            "motorbike",
            "motorcycle",
            "auto",
            "autorickshaw",
            "scooter",
            "van",
        }
        HMV_CLASSES = {"bus", "truck", "tractor"}

        LMV_IDS = {k for k, v in class_names.items() if normalize(v) in LMV_CLASSES}
        HMV_IDS = {k for k, v in class_names.items() if normalize(v) in HMV_CLASSES}

        print(f"\n🚗 Vehicle classes:")
        print(f"   LMV: {[class_names[i] for i in LMV_IDS]}")
        print(f"   HMV: {[class_names[i] for i in HMV_IDS]}")

        return LMV_IDS, HMV_IDS

    def _clean_plate_text(self, txt):
        """Clean OCR text"""
        if not txt:
            return ""
        cleaned = "".join(ch for ch in txt.upper() if ch.isalnum())
        return cleaned if len(cleaned) >= 4 else ""  # Minimum 4 chars

    def _detect_plate_text(self, crop_img):
        """Detect license plate text from vehicle crop"""
        if self.plate_model is None or self.ocr_reader is None or crop_img.size == 0:
            return ""

        try:
            # Detect plate region
            results = self.plate_model.predict(crop_img, conf=0.3, verbose=False)[0]

            if not hasattr(results, "boxes") or len(results.boxes) == 0:
                return ""

            # Process each detected plate
            for box in results.boxes:
                try:
                    x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
                    plate_img = crop_img[y1:y2, x1:x2]

                    if plate_img.size == 0:
                        continue

                    # Preprocess for better OCR
                    gray_plate = cv2.cvtColor(plate_img, cv2.COLOR_BGR2GRAY)
                    gray_plate = cv2.threshold(
                        gray_plate, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU
                    )[1]

                    # OCR
                    ocr_results = self.ocr_reader.readtext(
                        gray_plate, detail=0, paragraph=False
                    )

                    if ocr_results:
                        plate_text = self._clean_plate_text(ocr_results[0])
                        if plate_text:
                            return plate_text

                except Exception as e:
                    continue
        except Exception:
            pass

        return ""

    def _report_violation_to_backend(self, vehicle_data, camera_location):
        """
        Report HMV violation to backend with session tracking
        Returns: (success: bool, violation_data: dict or None)
        """
        try:
            # Only report HMV
            if vehicle_data["vehicle_type"] != "HMV":
                return False, None

            session_id = camera_location.get("session_id", "")

            # Create unique key to avoid duplicate reports within same session
            violation_key = f"{vehicle_data['number_plate']}_{session_id}"

            # Skip if already reported in this session
            if violation_key in self.reported_violations:
                print(f"   ℹ️ Skipping duplicate: {vehicle_data['number_plate']}")
                return False, None

            # ✅ CRITICAL: Include session_id in payload
            payload = {
                "vehicle_number": vehicle_data["number_plate"],
                "vehicle_type": "HMV",
                "accuracy_percentage": vehicle_data.get("confidence", "unknown"),
                "zone_location": {
                    "lat": camera_location["lat"],
                    "lon": camera_location["lon"],
                },
                "camera_id": camera_location.get("camera_id", "UNKNOWN"),
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "video_path": vehicle_data.get("video_path", "not_provided"),
                "session_id": session_id,  # ← MUST BE HERE!
            }

            # Send to backend
            url = f"{self.backend_url}/vehicle-detected"

            print(f"\n📤 Reporting HMV violation:")
            print(f"   Vehicle: {vehicle_data['number_plate']}")
            print(f"   Session: {session_id}")
            print(f"   URL: {url}")
            print(f"   Payload: {json.dumps(payload, indent=2)}")

            response = requests.post(url, json=payload, timeout=15)

            print(f"📡 Backend response: {response.status_code}")
            print(f"   Response body: {response.text[:200]}")

            if response.status_code == 200:
                result = response.json()
                print(f"   Status: {result.get('status')}")
                print(f"   Message: {result.get('message')}")

                if result.get("status") == "violation":
                    violation_data = result.get("violation_data")
                    violation_id = result.get("violation_id")
                    zone_name = result.get("zone_name")

                    print(f"\n🚨 ========================================")
                    print(f"🚨 VIOLATION CONFIRMED!")
                    print(f"🚨 Vehicle: {vehicle_data['number_plate']}")
                    print(f"🚨 Zone: {zone_name}")
                    print(f"🚨 Violation ID: {violation_id}")
                    print(f"🚨 Distance: {result.get('distance_m')}m from center")
                    print(f"🚨 Session: {session_id}")
                    print(f"🚨 ========================================\n")

                    # Mark as reported
                    self.reported_violations.add(violation_key)

                    return True, violation_data
                else:
                    print(f"   ℹ️ Not in restricted zone or outside radius")
                    return False, None
            else:
                print(f"   ❌ Backend error: {response.text}")
                return False, None

        except requests.exceptions.Timeout:
            print(f"   ⏰ Backend timeout")
            return False, None
        except Exception as e:
            print(f"   ❌ Error reporting violation: {e}")
            import traceback

            traceback.print_exc()
            return False, None

    def process_video(
        self,
        video_source,
        camera_location,
        output_dir="outputs",
        conf_threshold=0.35,
        frame_skip=2,
    ):
        """
        Process video and detect vehicles with REAL-TIME violation reporting

        Args:
            video_source: Video file path
            camera_location: {'lat': float, 'lon': float, 'camera_id': str, 'session_id': str}
            output_dir: Output directory
            conf_threshold: Detection confidence threshold
            frame_skip: Process every nth frame (2 = process every 2nd frame)

        Returns:
            dict with results
        """
        print("\n" + "=" * 80)
        print("🎥 VIDEO PROCESSING STARTED")
        print("=" * 80)
        print(f"📹 Source: {video_source}")
        print(f"📍 Location: ({camera_location['lat']}, {camera_location['lon']})")
        print(f"📸 Camera: {camera_location.get('camera_id', 'UNKNOWN')}")
        print(f"🔑 Session: {camera_location.get('session_id', 'UNKNOWN')}")
        print(f"⚙️ Config: conf={conf_threshold}, skip={frame_skip}")
        print("=" * 80 + "\n")

        os.makedirs(output_dir, exist_ok=True)

        # Reset violation tracking for new session
        session_id = camera_location.get("session_id", "")
        if session_id:
            # Only clear violations for this session
            self.reported_violations = {
                k for k in self.reported_violations if not k.endswith(f"_{session_id}")
            }

        # Open video
        cap = cv2.VideoCapture(video_source)
        if not cap.isOpened():
            print(f"❌ Failed to open video: {video_source}")
            raise Exception(f"Cannot open video: {video_source}")

        # Video properties
        frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = cap.get(cv2.CAP_PROP_FPS) or 25
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        print(f"✅ Video opened successfully")
        print(f"   Resolution: {frame_width}x{frame_height}")
        print(f"   FPS: {fps:.1f}")
        print(f"   Total frames: {total_frames}")
        print(f"   Duration: {total_frames/fps:.1f} seconds\n")

        # Get vehicle classes
        LMV_IDS, HMV_IDS = self._get_class_id_sets()

        # Output video setup
        timestamp = int(time.time())
        output_video_path = os.path.join(output_dir, f"detection_{timestamp}.mp4")
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        out = cv2.VideoWriter(
            output_video_path, fourcc, fps / frame_skip, (frame_width, frame_height)
        )

        # Detection storage
        all_detections = {}  # track_id -> [plate_texts]
        vehicle_types = {}  # track_id -> vehicle_type
        violation_ids = []  # List of violation IDs reported
        violation_data_list = []  # NEW: Store full violation data

        frame_no = 0
        processed_frames = 0
        start_time = time.time()

        print("🔍 Starting frame-by-frame processing...\n")

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame_no += 1

            # Skip frames for performance
            if frame_no % frame_skip != 0:
                continue

            processed_frames += 1

            # Convert grayscale to BGR if needed
            if len(frame.shape) == 2:
                frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)

            display_frame = frame.copy()

            # Run YOLO detection with tracking
            try:
                results = self.vehicle_model.track(
                    frame,
                    persist=True,
                    conf=conf_threshold,
                    verbose=False,
                    iou=0.5,
                    tracker="bytetrack.yaml",
                )[0]
            except:
                results = self.vehicle_model.predict(
                    frame, conf=conf_threshold, verbose=False
                )[0]

            # Process each detection
            if hasattr(results, "boxes") and len(results.boxes) > 0:
                for box in results.boxes:
                    try:
                        # Get track ID
                        track_id = None
                        if hasattr(box, "id") and box.id is not None:
                            track_id = int(box.id[0].item())

                        if track_id is None:
                            continue

                        # Get class ID and confidence
                        cls_id = int(box.cls[0].item())
                        confidence = float(box.conf[0].item())

                        # Only process vehicles (LMV or HMV)
                        if cls_id not in (LMV_IDS | HMV_IDS):
                            continue

                        # Determine vehicle type
                        vehicle_type = "LMV" if cls_id in LMV_IDS else "HMV"

                        # Store vehicle type
                        if track_id not in vehicle_types:
                            vehicle_types[track_id] = vehicle_type
                            print(f"   🚗 New {vehicle_type} detected (ID: {track_id})")

                        # Get bounding box
                        x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())

                        # Crop vehicle region for plate detection
                        crop = frame[y1:y2, x1:x2]

                        # Detect license plate
                        plate_text = self._detect_plate_text(crop)

                        if plate_text:
                            # Store detection
                            all_detections.setdefault(track_id, []).append(plate_text)

                            # Report HMV violations IMMEDIATELY
                            if vehicle_type == "HMV":
                                vehicle_data = {
                                    "number_plate": plate_text,
                                    "vehicle_type": "HMV",
                                    "confidence": f"{confidence*100:.1f}%",
                                    "video_path": output_video_path,
                                }

                                # Report to backend
                                success, vdata = self._report_violation_to_backend(
                                    vehicle_data, camera_location
                                )

                                if success and vdata:
                                    violation_ids.append(vdata.get("id"))
                                    violation_data_list.append(vdata)

                        # Draw bounding box
                        color = (0, 255, 0) if vehicle_type == "LMV" else (0, 0, 255)
                        label = f"{vehicle_type}"
                        if plate_text:
                            label = f"{vehicle_type}: {plate_text}"

                        cv2.rectangle(display_frame, (x1, y1), (x2, y2), color, 2)

                        # Label background
                        (w, h), _ = cv2.getTextSize(
                            label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2
                        )
                        cv2.rectangle(
                            display_frame, (x1, y1 - 25), (x1 + w + 10, y1), color, -1
                        )
                        cv2.putText(
                            display_frame,
                            label,
                            (x1 + 5, y1 - 8),
                            cv2.FONT_HERSHEY_SIMPLEX,
                            0.6,
                            (255, 255, 255),
                            2,
                        )

                    except Exception as e:
                        continue

            # Write annotated frame
            out.write(display_frame)

            # Progress update every 30 frames
            if processed_frames % 30 == 0:
                elapsed = time.time() - start_time
                processing_fps = processed_frames / elapsed if elapsed > 0 else 0
                progress = (frame_no / total_frames * 100) if total_frames > 0 else 0

                sys.stdout.write(
                    f"\r⏳ Frame {frame_no}/{total_frames} ({progress:.1f}%) | "
                    f"FPS: {processing_fps:.1f} | Violations: {len(violation_ids)}"
                )
                sys.stdout.flush()

        # Cleanup
        cap.release()
        out.release()

        elapsed_time = time.time() - start_time

        print(f"\n\n{'='*80}")
        print("✅ PROCESSING COMPLETE!")
        print("=" * 80)
        print(f"⏱️ Total time: {elapsed_time:.1f} seconds")
        print(f"📊 Frames processed: {processed_frames}/{total_frames}")
        print(f"🚗 Total vehicles detected: {len(all_detections)}")
        print(
            f"🚛 HMV vehicles: {sum(1 for v in vehicle_types.values() if v == 'HMV')}"
        )
        print(f"🚨 Violations reported: {len(violation_ids)}")
        print(f"📹 Output video: {output_video_path}")
        print("=" * 80 + "\n")

        # Generate CSV report
        csv_path = os.path.join(output_dir, f"report_{timestamp}.csv")
        with open(csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(
                ["track_id", "vehicle_type", "number_plate", "detections_count"]
            )

            for track_id, plates in all_detections.items():
                if plates:
                    # Most common plate for this vehicle
                    most_common = Counter(plates).most_common(1)[0][0]
                    vehicle_type = vehicle_types.get(track_id, "Unknown")
                    writer.writerow([track_id, vehicle_type, most_common, len(plates)])

        print(f"📄 CSV report saved: {csv_path}\n")

        # Return results with violation data
        return {
            "success": True,
            "output_video": output_video_path,
            "csv_report": csv_path,
            "violations_detected": len(violation_ids),
            "violation_ids": violation_ids,
            "violation_data": violation_data_list,  # NEW: Full violation data
            "total_vehicles": len(all_detections),
            "hmv_detected": sum(1 for v in vehicle_types.values() if v == "HMV"),
            "lmv_detected": sum(1 for v in vehicle_types.values() if v == "LMV"),
            "processing_time": elapsed_time,
            "camera_location": camera_location,
        }

    def process_youtube_video(self, youtube_url, camera_location, output_dir="outputs"):
        """Process YouTube video"""
        print("📺 Processing YouTube video...")

        # Try stream URL first
        stream_url = self._get_youtube_stream_url(youtube_url)

        if stream_url:
            print("✅ Got stream URL, processing...")
            return self.process_video(stream_url, camera_location, output_dir)
        else:
            # Download video
            print("⬇️ Downloading video...")
            temp_file = self._download_youtube_video(youtube_url)

            if temp_file:
                try:
                    return self.process_video(temp_file, camera_location, output_dir)
                finally:
                    # Cleanup
                    try:
                        os.remove(temp_file)
                        print(f"🗑️ Cleaned up: {temp_file}")
                    except:
                        pass
            else:
                raise Exception("Failed to download YouTube video")

    def _get_youtube_stream_url(self, youtube_url):
        """Get YouTube stream URL"""
        try:
            import yt_dlp

            ydl_opts = {
                "format": "best[ext=mp4]/best",
                "quiet": True,
                "no_warnings": True,
            }
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(youtube_url, download=False)
                return info.get("url")
        except Exception as e:
            print(f"⚠️ yt-dlp failed: {e}")
            return None

    def _download_youtube_video(self, youtube_url):
        """Download YouTube video"""
        temp_dir = tempfile.gettempdir()
        output_file = os.path.join(temp_dir, f"youtube_{int(time.time())}.mp4")

        try:
            cmd = [
                sys.executable,
                "-m",
                "yt_dlp",
                "-f",
                "best[ext=mp4]",
                "-o",
                output_file,
                youtube_url,
            ]

            subprocess.run(cmd, check=True, timeout=300)

            if os.path.exists(output_file):
                print(f"✅ Downloaded: {output_file}")
                return output_file
        except Exception as e:
            print(f"❌ Download failed: {e}")

        return None


# Test script
if __name__ == "__main__":
    print("\n" + "=" * 80)
    print("🧪 AI PROCESSOR TEST")
    print("=" * 80 + "\n")

    # Initialize
    try:
        processor = AIProcessor()
    except Exception as e:
        print(f"❌ Failed to initialize: {e}")
        sys.exit(1)

    # Test with sample video
    if len(sys.argv) > 1:
        video_path = sys.argv[1]
    else:
        video_path = input("Enter video path: ").strip()

    if not os.path.exists(video_path):
        print(f"❌ Video not found: {video_path}")
        sys.exit(1)

    # Test camera location (Pune coordinates)
    camera_location = {
        "lat": 18.5204,
        "lon": 73.8567,
        "camera_id": "TEST_CAM_001",
        "session_id": f"test_session_{int(time.time())}",
    }

    # Process
    try:
        result = processor.process_video(
            video_source=video_path, camera_location=camera_location
        )

        print("\n🎉 Test completed successfully!")
        print(f"Results: {result}")

    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback

        traceback.print_exc()
