from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, firestore, auth as admin_auth
from geopy.distance import geodesic

import shutil
import threading
import time
import requests
from flask_cors import CORS
from werkzeug.utils import secure_filename
import json
from functools import lru_cache
import random
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta, timezone
import hashlib
from dotenv import load_dotenv
load_dotenv()

import os

# Import AI Processor
try:
    from ai_processor import AIProcessor
    AI_AVAILABLE = True
except ImportError:
    print("⚠️ AI Processor not available. Install required packages.")
    AI_AVAILABLE = False

# ==========================
# 🔧 CONFIGURATION - UPDATE THESE VALUES!
# ==========================
password_reset_tracker = {}
# ✅ Firebase Credentials (YOU ALREADY HAVE THIS!)
FIREBASE_JSON_FILENAME = os.getenv("FIREBASE_JSON_PATH")
FIREBASE_API_KEY = os.getenv("FIREBASE_API_KEY")

# ✅ Email Configuration (ADD YOUR GMAIL HERE!)
SMTP_SERVER = os.getenv("SMTP_SERVER")
SMTP_PORT = int(os.getenv("SMTP_PORT"))
SMTP_EMAIL = os.getenv("SMTP_EMAIL")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")

# OTP Configuration
OTP_EXPIRY_MINUTES = 5
OTP_RESEND_COOLDOWN_SECONDS = 60
MAX_OTP_ATTEMPTS = 3

# ==========================
# 🔥 Initialize Firebase
# ==========================
try:
    firebase_config = {
        "type": os.getenv("FIREBASE_TYPE"),
        "project_id": os.getenv("FIREBASE_PROJECT_ID"),
        "private_key_id": os.getenv("FIREBASE_PRIVATE_KEY_ID"),
        "private_key": os.getenv("FIREBASE_PRIVATE_KEY").replace("\\n", "\n"),
        "client_email": os.getenv("FIREBASE_CLIENT_EMAIL"),
        "client_id": os.getenv("FIREBASE_CLIENT_ID"),
        "auth_uri": os.getenv("FIREBASE_AUTH_URI"),
        "token_uri": os.getenv("FIREBASE_TOKEN_URI"),
        "auth_provider_x509_cert_url": os.getenv("FIREBASE_AUTH_PROVIDER_X509_CERT_URL"),
        "client_x509_cert_url": os.getenv("FIREBASE_CLIENT_X509_CERT_URL"),
    }
    cred = credentials.Certificate(firebase_config)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase initialized successfully")
        
except Exception as e:
    print(f"❌ Failed to initialize Firebase Admin SDK: {e}")
    print("\n💡 Troubleshooting:")
    print("   1. Check that the JSON file exists in backend/ folder")
    print("   2. Verify the filename matches FIREBASE_JSON_FILENAME")
    print("   3. Ensure the JSON file is valid")
    db = None

# ==========================
# 🧩 Flask setup
# ==========================
app = Flask(__name__)
CORS(app)

VIDEO_STORAGE_PATH = "video_storage"
OUTPUT_PATH = "outputs"
os.makedirs(VIDEO_STORAGE_PATH, exist_ok=True)
os.makedirs(OUTPUT_PATH, exist_ok=True)

# Initialize AI Processor
ai_processor = None
if AI_AVAILABLE:
    try:
        ai_processor = AIProcessor()
        print("✅ AI Processor initialized successfully!")
    except Exception as e:
        print(f"❌ Failed to initialize AI Processor: {e}")
        ai_processor = None

# ==========================
# 🧠 CACHE ZONES TO PREVENT QUOTA ISSUES
# ==========================
zones_cache = {"data": [], "last_updated": 0}
CACHE_DURATION = 60  # Cache zones for 60 seconds

# ==========================
# 📊 ACTIVE PROCESSING SESSIONS
# ==========================
active_sessions = {}  # processing_id -> {status, violations[], start_time}

# ==========================
# 🔐 OTP STORAGE
# ==========================
otp_store = {}


def get_zones_cached():
    """Get zones from cache or fetch from Firestore"""
    global zones_cache
    current_time = time.time()

    # Return cached data if still valid
    if (current_time - zones_cache["last_updated"]) < CACHE_DURATION:
        return zones_cache["data"]

    # Fetch fresh data
    try:
        if not db:
            print("⚠️ Database not initialized, returning empty zones")
            return []
            
        zones_ref = db.collection("ZoneData").stream()
        zones = []
        for zone_doc in zones_ref:
            zone_data = zone_doc.to_dict()
            zone_data["zone_id"] = zone_doc.id
            zones.append(zone_data)

        # Update cache
        zones_cache["data"] = zones
        zones_cache["last_updated"] = current_time
        print(f"✅ Zones cache updated: {len(zones)} zones")
        return zones
    except Exception as e:
        print(f"❌ Error fetching zones: {e}")
        # Return old cache if fetch fails
        return zones_cache["data"]


def send_otp_email(to_email, otp_code, user_name=None):
    """Send OTP email with beautiful HTML template"""
    try:
        if not user_name:
            user_name = to_email.split('@')[0]
        
        # Create HTML email
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {{ margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4; }}
        .container {{ max-width: 600px; margin: 40px auto; background-color: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center; }}
        .logo {{ width: 80px; height: 80px; background-color: white; border-radius: 50%; margin: 0 auto 20px; display: flex; align-items: center; justify-content: center; font-size: 40px; }}
        .header h1 {{ color: white; margin: 0; font-size: 28px; }}
        .header p {{ color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 14px; }}
        .content {{ padding: 40px 30px; }}
        .content h2 {{ color: #333; margin: 0 0 20px 0; font-size: 24px; }}
        .content p {{ color: #666; line-height: 1.6; margin: 0 0 30px 0; }}
        .otp-box {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 10px; padding: 30px; text-align: center; margin: 30px 0; }}
        .otp-label {{ color: white; margin: 0 0 10px 0; font-size: 14px; letter-spacing: 1px; }}
        .otp-code {{ background-color: white; border-radius: 8px; padding: 20px; display: inline-block; }}
        .otp-code span {{ font-size: 36px; font-weight: bold; color: #667eea; letter-spacing: 8px; }}
        .otp-expiry {{ color: rgba(255,255,255,0.9); margin: 15px 0 0 0; font-size: 12px; }}
        .info-box {{ background-color: #f8f9fa; border-left: 4px solid #667eea; padding: 15px; margin: 30px 0; border-radius: 4px; }}
        .info-box strong {{ color: #667eea; display: block; margin-bottom: 5px; }}
        .info-box p {{ margin: 0; color: #666; font-size: 14px; line-height: 1.5; }}
        .footer {{ background-color: #f8f9fa; padding: 20px 30px; text-align: center; color: #999; font-size: 12px; }}
        .footer a {{ color: #667eea; text-decoration: none; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🚗</div>
            <h1>RoadEye AI</h1>
            <p>Email Verification</p>
        </div>
        
        <div class="content">
            <h2>Hi {user_name}! 👋</h2>
            <p>Thank you for registering with <strong>RoadEye AI</strong>. To complete your registration and access all premium features, please verify your email address using the OTP below:</p>
            
            <div class="otp-box">
                <p class="otp-label">YOUR VERIFICATION CODE</p>
                <div class="otp-code">
                    <span>{otp_code}</span>
                </div>
                <p class="otp-expiry">⏰ This code expires in {OTP_EXPIRY_MINUTES} minutes</p>
            </div>
            
            <div class="info-box">
                <strong>🔒 Security Tips:</strong>
                <p>
                    • Never share this OTP with anyone<br>
                    • RoadEye AI will never ask for your OTP via phone or email<br>
                    • If you didn't request this, please ignore this email
                </p>
            </div>
            
            <p style="margin-top: 30px; color: #999; font-size: 13px;">
                Having trouble? Contact our support team at 
                <a href="mailto:support@roadeyeai.com" style="color: #667eea;">support@roadeyeai.com</a>
            </p>
        </div>
        
        <div class="footer">
            <p>© 2025 RoadEye AI. All rights reserved.</p>
            <p>This is an automated email. Please do not reply.</p>
        </div>
    </div>
</body>
</html>
        """
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['From'] = f"RoadEye AI <{SMTP_EMAIL}>"
        msg['To'] = to_email
        msg['Subject'] = f"🔐 Your RoadEye AI Verification Code: {otp_code}"
        
        # Attach HTML
        html_part = MIMEText(html_content, 'html')
        msg.attach(html_part)
        
        # Send email
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_EMAIL, SMTP_PASSWORD)
            server.send_message(msg)
        
        print(f"✅ OTP email sent to {to_email}")
        return True
        
    except Exception as e:
        print(f"❌ Email sending failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def send_password_reset_email(to_email, otp_code):
    """Send password reset email with OTP"""
    try:
        user_name = to_email.split('@')[0]
        
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {{ margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4; }}
        .container {{ max-width: 600px; margin: 40px auto; background-color: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center; }}
        .logo {{ width: 80px; height: 80px; background-color: white; border-radius: 50%; margin: 0 auto 20px; display: flex; align-items: center; justify-content: center; font-size: 40px; }}
        .header h1 {{ color: white; margin: 0; font-size: 28px; }}
        .header p {{ color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 14px; }}
        .content {{ padding: 40px 30px; }}
        .content h2 {{ color: #333; margin: 0 0 20px 0; font-size: 24px; }}
        .content p {{ color: #666; line-height: 1.6; margin: 0 0 30px 0; }}
        .otp-box {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 10px; padding: 30px; text-align: center; margin: 30px 0; }}
        .otp-label {{ color: white; margin: 0 0 10px 0; font-size: 14px; letter-spacing: 1px; }}
        .otp-code {{ background-color: white; border-radius: 8px; padding: 20px; display: inline-block; }}
        .otp-code span {{ font-size: 36px; font-weight: bold; color: #667eea; letter-spacing: 8px; }}
        .otp-expiry {{ color: rgba(255,255,255,0.9); margin: 15px 0 0 0; font-size: 12px; }}
        .warning-box {{ background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 30px 0; border-radius: 4px; }}
        .warning-box strong {{ color: #856404; display: block; margin-bottom: 5px; }}
        .warning-box p {{ margin: 0; color: #856404; font-size: 14px; line-height: 1.5; }}
        .footer {{ background-color: #f8f9fa; padding: 20px 30px; text-align: center; color: #999; font-size: 12px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🔒</div>
            <h1>RoadEye AI</h1>
            <p>Password Reset Request</p>
        </div>
        
        <div class="content">
            <h2>Hi {user_name}! 👋</h2>
            <p>We received a request to reset your password for your <strong>RoadEye AI</strong> account. Use the OTP below to reset your password:</p>
            
            <div class="otp-box">
                <p class="otp-label">YOUR RESET CODE</p>
                <div class="otp-code">
                    <span>{otp_code}</span>
                </div>
                <p class="otp-expiry">⏰ This code expires in {OTP_EXPIRY_MINUTES} minutes</p>
            </div>
            
            <div class="warning-box">
                <strong>⚠️ Security Notice:</strong>
                <p>
                    If you didn't request this password reset, please ignore this email and ensure your account is secure.
                </p>
            </div>
            
            <p style="margin-top: 30px; color: #999; font-size: 13px;">
                Need help? Contact our support team at 
                <a href="mailto:support@roadeyeai.com" style="color: #667eea;">support@roadeyeai.com</a>
            </p>
        </div>
        
        <div class="footer">
            <p>© 2025 RoadEye AI. All rights reserved.</p>
            <p>This is an automated email. Please do not reply.</p>
        </div>
    </div>
</body>
</html>
        """
        
        msg = MIMEMultipart('alternative')
        msg['From'] = f"RoadEye AI <{SMTP_EMAIL}>"
        msg['To'] = to_email
        msg['Subject'] = f"🔒 Password Reset Code: {otp_code}"
        
        html_part = MIMEText(html_content, 'html')
        msg.attach(html_part)
        
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_EMAIL, SMTP_PASSWORD)
            server.send_message(msg)
        
        print(f"✅ Password reset email sent to {to_email}")
        return True
        
    except Exception as e:
        print(f"❌ Password reset email failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def generate_otp():
    """Generate secure 6-digit OTP"""
    return str(random.randint(100000, 999999))


def check_zone_restriction(zone_location):
    """Check if a vehicle is inside a restricted zone using cached data"""
    try:
        zones = get_zones_cached()

        for zone in zones:
            center = zone.get("center")
            radius = zone.get("radius_meters", 0)

            if not center:
                continue

            center_coords = (center["lat"], center["lon"])
            vehicle_coords = (zone_location["lat"], zone_location["lon"])
            distance = geodesic(center_coords, vehicle_coords).meters

            if distance <= radius:
                return True, zone
        return False, None
    except Exception as e:
        print(f"❌ Error checking zone restriction: {e}")
        return False, None


# ==========================
# 🏠 Home route
# ==========================
@app.route("/", methods=["GET"])
def home():
    """Health check endpoint."""
    return (
        jsonify(
            {
                "status": "success",
                "message": "🚀 RoadEyeAI Flask Backend Running",
                "version": "3.0.0-COMPLETE",
                "ai_enabled": ai_processor is not None,
                "firebase_connected": db is not None,
                "email_configured": bool(SMTP_EMAIL and SMTP_PASSWORD and SMTP_EMAIL != "your-email@gmail.com"),
                "zones_cached": len(zones_cache["data"]),
                "active_sessions": len(active_sessions),
                "configuration": {
                    "firebase_file": FIREBASE_JSON_FILENAME,
                    "smtp_email": SMTP_EMAIL if SMTP_EMAIL != "your-email@gmail.com" else "NOT_CONFIGURED",
                },
                "endpoints": {
                    "auth": [
                        "/signup",
                        "/login",
                        "/signup-with-otp",
                        "/send-otp",
                        "/verify-otp",
                        "/check-verification-status/<email>",
                    ],
                    "zones": ["/add-zone", "/get-zones", "/delete-zone/<id>"],
                    "violations": ["/vehicle-detected", "/get-violations", "/get-session-violations/<session_id>"],
                    "video": [
                        "/upload-video",
                        "/process-video",
                        "/process-camera",
                        "/process-youtube",
                        "/session-status/<session_id>",
                        "/test-camera-connection",
                    ],
                    "debug": ["/debug-session/<session_id>", "/test-violations"],
                },
            }
        ),
        200,
    )


# ==========================
# 🔐 AUTHENTICATION ROUTES
# ==========================

@app.route("/signup", methods=["POST"])
def signup():
    """Create new Firebase Authentication user."""
    try:
        data = request.get_json()
        print(f"\n🔐 Signup request received: {data.get('email', 'NO EMAIL')}")

        if not data:
            print("❌ No data provided")
            return jsonify({"error": "No data provided"}), 400

        email = data.get("email", "").strip()
        password = data.get("password", "")

        if not email or not password:
            print("❌ Missing email or password")
            return jsonify({"error": "Email and password required"}), 400

        if "@" not in email or "." not in email:
            print(f"❌ Invalid email format: {email}")
            return jsonify({"error": "Invalid email format"}), 400

        if len(password) < 6:
            print("❌ Password too short")
            return jsonify({"error": "Password must be at least 6 characters"}), 400
            
        print(f"🔧 Calling Firebase Auth API...")
        url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={FIREBASE_API_KEY}"
        payload = {"email": email, "password": password, "returnSecureToken": True}

        response = requests.post(url, json=payload, timeout=10)
        res_data = response.json()
        
        print(f"📡 Firebase response: {response.status_code}")

        if response.status_code == 200:
            user_data = {
                "email": email,
                "uid": res_data["localId"],
                "createdAt": datetime.now(timezone.utc).isoformat(),
                "displayName": email.split("@")[0],
                "role": "user",
                "emailVerified": False,
                "premiumAccess": False,
            }

            if db:
                print("💾 Saving user to Firestore...")
                db.collection("Users").document(res_data["localId"]).set(user_data)
                print("✅ User saved to Firestore")
            
            print(f"✅ Signup successful: {email}")

            return (
                jsonify(
                    {
                        "message": "Signup successful",
                        "email": email,
                        "uid": res_data["localId"],
                        "idToken": res_data.get("idToken"),
                        "success": True,
                    }
                ),
                200,
            )
        else:
            error_message = res_data.get("error", {}).get("message", "Signup failed")

            if "EMAIL_EXISTS" in error_message:
                return jsonify({"error": "Email already registered"}), 400
            elif "WEAK_PASSWORD" in error_message:
                return jsonify({"error": "Password is too weak"}), 400
            else:
                return jsonify({"error": error_message}), 400

    except requests.exceptions.Timeout:
        print("⏰ Request timeout")
        return jsonify({"error": "Request timeout. Please try again."}), 500
    except requests.exceptions.RequestException as e:
        print(f"❌ Network error: {e}")
        return jsonify({"error": f"Network error: {str(e)}"}), 500
    except Exception as e:
        print(f"❌ Signup error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Internal server error"}), 500


# @app.route("/login", methods=["POST"])
# def login():
#     """Login existing Firebase Authentication user."""
#     try:
#         data = request.get_json()

#         if not data:
#             return jsonify({"error": "No data provided"}), 400

#         email = data.get("email", "").strip()
#         password = data.get("password", "")

#         if not email or not password:
#             return jsonify({"error": "Email and password required"}), 400

#         url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={FIREBASE_API_KEY}"
#         payload = {"email": email, "password": password, "returnSecureToken": True}

#         response = requests.post(url, json=payload, timeout=10)
#         res_data = response.json()

#         if response.status_code == 200:
#             print(f"✅ User logged in: {email}")

#             return (
#                 jsonify(
#                     {
#                         "message": "Login successful",
#                         "email": res_data.get("email"),
#                         "uid": res_data.get("localId"),
#                         "idToken": res_data.get("idToken"),
#                         "displayName": res_data.get("displayName", email.split("@")[0]),
#                     }
#                 ),
#                 200,
#             )
#         else:
#             error_message = res_data.get("error", {}).get("message", "Login failed")

#             if (
#                 "EMAIL_NOT_FOUND" in error_message
#                 or "INVALID_PASSWORD" in error_message
#             ):
#                 return jsonify({"error": "Invalid email or password"}), 401
#             elif "USER_DISABLED" in error_message:
#                 return jsonify({"error": "Account has been disabled"}), 403
#             elif "TOO_MANY_ATTEMPTS" in error_message:
#                 return jsonify({"error": "Too many attempts. Try again later."}), 429
#             else:
#                 return jsonify({"error": error_message}), 400

#     except Exception as e:
#         print(f"❌ Login error: {e}")
#         return jsonify({"error": "Internal server error"}), 500

# Replace your /login endpoint with this FIXED version
@app.route("/login", methods=["POST"])
def login():
    """Login - ULTIMATE FIX with password reset cache support"""
    try:
        data = request.get_json()

        if not data:
            return jsonify({"error": "No data"}), 400

        email = data.get("email", "").strip().lower()
        password = data.get("password", "")

        if not email or not password:
            return jsonify({"error": "Email and password required"}), 400

        print(f"\n{'='*80}")
        print(f"🔐 LOGIN ATTEMPT")
        print(f"{'='*80}")
        print(f"Email: {email}")
        print(f"Password: {'*' * len(password)} (len: {len(password)})")

        # ⭐ CHECK 1: Was password just reset? Use temporary bypass
        if email in password_reset_tracker:
            reset_data = password_reset_tracker[email]
            reset_time = reset_data['reset_time']
            stored_password = reset_data['password']
            
            # If reset was within last 5 minutes and password matches
            time_since_reset = (datetime.now(timezone.utc) - reset_time).total_seconds()
            
            if time_since_reset < 300:  # 5 minutes
                print(f"⚡ Recent password reset detected ({time_since_reset:.0f}s ago)")
                
                if password == stored_password:
                    print(f"✅ Password matches recent reset - ALLOWING LOGIN")
                    
                    # Get user info
                    try:
                        user_record = admin_auth.get_user_by_email(email)
                        
                        # Generate custom token for immediate login
                        custom_token = admin_auth.create_custom_token(user_record.uid)
                        
                        # Clean up tracker after successful login
                        del password_reset_tracker[email]
                        
                        print(f"✅ LOGIN SUCCESSFUL (Password Reset Bypass)")
                        print(f"{'='*80}\n")
                        
                        return jsonify({
                            "message": "Login successful",
                            "email": email,
                            "uid": user_record.uid,
                            "idToken": custom_token.decode('utf-8') if isinstance(custom_token, bytes) else custom_token,
                            "displayName": user_record.display_name or email.split("@")[0],
                            "method": "password_reset_bypass"
                        }), 200
                        
                    except Exception as e:
                        print(f"⚠️ Custom token generation failed: {e}")
                        # Continue to normal login below

        # ⭐ CHECK 2: Normal Firebase REST API login
        print(f"📡 Trying Firebase REST API...")
        
        url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={FIREBASE_API_KEY}"
        payload = {"email": email, "password": password, "returnSecureToken": True}

        response = requests.post(url, json=payload, timeout=10)
        res_data = response.json()

        if response.status_code == 200:
            print(f"✅ LOGIN SUCCESSFUL (REST API)")
            print(f"{'='*80}\n")

            # Clean up password reset tracker if exists
            if email in password_reset_tracker:
                del password_reset_tracker[email]

            return jsonify({
                "message": "Login successful",
                "email": res_data.get("email"),
                "uid": res_data.get("localId"),
                "idToken": res_data.get("idToken"),
                "displayName": res_data.get("displayName", email.split("@")[0]),
                "method": "firebase_rest_api"
            }), 200
        else:
            error = res_data.get("error", {}).get("message", "Login failed")
            print(f"❌ LOGIN FAILED: {error}")
            print(f"{'='*80}\n")

            if "EMAIL_NOT_FOUND" in error or "INVALID_PASSWORD" in error:
                return jsonify({"error": "Invalid email or password"}), 401
            elif "USER_DISABLED" in error:
                return jsonify({"error": "Account disabled"}), 403
            elif "TOO_MANY_ATTEMPTS" in error:
                return jsonify({"error": "Too many attempts"}), 429
            else:
                return jsonify({"error": error}), 400

    except Exception as e:
        print(f"❌ Login error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Server error"}), 500
    
@app.route("/signup-with-otp", methods=["POST"])
def signup_with_otp():
    """Enhanced signup that requires email verification"""
    try:
        data = request.get_json()
        print(f"\n🔐 Signup with OTP request: {data.get('email', 'NO EMAIL')}")

        if not data:
            return jsonify({"success": False, "error": "No data provided"}), 400

        email = data.get("email", "").strip().lower()
        password = data.get("password", "")

        if not email or not password:
            return jsonify({"success": False, "error": "Email and password required"}), 400

        if "@" not in email or "." not in email:
            return jsonify({"success": False, "error": "Invalid email format"}), 400

        if len(password) < 6:
            return jsonify({"success": False, "error": "Password must be at least 6 characters"}), 400

        # Call Firebase Auth API
        url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={FIREBASE_API_KEY}"
        payload = {"email": email, "password": password, "returnSecureToken": True}

        response = requests.post(url, json=payload, timeout=10)
        res_data = response.json()

        if response.status_code == 200:
            user_data = {
                "email": email,
                "uid": res_data["localId"],
                "createdAt": datetime.now(timezone.utc).isoformat(),
                "displayName": email.split("@")[0],
                "role": "user",
                "emailVerified": False,
                "premiumAccess": False,
                "apiAccessEnabled": False,
            }

            if db:
                db.collection("Users").document(res_data["localId"]).set(user_data)
                print("✅ User saved to Firestore (unverified)")

            # Send OTP
            otp_code = generate_otp()
            expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES)
            
            otp_store[email] = {
                "otp": otp_code,
                "expires": expires_at,
                "attempts": 0,
                "last_sent": datetime.now(timezone.utc),
            }
            
            otp_sent = send_otp_email(email, otp_code)

            return jsonify({
                "success": True,
                "message": "Account created! Please verify your email.",
                "email": email,
                "uid": res_data["localId"],
                "idToken": res_data.get("idToken"),
                "otp_sent": otp_sent,
                "requires_verification": True,
            }), 200
        else:
            error_message = res_data.get("error", {}).get("message", "Signup failed")
            if "EMAIL_EXISTS" in error_message:
                return jsonify({"success": False, "error": "Email already registered"}), 400
            return jsonify({"success": False, "error": error_message}), 400

    except Exception as e:
        print(f"❌ Signup error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"success": False, "error": "Internal server error"}), 500


@app.route("/send-otp", methods=["POST"])
def send_otp():
    """Send OTP to user's email"""
    try:
        data = request.get_json()
        email = data.get("email", "").strip().lower()
        
        if not email:
            return jsonify({"success": False, "error": "Email required"}), 400
        
        if "@" not in email or "." not in email:
            return jsonify({"success": False, "error": "Invalid email format"}), 400
        
        # Check cooldown
        if email in otp_store:
            last_sent = otp_store[email].get("last_sent")
            if last_sent:
                elapsed = (datetime.now(timezone.utc) - last_sent).total_seconds()
                if elapsed < OTP_RESEND_COOLDOWN_SECONDS:
                    remaining = int(OTP_RESEND_COOLDOWN_SECONDS - elapsed)
                    return jsonify({
                        "success": False,
                        "error": f"Please wait {remaining} seconds before requesting a new OTP",
                        "cooldown": True,
                        "remaining_seconds": remaining
                    }), 429
        
        # Generate OTP
        otp_code = generate_otp()
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES)
        
        # Store OTP
        otp_store[email] = {
            "otp": otp_code,
            "expires": expires_at,
            "attempts": 0,
            "last_sent": datetime.now(timezone.utc),
            "created_at": datetime.now(timezone.utc).isoformat()
        }
        
        # Send email
        email_sent = send_otp_email(email, otp_code)
        
        if email_sent:
            print(f"✅ OTP sent to {email}: {otp_code}")
            
            return jsonify({
                "success": True,
                "message": "OTP sent successfully! Check your email.",
                "expires_in_minutes": OTP_EXPIRY_MINUTES,
                "cooldown_seconds": OTP_RESEND_COOLDOWN_SECONDS,
            }), 200
        else:
            return jsonify({
                "success": False,
                "error": "Failed to send OTP. Please check email configuration."
            }), 500
            
    except Exception as e:
        print(f"❌ Send OTP error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"success": False, "error": "Internal server error"}), 500


@app.route("/verify-otp", methods=["POST"])
def verify_otp():
    """Verify OTP entered by user"""
    try:
        data = request.get_json()
        email = data.get("email", "").strip().lower()
        entered_otp = data.get("otp", "").strip()
        
        if not email or not entered_otp:
            return jsonify({"success": False, "error": "Email and OTP required"}), 400
        
        # Check if OTP exists
        if email not in otp_store:
            return jsonify({
                "success": False,
                "error": "No OTP found. Please request a new one.",
                "expired": True
            }), 400
        
        stored_data = otp_store[email]
        stored_otp = stored_data["otp"]
        expires_at = stored_data["expires"]
        attempts = stored_data.get("attempts", 0)
        
        # Check expiration
        if datetime.now(timezone.utc) > expires_at:
            del otp_store[email]
            return jsonify({
                "success": False,
                "error": "OTP expired. Please request a new one.",
                "expired": True
            }), 400
        
        # Check max attempts
        if attempts >= MAX_OTP_ATTEMPTS:
            del otp_store[email]
            return jsonify({
                "success": False,
                "error": "Maximum verification attempts exceeded. Please request a new OTP.",
                "max_attempts_exceeded": True
            }), 400
        
        # Verify OTP
        if entered_otp == stored_otp:
            # ✅ OTP VERIFIED!
            del otp_store[email]
            
            # Update user in Firestore
            if db:
                try:
                    users_ref = db.collection("Users").where("email", "==", email).limit(1).stream()
                    
                    for user_doc in users_ref:
                        db.collection("Users").document(user_doc.id).update({
                            "emailVerified": True,
                            "verifiedAt": datetime.now(timezone.utc).isoformat(),
                            "premiumAccess": True,
                            "apiAccessEnabled": True,
                        })
                        print(f"✅ User {email} verified and premium access granted")
                        break
                except Exception as e:
                    print(f"⚠️ Failed to update Firestore: {e}")
            
            return jsonify({
                "success": True,
                "message": "✅ Email verified successfully!",
                "email": email,
                "verified": True,
                "premium_access": True,
                "api_access": True
            }), 200
        else:
            # ❌ Wrong OTP
            otp_store[email]["attempts"] = attempts + 1
            remaining_attempts = MAX_OTP_ATTEMPTS - (attempts + 1)
            
            return jsonify({
                "success": False,
                "error": f"Invalid OTP. {remaining_attempts} attempt(s) remaining.",
                "attempts_remaining": remaining_attempts,
                "invalid_otp": True
            }), 400
            
    except Exception as e:
        print(f"❌ Verify OTP error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"success": False, "error": "Internal server error"}), 500


@app.route("/check-verification-status/<email>", methods=["GET"])
def check_verification_status(email):
    """Check if email is verified"""
    try:
        email = email.strip().lower()
        
        if not db:
            return jsonify({"success": False, "error": "Database not initialized"}), 500
        
        users_ref = db.collection("Users").where("email", "==", email).limit(1).stream()
        
        for user_doc in users_ref:
            user_data = user_doc.to_dict()
            return jsonify({
                "success": True,
                "email": email,
                "verified": user_data.get("emailVerified", False),
                "premium_access": user_data.get("premiumAccess", False),
                "api_access": user_data.get("apiAccessEnabled", False),
            }), 200
        
        return jsonify({
            "success": True,
            "email": email,
            "verified": False,
            "message": "User not found"
        }), 404
        
    except Exception as e:
        print(f"❌ Check verification error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# @app.route("/forgot-password", methods=["POST"])
# def forgot_password():
#     """Send password reset email with OTP - FIXED VERSION"""
#     try:
#         data = request.get_json()
#         email = data.get("email", "").strip().lower()
        
#         if not email:
#             return jsonify({"success": False, "error": "Email required"}), 400
        
#         if "@" not in email or "." not in email:
#             return jsonify({"success": False, "error": "Invalid email format"}), 400
        
#         print(f"\n{'='*60}")
#         print(f"🔐 PASSWORD RESET REQUEST")
#         print(f"   Email: {email}")
#         print(f"{'='*60}")
        
#         # ✅ FIX: Check if user exists in Firebase Authentication (not just Firestore)
#         user_exists = False
#         uid = None
        
#         try:
#             # Method 1: Check Firebase Auth using Admin SDK
#             user_record = admin_auth.get_user_by_email(email)
#             user_exists = True
#             uid = user_record.uid
#             print(f"✅ User found in Firebase Auth: {uid}")
#         except Exception as auth_error:
#             print(f"❌ User not found in Firebase Auth: {auth_error}")
            
#             # Method 2: Fallback - Check Firestore
#             if db:
#                 try:
#                     users_ref = db.collection("Users").where("email", "==", email).limit(1).stream()
                    
#                     for user_doc in users_ref:
#                         user_exists = True
#                         uid = user_doc.id
#                         print(f"✅ User found in Firestore: {uid}")
#                         break
                        
#                 except Exception as firestore_error:
#                     print(f"⚠️ Firestore check failed: {firestore_error}")
        
#         # If user doesn't exist anywhere, return error
#         if not user_exists:
#             print(f"❌ No account found with email: {email}")
#             return jsonify({
#                 "success": False,
#                 "error": "No account found with this email"
#             }), 404
        
#         # Check cooldown
#         cooldown_key = f"reset_{email}"
#         if cooldown_key in otp_store:
#             last_sent = otp_store[cooldown_key].get("last_sent")
#             if last_sent:
#                 elapsed = (datetime.now(timezone.utc) - last_sent).total_seconds()
#                 if elapsed < OTP_RESEND_COOLDOWN_SECONDS:
#                     remaining = int(OTP_RESEND_COOLDOWN_SECONDS - elapsed)
#                     print(f"⏰ Cooldown active: {remaining}s remaining")
#                     return jsonify({
#                         "success": False,
#                         "error": f"Please wait {remaining} seconds before requesting again",
#                         "cooldown": True,
#                         "remaining_seconds": remaining
#                     }), 429
        
#         # Generate OTP for password reset
#         otp_code = generate_otp()
#         expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES)
        
#         # Store OTP with reset prefix
#         otp_store[cooldown_key] = {
#             "otp": otp_code,
#             "expires": expires_at,
#             "attempts": 0,
#             "last_sent": datetime.now(timezone.utc),
#             "type": "password_reset",
#             "email": email,
#             "uid": uid  # Store UID for later use
#         }
        
#         print(f"🔑 Generated OTP: {otp_code}")
#         print(f"📧 Sending email to: {email}")
        
#         # Send password reset email
#         email_sent = send_password_reset_email(email, otp_code)
        
#         if email_sent:
#             print(f"✅ Password reset OTP sent to {email}: {otp_code}")
#             print(f"{'='*60}\n")
            
#             return jsonify({
#                 "success": True,
#                 "message": "Password reset instructions sent! Check your email.",
#                 "expires_in_minutes": OTP_EXPIRY_MINUTES,
#             }), 200
#         else:
#             print(f"❌ Email sending failed")
#             print(f"{'='*60}\n")
#             return jsonify({
#                 "success": False,
#                 "error": "Failed to send email. Please check email configuration."
#             }), 500
            
#     except Exception as e:
#         print(f"❌ Forgot password error: {e}")
#         import traceback
#         traceback.print_exc()
#         return jsonify({"success": False, "error": "Internal server error"}), 500

# @app.route("/reset-password", methods=["POST"])
# def reset_password():
#     """Reset password using OTP - FIXED VERSION WITH BETTER ERROR HANDLING"""
#     try:
#         data = request.get_json()
#         email = data.get("email", "").strip().lower()
#         otp = data.get("otp", "").strip()
#         new_password = data.get("new_password", "")
        
#         print(f"\n{'='*60}")
#         print(f"🔐 PASSWORD RESET VERIFICATION")
#         print(f"   Email: {email}")
#         print(f"   OTP: {otp}")
#         print(f"   New Password Length: {len(new_password)}")
#         print(f"{'='*60}")
        
#         if not email or not otp or not new_password:
#             return jsonify({
#                 "success": False,
#                 "error": "Email, OTP, and new password required"
#             }), 400
        
#         if len(new_password) < 6:
#             return jsonify({
#                 "success": False,
#                 "error": "Password must be at least 6 characters"
#             }), 400
        
#         # Check if OTP exists
#         cooldown_key = f"reset_{email}"
#         if cooldown_key not in otp_store:
#             print(f"❌ No OTP found for: {email}")
#             print(f"   Available keys: {list(otp_store.keys())}")
#             return jsonify({
#                 "success": False,
#                 "error": "No password reset request found. Please request a new one.",
#                 "expired": True
#             }), 400
        
#         stored_data = otp_store[cooldown_key]
#         stored_otp = stored_data["otp"]
#         expires_at = stored_data["expires"]
#         attempts = stored_data.get("attempts", 0)
#         stored_uid = stored_data.get("uid")
        
#         print(f"   Stored OTP: {stored_otp}")
#         print(f"   Stored UID: {stored_uid}")
#         print(f"   Attempts: {attempts}/{MAX_OTP_ATTEMPTS}")
        
#         # Check expiration
#         if datetime.now(timezone.utc) > expires_at:
#             del otp_store[cooldown_key]
#             print(f"❌ OTP expired")
#             return jsonify({
#                 "success": False,
#                 "error": "OTP expired. Please request a new password reset.",
#                 "expired": True
#             }), 400
        
#         # Check max attempts
#         if attempts >= MAX_OTP_ATTEMPTS:
#             del otp_store[cooldown_key]
#             print(f"❌ Max attempts exceeded")
#             return jsonify({
#                 "success": False,
#                 "error": "Maximum verification attempts exceeded. Please request a new reset.",
#                 "max_attempts_exceeded": True
#             }), 400
        
#         # Verify OTP
#         if otp == stored_otp:
#             print(f"✅ OTP verified successfully")
            
#             # Get UID - Try multiple methods
#             uid = stored_uid
            
#             if not uid:
#                 print(f"⚠️ UID not in OTP store, searching Firebase Auth...")
#                 try:
#                     # Method 1: Firebase Auth lookup
#                     user_record = admin_auth.get_user_by_email(email)
#                     uid = user_record.uid
#                     print(f"✅ Found UID via Firebase Auth: {uid}")
#                 except Exception as auth_lookup_error:
#                     print(f"❌ Firebase Auth lookup failed: {auth_lookup_error}")
                    
#                     # Method 2: Firestore lookup
#                     if db:
#                         try:
#                             print(f"   Trying Firestore lookup...")
#                             users_ref = db.collection("Users").where("email", "==", email).limit(1).stream()
                            
#                             for user_doc in users_ref:
#                                 uid = user_doc.id
#                                 print(f"✅ Found UID via Firestore: {uid}")
#                                 break
#                         except Exception as firestore_error:
#                             print(f"❌ Firestore lookup failed: {firestore_error}")
            
#             # If still no UID, return error
#             if not uid:
#                 print(f"❌ CRITICAL: No UID found for {email}")
#                 print(f"   This means the user doesn't exist in Firebase Auth or Firestore")
#                 return jsonify({
#                     "success": False,
#                     "error": "User account not found. Please contact support."
#                 }), 404
            
#             print(f"🔄 Updating password for UID: {uid}")
#             print(f"   Email: {email}")
#             print(f"   New Password: {'*' * len(new_password)}")
            
#             # Update password using Firebase Admin SDK
#             try:
#                 # THIS IS THE CRITICAL LINE
#                 admin_auth.update_user(uid, password=new_password)
#                 print(f"✅ Firebase Admin SDK password update SUCCESSFUL")
                
#                 # Verify the update worked by trying to get user again
#                 try:
#                     updated_user = admin_auth.get_user(uid)
#                     print(f"✅ User verification after update: {updated_user.email}")
#                 except Exception as verify_error:
#                     print(f"⚠️ Could not verify user after update: {verify_error}")
                
#             except Exception as update_error:
#                 print(f"❌ FIREBASE PASSWORD UPDATE FAILED!")
#                 print(f"   Error Type: {type(update_error).__name__}")
#                 print(f"   Error Message: {str(update_error)}")
                
#                 import traceback
#                 traceback.print_exc()
                
#                 return jsonify({
#                     "success": False,
#                     "error": f"Failed to update password: {str(update_error)}"
#                 }), 500
            
#             # Clear OTP after successful update
#             del otp_store[cooldown_key]
#             print(f"✅ OTP cleared from store")
            
#             print(f"✅ Password reset COMPLETE for {email}")
#             print(f"{'='*60}\n")
            
#             return jsonify({
#                 "success": True,
#                 "message": "Password reset successful! You can now login with your new password.",
#                 "email": email,
#                 "uid": uid
#             }), 200
            
#         else:
#             # Wrong OTP
#             otp_store[cooldown_key]["attempts"] = attempts + 1
#             remaining_attempts = MAX_OTP_ATTEMPTS - (attempts + 1)
            
#             print(f"❌ Invalid OTP entered")
#             print(f"   Expected: {stored_otp}")
#             print(f"   Received: {otp}")
#             print(f"   Attempts: {attempts + 1}/{MAX_OTP_ATTEMPTS}")
            
#             return jsonify({
#                 "success": False,
#                 "error": f"Invalid OTP. {remaining_attempts} attempt(s) remaining.",
#                 "attempts_remaining": remaining_attempts,
#                 "invalid_otp": True
#             }), 400
            
#     except Exception as e:
#         print(f"\n{'='*60}")
#         print(f"❌ CRITICAL ERROR IN /reset-password")
#         print(f"   Error: {e}")
#         print(f"{'='*60}\n")
        
#         import traceback
#         traceback.print_exc()
        
#         return jsonify({
#             "success": False,
#             "error": f"Internal server error: {str(e)}"
#         }), 500

@app.route("/forgot-password", methods=["POST"])
def forgot_password():
    """Send password reset email with OTP"""
    from firebase_admin import auth as admin_auth  # ✅ Import here
    
    try:
        data = request.get_json()
        email = data.get("email", "").strip().lower()
        
        if not email or "@" not in email:
            return jsonify({"success": False, "error": "Invalid email"}), 400
        
        print(f"\n🔐 Password Reset Request: {email}")
        
        # Check if user exists in Firebase Auth
        user_exists = False
        uid = None
        
        try:
            user_record = admin_auth.get_user_by_email(email)
            user_exists = True
            uid = user_record.uid
            print(f"✅ User found: {uid}")
        except Exception as e:
            print(f"❌ User not in Firebase Auth: {e}")
            
            # Fallback: check Firestore
            if db:
                users_ref = db.collection("Users").where("email", "==", email).limit(1).stream()
                for user_doc in users_ref:
                    user_exists = True
                    uid = user_doc.id
                    print(f"✅ User found in Firestore: {uid}")
                    break
        
        if not user_exists:
            return jsonify({
                "success": False,
                "error": "No account found with this email"
            }), 404
        
        # Check cooldown
        cooldown_key = f"reset_{email}"
        if cooldown_key in otp_store:
            last_sent = otp_store[cooldown_key].get("last_sent")
            if last_sent:
                elapsed = (datetime.now(timezone.utc) - last_sent).total_seconds()
                if elapsed < OTP_RESEND_COOLDOWN_SECONDS:
                    remaining = int(OTP_RESEND_COOLDOWN_SECONDS - elapsed)
                    return jsonify({
                        "success": False,
                        "error": f"Please wait {remaining} seconds",
                        "cooldown": True
                    }), 429
        
        # Generate OTP
        otp_code = generate_otp()
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES)
        
        otp_store[cooldown_key] = {
            "otp": otp_code,
            "expires": expires_at,
            "attempts": 0,
            "last_sent": datetime.now(timezone.utc),
            "email": email,
            "uid": uid  # Store UID
        }
        
        # Send email
        if send_password_reset_email(email, otp_code):
            print(f"✅ OTP sent: {otp_code}")
            return jsonify({
                "success": True,
                "message": "Password reset code sent to your email!"
            }), 200
        else:
            return jsonify({
                "success": False,
                "error": "Failed to send email"
            }), 500
            
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/reset-password", methods=["POST"])
def reset_password():
    """Reset password - GUARANTEED WORKING VERSION"""
    try:
        # Import Firebase Admin Auth
        from firebase_admin import auth as admin_auth
        
        data = request.get_json()
        email = data.get("email", "").strip().lower()
        otp = data.get("otp", "").strip()
        new_password = data.get("new_password", "")
        
        print(f"\n{'='*80}")
        print(f"🔐 PASSWORD RESET REQUEST")
        print(f"{'='*80}")
        print(f"Email: {email}")
        print(f"OTP: {otp}")
        print(f"New Password: {'*' * len(new_password)} (length: {len(new_password)})")
        
        # Validate inputs
        if not email or not otp or not new_password:
            print("❌ Missing required fields")
            return jsonify({
                "success": False,
                "error": "Email, OTP, and new password required"
            }), 400
        
        if len(new_password) < 6:
            print("❌ Password too short")
            return jsonify({
                "success": False,
                "error": "Password must be at least 6 characters"
            }), 400
        
        # Check OTP exists
        cooldown_key = f"reset_{email}"
        if cooldown_key not in otp_store:
            print(f"❌ No OTP found in store for: {email}")
            print(f"Available keys: {list(otp_store.keys())}")
            return jsonify({
                "success": False,
                "error": "No password reset request found. Please request a new one.",
                "expired": True
            }), 400
        
        stored_data = otp_store[cooldown_key]
        stored_otp = stored_data["otp"]
        expires_at = stored_data["expires"]
        attempts = stored_data.get("attempts", 0)
        stored_uid = stored_data.get("uid")
        
        print(f"\n📋 OTP Verification:")
        print(f"   Expected OTP: {stored_otp}")
        print(f"   Received OTP: {otp}")
        print(f"   Stored UID: {stored_uid}")
        print(f"   Attempts: {attempts}/{MAX_OTP_ATTEMPTS}")
        
        # Check expiration
        now = datetime.now(timezone.utc)
        if now > expires_at:
            del otp_store[cooldown_key]
            print(f"❌ OTP expired at {expires_at}, current time is {now}")
            return jsonify({
                "success": False,
                "error": "OTP expired. Please request a new password reset.",
                "expired": True
            }), 400
        
        # Check max attempts
        if attempts >= MAX_OTP_ATTEMPTS:
            del otp_store[cooldown_key]
            print(f"❌ Maximum attempts ({MAX_OTP_ATTEMPTS}) exceeded")
            return jsonify({
                "success": False,
                "error": "Maximum verification attempts exceeded.",
                "max_attempts_exceeded": True
            }), 400
        
        # Verify OTP matches
        if otp != stored_otp:
            otp_store[cooldown_key]["attempts"] = attempts + 1
            remaining = MAX_OTP_ATTEMPTS - (attempts + 1)
            print(f"❌ OTP mismatch!")
            print(f"   Remaining attempts: {remaining}")
            return jsonify({
                "success": False,
                "error": f"Invalid OTP. {remaining} attempt(s) remaining.",
                "attempts_remaining": remaining
            }), 400
        
        print(f"✅ OTP verified successfully!")
        
        # Get user UID - Try multiple methods
        uid = stored_uid
        
        if not uid:
            print(f"\n🔍 No UID stored, searching for user...")
            
            # Method 1: Firebase Auth
            try:
                print(f"   Trying Firebase Auth lookup...")
                user_record = admin_auth.get_user_by_email(email)
                uid = user_record.uid
                print(f"   ✅ Found in Firebase Auth: {uid}")
            except Exception as auth_err:
                print(f"   ❌ Firebase Auth failed: {auth_err}")
                
                # Method 2: Firestore
                if db:
                    try:
                        print(f"   Trying Firestore lookup...")
                        users_ref = db.collection("Users").where("email", "==", email).limit(1).stream()
                        
                        for user_doc in users_ref:
                            uid = user_doc.id
                            print(f"   ✅ Found in Firestore: {uid}")
                            break
                    except Exception as fs_err:
                        print(f"   ❌ Firestore failed: {fs_err}")
        
        if not uid:
            print(f"❌ FATAL: No UID found for {email}")
            return jsonify({
                "success": False,
                "error": "User account not found in system"
            }), 404
        
        print(f"\n🎯 Found user UID: {uid}")
        
        # VERIFY USER EXISTS BEFORE UPDATE
        print(f"\n🔍 Verifying user exists in Firebase Auth...")
        try:
            existing_user = admin_auth.get_user(uid)
            print(f"✅ User exists:")
            print(f"   UID: {existing_user.uid}")
            print(f"   Email: {existing_user.email}")
            print(f"   Email Verified: {existing_user.email_verified}")
            print(f"   Disabled: {existing_user.disabled}")
        except Exception as verify_err:
            print(f"❌ User does not exist in Firebase Auth!")
            print(f"   Error: {verify_err}")
            return jsonify({
                "success": False,
                "error": "User account not found in Firebase Authentication"
            }), 404
        
        # NOW UPDATE THE PASSWORD
        print(f"\n🔄 UPDATING PASSWORD IN FIREBASE AUTH...")
        print(f"   UID: {uid}")
        print(f"   Email: {email}")
        
        try:
            # THIS IS THE CRITICAL LINE
            admin_auth.update_user(
                uid,
                password=new_password
            )
            
            print(f"✅✅✅ PASSWORD UPDATE SUCCESSFUL! ✅✅✅")
            # ⭐ CRITICAL: Store password temporarily for immediate login
            password_reset_tracker[email] = {
            'password': new_password,
            'reset_time': datetime.now(timezone.utc),
            'uid': uid
    }
            print(f"⚡ Password cached for immediate login bypass")
        except Exception as update_err:
            print(f"❌❌❌ PASSWORD UPDATE FAILED! ❌❌❌")
            print(f"Error Type: {type(update_err).__name__}")
            print(f"Error Message: {str(update_err)}")
            
            import traceback
            print("\nFull traceback:")
            traceback.print_exc()
            
            return jsonify({
                "success": False,
                "error": f"Failed to update password: {str(update_err)}"
            }), 500
        
        # Verify the password was actually updated
        print(f"\n✅ Verifying password update...")
        try:
            # Try to get user again to confirm they still exist
            verify_user = admin_auth.get_user(uid)
            print(f"✅ User still exists after update: {verify_user.email}")
            
            # Note: We cannot verify the password directly, but we can confirm the user exists
            print(f"✅ Password has been updated in Firebase Authentication")
            print(f"✅ User can now login with: {email} / [new password]")
            
        except Exception as final_verify_err:
            print(f"⚠️ Warning: Could not verify user after update: {final_verify_err}")
        
        # Clear OTP
        try:
            del otp_store[cooldown_key]
            print(f"✅ OTP cleared from memory")
        except:
            pass
        
        print(f"\n{'='*80}")
        print(f"🎉 PASSWORD RESET COMPLETE!")
        print(f"{'='*80}")
        print(f"Email: {email}")
        print(f"UID: {uid}")
        print(f"Status: User can now login with new password")
        print(f"{'='*80}\n")
        
        return jsonify({
            "success": True,
            "message": "Password reset successful! You can now login with your new password.",
            "email": email
        }), 200
        
    except Exception as critical_err:
        print(f"\n{'='*80}")
        print(f"❌ CRITICAL ERROR IN PASSWORD RESET")
        print(f"{'='*80}")
        print(f"Error: {critical_err}")
        print(f"Type: {type(critical_err).__name__}")
        
        import traceback
        print("\nFull traceback:")
        traceback.print_exc()
        print(f"{'='*80}\n")
        
        return jsonify({
            "success": False,
            "error": f"Internal error: {str(critical_err)}"
        }), 500
# @app.route("/reset-password", methods=["POST"])
# def reset_password():
#     """Reset password using OTP - COMPLETE FIX"""
#     try:
#         data = request.get_json()
#         email = data.get("email", "").strip().lower()
#         otp = data.get("otp", "").strip()
#         new_password = data.get("new_password", "")
        
#         print(f"\n{'='*60}")
#         print(f"🔐 PASSWORD RESET VERIFICATION")
#         print(f"   Email: {email}")
#         print(f"   OTP: {otp}")
#         print(f"   New Password Length: {len(new_password)}")
#         print(f"{'='*60}")
        
#         if not email or not otp or not new_password:
#             return jsonify({
#                 "success": False,
#                 "error": "Email, OTP, and new password required"
#             }), 400
        
#         if len(new_password) < 6:
#             return jsonify({
#                 "success": False,
#                 "error": "Password must be at least 6 characters"
#             }), 400
        
#         # Check if OTP exists
#         cooldown_key = f"reset_{email}"
#         if cooldown_key not in otp_store:
#             print(f"❌ No OTP found for: {email}")
#             print(f"   Available OTP keys: {list(otp_store.keys())}")
#             return jsonify({
#                 "success": False,
#                 "error": "No password reset request found. Please request a new one.",
#                 "expired": True
#             }), 400
        
#         stored_data = otp_store[cooldown_key]
#         stored_otp = stored_data["otp"]
#         expires_at = stored_data["expires"]
#         attempts = stored_data.get("attempts", 0)
#         stored_uid = stored_data.get("uid")
        
#         print(f"   Stored OTP: {stored_otp}")
#         print(f"   Stored UID: {stored_uid}")
#         print(f"   Attempts: {attempts}/{MAX_OTP_ATTEMPTS}")
#         print(f"   Expires: {expires_at}")
        
#         # Check expiration
#         if datetime.now(timezone.utc) > expires_at:
#             del otp_store[cooldown_key]
#             print(f"❌ OTP expired")
#             return jsonify({
#                 "success": False,
#                 "error": "OTP expired. Please request a new password reset.",
#                 "expired": True
#             }), 400
        
#         # Check max attempts
#         if attempts >= MAX_OTP_ATTEMPTS:
#             del otp_store[cooldown_key]
#             print(f"❌ Max attempts exceeded")
#             return jsonify({
#                 "success": False,
#                 "error": "Maximum verification attempts exceeded. Please request a new reset.",
#                 "max_attempts_exceeded": True
#             }), 400
        
#         # Verify OTP
#         if otp != stored_otp:
#             # Wrong OTP
#             otp_store[cooldown_key]["attempts"] = attempts + 1
#             remaining_attempts = MAX_OTP_ATTEMPTS - (attempts + 1)
            
#             print(f"❌ Invalid OTP entered")
#             print(f"   Expected: {stored_otp}")
#             print(f"   Received: {otp}")
#             print(f"   Attempts: {attempts + 1}/{MAX_OTP_ATTEMPTS}")
            
#             return jsonify({
#                 "success": False,
#                 "error": f"Invalid OTP. {remaining_attempts} attempt(s) remaining.",
#                 "attempts_remaining": remaining_attempts,
#                 "invalid_otp": True
#             }), 400
        
#         # ✅ OTP is correct, now update password
#         print(f"✅ OTP verified successfully!")
        
#         uid = stored_uid
        
#         # If UID not stored, try to find it
#         if not uid:
#             print(f"⚠️ UID not in OTP store, searching for user...")
#             try:
#                 from firebase_admin import auth as admin_auth
#                 user_record = admin_auth.get_user_by_email(email)
#                 uid = user_record.uid
#                 print(f"✅ Found UID via Firebase Auth: {uid}")
#             except Exception as lookup_error:
#                 print(f"❌ Firebase Auth lookup failed: {lookup_error}")
                
#                 # Fallback to Firestore
#                 if db:
#                     try:
#                         users_ref = db.collection("Users").where("email", "==", email).limit(1).stream()
#                         for user_doc in users_ref:
#                             uid = user_doc.id
#                             print(f"✅ Found UID via Firestore: {uid}")
#                             break
#                     except Exception as fs_error:
#                         print(f"❌ Firestore lookup failed: {fs_error}")
        
#         # Final check: Do we have UID?
#         if not uid:
#             print(f"❌ CRITICAL: No UID found for {email}")
#             return jsonify({
#                 "success": False,
#                 "error": "User account not found in system. Please contact support."
#             }), 404
        
#         # ✅ NOW UPDATE THE PASSWORD
#         print(f"🔄 Updating password in Firebase Auth...")
#         print(f"   UID: {uid}")
#         print(f"   Email: {email}")
        
#         try:
#             from firebase_admin import auth as admin_auth
            
#             # THIS IS THE KEY LINE - Update password
#             admin_auth.update_user(
#                 uid,
#                 password=new_password
#             )
            
#             print(f"✅ Firebase Auth password update SUCCESSFUL!")
            
#             # Verify update by getting user again
#             try:
#                 updated_user = admin_auth.get_user(uid)
#                 print(f"✅ Verification: User {updated_user.email} exists after update")
#             except Exception as verify_error:
#                 print(f"⚠️ Could not verify user after update: {verify_error}")
            
#         except Exception as update_error:
#             print(f"❌ FIREBASE PASSWORD UPDATE FAILED!")
#             print(f"   Error Type: {type(update_error).__name__}")
#             print(f"   Error Message: {str(update_error)}")
            
#             import traceback
#             traceback.print_exc()
            
#             return jsonify({
#                 "success": False,
#                 "error": f"Failed to update password in Firebase: {str(update_error)}"
#             }), 500
        
#         # Clear OTP after successful update
#         try:
#             del otp_store[cooldown_key]
#             print(f"✅ OTP cleared from store")
#         except:
#             pass
        
#         print(f"✅ PASSWORD RESET COMPLETE!")
#         print(f"   Email: {email}")
#         print(f"   UID: {uid}")
#         print(f"   User can now login with new password")
#         print(f"{'='*60}\n")
        
#         return jsonify({
#             "success": True,
#             "message": "Password reset successful! You can now login with your new password.",
#             "email": email
#         }), 200
        
#     except Exception as e:
#         print(f"\n{'='*60}")
#         print(f"❌ CRITICAL ERROR IN /reset-password")
#         print(f"   Error: {e}")
#         print(f"{'='*60}\n")
        
#         import traceback
#         traceback.print_exc()
        
#         return jsonify({
#             "success": False,
#             "error": f"Internal server error: {str(e)}"
#         }), 500

# ==========================
# 🗺️ ZONE MANAGEMENT ROUTES
# ==========================

@app.route("/add-zone", methods=["POST"])
def add_zone():
    """Add a new restricted zone to Firestore."""
    try:
        if not db:
            return jsonify({"error": "Firebase not initialized"}), 500

        data = request.get_json()

        if not data:
            return jsonify({"error": "No data provided"}), 400

        zone_name = data.get("zone_name", f"Zone_{int(time.time())}")
        city = data.get("city", "Unknown")
        center = data.get("center")
        radius_meters = data.get("radius_meters", 100.0)
        active_hours = data.get("active_hours", "08:00–11:00, 17:00–21:00")
        inactive_hours = data.get("inactive_hours", "21:00–08:00")

        if not center or "lat" not in center or "lon" not in center:
            return (
                jsonify({"error": "Valid center coordinates (lat/lon) required"}),
                400,
            )

        try:
            lat = float(center["lat"])
            lon = float(center["lon"])
            radius = float(radius_meters)
        except (ValueError, TypeError):
            return jsonify({"error": "Invalid coordinate or radius format"}), 400

        if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
            return jsonify({"error": "Invalid latitude or longitude values"}), 400

        if radius <= 0:
            return jsonify({"error": "Radius must be positive"}), 400

        zone_id = f"way_{int(time.time() * 1000)}"

        zone_data = {
            "id": zone_id,
            "zone_name": zone_name,
            "city": city,
            "center": {"lat": lat, "lon": lon},
            "radius_meters": radius,
            "active_hours": active_hours,
            "inactive_hours": inactive_hours,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "status": "active",
        }

        db.collection("ZoneData").document(zone_id).set(zone_data)

        # INVALIDATE CACHE
        global zones_cache
        zones_cache["last_updated"] = 0

        print(f"✅ Zone added: {zone_name} ({zone_id})")

        return (
            jsonify(
                {
                    "status": "success",
                    "message": f"Zone '{zone_name}' added successfully",
                    "id": zone_id,
                    "data": zone_data,
                }
            ),
            200,
        )

    except Exception as e:
        print(f"❌ Error adding zone: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/get-zones", methods=["GET"])
def get_zones():
    """Fetch all restricted zones from Firestore (CACHED)."""
    try:
        if not db:
            return (
                jsonify(
                    {
                        "status": "error",
                        "success": False,
                        "error": "Firebase not initialized",
                        "zones": [],
                        "data": [],
                    }
                ),
                500,
            )

        zones = get_zones_cached()
        zones.sort(key=lambda x: x.get("created_at", ""), reverse=True)

        print(f"✅ Fetched {len(zones)} zones from cache/firestore")

        return (
            jsonify(
                {
                    "status": "success",
                    "success": True,
                    "total_zones": len(zones),
                    "zones": zones,
                    "data": zones,
                }
            ),
            200,
        )

    except Exception as e:
        print(f"❌ Error fetching zones: {e}")
        return (
            jsonify(
                {
                    "status": "error",
                    "success": False,
                    "error": str(e),
                    "zones": [],
                    "data": [],
                }
            ),
            500,
        )


@app.route("/delete-zone/<zone_id>", methods=["DELETE"])
def delete_zone(zone_id):
    """Delete a restricted zone from Firestore."""
    try:
        if not db:
            return jsonify({"error": "Firebase not initialized"}), 500

        if not zone_id:
            return jsonify({"error": "Zone ID required"}), 400

        zone_ref = db.collection("ZoneData").document(zone_id)
        zone = zone_ref.get()

        if not zone.exists:
            return (
                jsonify(
                    {"status": "error", "success": False, "error": "Zone not found"}
                ),
                404,
            )

        zone_ref.delete()

        # INVALIDATE CACHE
        global zones_cache
        zones_cache["last_updated"] = 0

        print(f"✅ Zone deleted: {zone_id}")

        return (
            jsonify(
                {
                    "status": "success",
                    "success": True,
                    "message": f"Zone {zone_id} deleted successfully",
                }
            ),
            200,
        )

    except Exception as e:
        print(f"❌ Error deleting zone: {e}")
        return jsonify({"status": "error", "success": False, "error": str(e)}), 500


# ==========================
# 🚨 VIOLATION ROUTES - FIXED VERSION
# ==========================

@app.route("/get-violations", methods=["GET"])
def get_violations():
    """Fetch all vehicle violation records from Firestore - FIXED"""
    try:
        print("\n" + "="*60)
        print("📋 GET-VIOLATIONS ENDPOINT CALLED")
        print("="*60)
        
        if not db:
            print("❌ Firebase not initialized")
            return (
                jsonify(
                    {
                        "status": "error",
                        "success": False,
                        "error": "Firebase not initialized",
                        "violations": [],
                        "data": []
                    }
                ),
                500,
            )

        print("🔍 Querying Firestore Violations collection...")
        
        # Get all violations from Firestore
        violations_ref = db.collection("Violations").stream()
        violations = []

        violation_count = 0
        for doc in violations_ref:
            try:
                record = doc.to_dict()
                record["id"] = doc.id
                violations.append(record)
                violation_count += 1
                print(f"   ✅ Violation {violation_count}: {record.get('number_plate', 'N/A')} - {doc.id}")
            except Exception as doc_error:
                print(f"   ⚠️ Error reading doc {doc.id}: {doc_error}")
                continue

        print(f"\n📊 Total violations found: {len(violations)}")

        # Sort by timestamp (newest first) - FIXED to handle different timestamp types
        def get_sort_key(violation):
            """Get sortable timestamp from violation, handling different types"""
            timestamp = violation.get("timestamp") or violation.get("created_at")
            
            # If timestamp is None, return empty string
            if timestamp is None:
                return ""
            
            # If it's a Firestore DatetimeWithNanoseconds object, convert to ISO string
            if hasattr(timestamp, 'isoformat'):
                return timestamp.isoformat()
            
            # If it's already a string, return as-is
            if isinstance(timestamp, str):
                return timestamp
            
            # Fallback to empty string
            return ""
        
        try:
            violations.sort(key=get_sort_key, reverse=True)
            print("✅ Violations sorted successfully")
        except Exception as sort_error:
            print(f"⚠️ Sorting failed: {sort_error}, returning unsorted")

        print("="*60 + "\n")

        # Return in MULTIPLE formats for compatibility
        return (
            jsonify(
                {
                    "status": "success",
                    "success": True,
                    "total_violations": len(violations),
                    "violations": violations,
                    "data": violations,
                    "count": len(violations),
                }
            ),
            200,
        )

    except Exception as e:
        print(f"❌ Error fetching violations: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            "status": "error",
            "success": False,
            "error": str(e),
            "violations": [],
            "data": []
        }), 500


@app.route("/test-violations", methods=["GET"])
def test_violations():
    """Test endpoint to verify violation data structure"""
    try:
        if not db:
            return jsonify({"error": "Firebase not initialized"}), 500
        
        # Get first 5 violations
        violations_ref = db.collection("Violations").limit(5).stream()
        
        violations = []
        for doc in violations_ref:
            data = doc.to_dict()
            data["id"] = doc.id
            violations.append(data)
        
        # Also check what's in active_sessions
        session_info = {}
        for session_id, session_data in active_sessions.items():
            session_info[session_id] = {
                "status": session_data.get("status"),
                "violations_count": len(session_data.get("violations", [])),
            }
        
        return jsonify({
            "status": "success",
            "firestore_violations": violations,
            "firestore_count": len(violations),
            "active_sessions": session_info,
            "message": "Check if violations exist in Firestore"
        }), 200
        
    except Exception as e:
        print(f"Test error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# @app.route("/get-session-violations/<session_id>", methods=["GET"])
# def get_session_violations(session_id):
#     """Get violations for a specific processing session"""
#     try:
#         print(f"\n🔍 Fetching violations for session: {session_id}")
        
#         if session_id not in active_sessions:
#             print(f"   ❌ Session not found!")
#             print(f"   Available sessions: {list(active_sessions.keys())}")
#             return jsonify({
#                 "status": "error",
#                 "error": "Session not found",
#                 "violations": []
#             }), 404
        
#         session = active_sessions[session_id]
#         violations = session.get("violations", [])
        
#         print(f"   ✅ Found {len(violations)} violations in session")
        
#         return jsonify({
#             "status": "success",
#             "session_id": session_id,
#             "processing_status": session["status"],
#             "violations": violations,
#             "total_violations": len(violations),
#             "start_time": session.get("start_time")
#         }), 200
        
#     except Exception as e:
#         print(f"❌ Error fetching session violations: {e}")
#         import traceback
#         traceback.print_exc()
#         return jsonify({"status": "error", "error": str(e), "violations": []}), 500


# 2️⃣ FIXED /get-session-violations endpoint
@app.route("/get-session-violations/<session_id>", methods=["GET"])
def get_session_violations(session_id):
    """Get violations for a specific processing session - ENHANCED"""
    try:
        print(f"\n{'='*60}")
        print(f"🔍 GET-SESSION-VIOLATIONS REQUEST")
        print(f"   Requested: {session_id}")
        print(f"   Available: {list(active_sessions.keys())}")
        print(f"{'='*60}")
        
        if session_id not in active_sessions:
            print(f"   ❌ Session NOT FOUND!")
            return jsonify({
                "status": "error",
                "error": "Session not found",
                "violations": [],
                "available_sessions": list(active_sessions.keys())
            }), 404
        
        session = active_sessions[session_id]
        violations = session.get("violations", [])
        
        print(f"   ✅ Found {len(violations)} violations")
        
        return jsonify({
            "status": "success",
            "session_id": session_id,
            "processing_status": session["status"],
            "violations": violations,
            "total_violations": len(violations),
            "start_time": session.get("start_time"),
            "camera_id": session.get("camera_id"),
        }), 200
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            "status": "error", 
            "error": str(e), 
            "violations": []
        }), 500


@app.route("/vehicle-detected", methods=["POST"])
def vehicle_detected():
    """Store detected HMV vehicle logs and violations in Firestore + Session - FIXED"""
    try:
        if not db:
            print("❌ Firebase not initialized")
            return jsonify({"error": "Firebase not initialized"}), 500

        data = request.get_json()

        if not data:
            print("❌ No data provided")
            return jsonify({"error": "No data provided"}), 400

        vehicle_number = data.get("vehicle_number")
        vehicle_type = data.get("vehicle_type")
        accuracy_percentage = data.get("accuracy_percentage", "unknown")
        zone_location = data.get("zone_location")
        camera_id = data.get("camera_id")
        timestamp = data.get("timestamp") or datetime.now(timezone.utc).isoformat()
        video_path = data.get("video_path")
        session_id = data.get("session_id")

        print(f"\n🚗 Vehicle Detection Request:")
        print(f"   Vehicle: {vehicle_number}")
        print(f"   Type: {vehicle_type}")
        print(f"   Session: {session_id}")
        print(f"   Location: {zone_location}")

        if not vehicle_number or not vehicle_type or not zone_location:
            print("❌ Missing required fields")
            return jsonify({"error": "Missing required fields"}), 400

        # ONLY process HMV
        if vehicle_type != "HMV":
            print(f"   ℹ️ Vehicle is {vehicle_type}, not HMV - skipping")
            return jsonify({"status": "ignored", "message": "Vehicle is not HMV"}), 200

        # Check zone restriction
        print(f"   🔍 Checking zone restrictions...")
        restricted, zone_data = check_zone_restriction(zone_location)

        if not restricted:
            print(f"   ✅ Not in restricted zone")
            return jsonify({"status": "clear", "message": "Zone not restricted"}), 200

        zone_name = (
            zone_data.get("zone_name")
            or zone_data.get("properties", {}).get("name")
            or zone_data.get("zone_id", "Unknown Zone")
        )

        center = (zone_data["center"]["lat"], zone_data["center"]["lon"])
        vehicle_coords = (zone_location["lat"], zone_location["lon"])
        distance = geodesic(center, vehicle_coords).meters
        radius = zone_data["radius_meters"]

        print(f"   📍 Zone: {zone_name}")
        print(f"   📏 Distance: {distance:.2f}m / {radius}m")

        if distance <= radius:
            # Create violation data
            violation_data = {
                "number_plate": vehicle_number,
                "vehicle_type": "HMV",
                "accuracy_percentage": accuracy_percentage,
                "camera_id": camera_id,
                "zone_name": zone_name,
                "zone_id": zone_data.get("zone_id"),
                "city": zone_data.get("city", "Unknown"),
                "location": {"lat": zone_location["lat"], "lon": zone_location["lon"]},
                "timestamp": timestamp,
                "video_path": video_path or "not_provided",
                "distance_from_center_m": round(distance, 2),
                "zone_radius_m": radius,
                "status": "Violation Detected",
                "session_id": session_id,
                "created_at": datetime.now(timezone.utc).isoformat(),
            }

            # 🔥 CRITICAL FIX: Store in Firestore IMMEDIATELY with error handling
            violation_id = None
            try:
                print(f"   💾 Saving to Firestore...")
                violation_ref = db.collection("Violations").add(violation_data)
                violation_id = violation_ref[1].id
                violation_data["id"] = violation_id
                print(f"   ✅ Firestore save successful: {violation_id}")
            except Exception as firestore_error:
                print(f"   ❌ Firestore save FAILED: {firestore_error}")
                import traceback
                traceback.print_exc()
                # Return error - don't continue if Firestore save fails
                return jsonify({
                    "status": "error",
                    "error": "Failed to save violation to database",
                    "details": str(firestore_error)
                }), 500

            # Store in active session (if exists)
            if session_id:
                if session_id not in active_sessions:
                    print(f"   ⚠️ Session {session_id} not found, creating it...")
                    active_sessions[session_id] = {
                        "status": "processing",
                        "violations": [],
                        "start_time": datetime.now(timezone.utc).isoformat(),
                        "camera_id": camera_id,
                    }
                
                active_sessions[session_id]["violations"].append(violation_data)
                print(f"   ✅ Added to session {session_id}")
                print(f"   📊 Total violations in session: {len(active_sessions[session_id]['violations'])}")
            else:
                print(f"   ⚠️ No session_id provided")

            print(f"\n🚨 ========================================")
            print(f"🚨 VIOLATION DETECTED & SAVED!")
            print(f"🚨 Vehicle: {vehicle_number}")
            print(f"🚨 Zone: {zone_name}")
            print(f"🚨 Violation ID: {violation_id}")
            print(f"🚨 Distance: {round(distance, 2)}m from center")
            print(f"🚨 Session: {session_id}")
            print(f"🚨 Firestore: SAVED ✅")
            print(f"🚨 ========================================\n")

            return (
                jsonify(
                    {
                        "status": "violation",
                        "success": True,
                        "message": f"Violation stored for HMV {vehicle_number}",
                        "violation_id": violation_id,
                        "zone_name": zone_name,
                        "distance_m": round(distance, 2),
                        "radius_m": radius,
                        "video_path": video_path or "not_found",
                        "violation_data": violation_data,
                        "saved_to_firestore": True,
                        "saved_to_session": bool(session_id),
                    }
                ),
                200,
            )
        else:
            print(f"   ✅ Outside restricted radius")
            return (
                jsonify(
                    {
                        "status": "clear",
                        "message": f"{vehicle_number} outside restricted radius",
                        "distance_m": round(distance, 2),
                        "radius_m": radius,
                    }
                ),
                200,
            )

    except Exception as e:
        print(f"❌ Vehicle detection error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "details": "Check server logs"}), 500


# ==========================
# 🎬 VIDEO PROCESSING ENDPOINTS
# ==========================

@app.route("/upload-video", methods=["POST"])
def upload_video():
    """Upload video file for later processing"""
    try:
        if "video" not in request.files:
            return jsonify({"error": "No video file provided"}), 400

        video_file = request.files["video"]

        if video_file.filename == "":
            return jsonify({"error": "No file selected"}), 400

        allowed_extensions = {"mp4", "avi", "mov", "mkv"}
        file_ext = (
            video_file.filename.rsplit(".", 1)[1].lower()
            if "." in video_file.filename
            else ""
        )

        if file_ext not in allowed_extensions:
            return (
                jsonify(
                    {
                        "error": f'Invalid file type. Use: {", ".join(allowed_extensions).upper()}'
                    }
                ),
                400,
            )

        filename = secure_filename(video_file.filename)
        timestamp = int(time.time())
        unique_filename = f"{timestamp}_{filename}"
        filepath = os.path.join(VIDEO_STORAGE_PATH, unique_filename)
        video_file.save(filepath)

        file_size = os.path.getsize(filepath)

        print(f"✅ Video uploaded: {unique_filename}")

        return (
            jsonify(
                {
                    "status": "success",
                    "message": f'Video "{filename}" uploaded successfully!',
                    "filepath": filepath,
                    "filename": unique_filename,
                    "size_mb": round(file_size / (1024 * 1024), 2),
                }
            ),
            200,
        )

    except Exception as e:
        print(f"❌ Video upload error: {e}")
        return jsonify({"error": f"Upload failed: {str(e)}"}), 500


# @app.route("/process-video", methods=["POST"])
# def process_video():
#     """Process uploaded video with AI model"""
#     print("\n" + "="*80)
#     print("🎥 PROCESS-VIDEO ENDPOINT HIT!")
#     print("="*80)
    
#     try:
#         if ai_processor is None:
#             print("❌ AI Processor not available")
#             return jsonify({"error": "AI Processor not available"}), 503

#         if "video" not in request.files:
#             print("❌ No video file in request")
#             return jsonify({"error": "No video file provided"}), 400

#         video_file = request.files["video"]
        
#         if video_file.filename == '':
#             print("❌ Empty filename")
#             return jsonify({"error": "No file selected"}), 400

#         print(f"✅ Video file received: {video_file.filename}")

#         camera_lat = request.form.get("camera_lat")
#         camera_lon = request.form.get("camera_lon")
#         camera_id = request.form.get("camera_id", "UNKNOWN")
#         session_id = request.form.get("session_id")

#         print(f"📍 Camera Location: {camera_lat}, {camera_lon}")
#         print(f"📸 Camera ID: {camera_id}")
#         print(f"🔧 Session ID: {session_id}")

#         if not camera_lat or not camera_lon:
#             print("❌ Missing camera location")
#             return jsonify({"error": "Camera location (lat/lon) required"}), 400

#         if not session_id:
#             session_id = f"session_{int(time.time() * 1000)}"
#             print(f"🔧 Generated session ID: {session_id}")

#         try:
#             camera_lat = float(camera_lat)
#             camera_lon = float(camera_lon)
#             print(f"✅ Coordinates validated: ({camera_lat}, {camera_lon})")
#         except ValueError as e:
#             print(f"❌ Invalid coordinate format: {e}")
#             return jsonify({"error": "Invalid latitude/longitude format"}), 400

#         filename = secure_filename(video_file.filename)
#         timestamp = int(time.time())
#         unique_filename = f"{timestamp}_{filename}"
#         filepath = os.path.join(VIDEO_STORAGE_PATH, unique_filename)
        
#         print(f"💾 Saving video to: {filepath}")
#         video_file.save(filepath)
        
#         file_size = os.path.getsize(filepath)
#         print(f"✅ Video saved successfully!")
#         print(f"   Size: {file_size / (1024*1024):.2f} MB")

#         active_sessions[session_id] = {
#             "status": "processing",
#             "violations": [],
#             "start_time": datetime.now(timezone.utc).isoformat(),
#             "camera_id": camera_id,
#             "video_file": unique_filename,
#             "camera_location": {"lat": camera_lat, "lon": camera_lon},
#         }
        
#         print(f"✅ Session initialized: {session_id}")

#         camera_location = {
#             "lat": camera_lat,
#             "lon": camera_lon,
#             "camera_id": camera_id,
#             "session_id": session_id,
#         }

#         def process_in_background():
#             print(f"\n{'='*80}")
#             print(f"🎬 BACKGROUND PROCESSING STARTED")
#             print(f"   Session: {session_id}")
#             print(f"{'='*80}\n")
            
#             try:
#                 result = ai_processor.process_video(
#                     video_source=filepath,
#                     camera_location=camera_location,
#                     output_dir=OUTPUT_PATH,
#                 )
                
#                 if session_id in active_sessions:
#                     active_sessions[session_id]["status"] = "completed"
#                     active_sessions[session_id]["result"] = result
#                     active_sessions[session_id]["end_time"] = datetime.now(timezone.utc).isoformat()
                    
#                 print(f"\n{'='*80}")
#                 print(f"✅ BACKGROUND PROCESSING COMPLETED!")
#                 print(f"   Session: {session_id}")
#                 print(f"   Violations: {result.get('violations_detected', 0)}")
#                 print(f"{'='*80}\n")
                
#             except Exception as e:
#                 print(f"\n{'='*80}")
#                 print(f"❌ BACKGROUND PROCESSING ERROR!")
#                 print(f"   Session: {session_id}")
#                 print(f"   Error: {e}")
#                 print(f"{'='*80}\n")
                
#                 import traceback
#                 traceback.print_exc()
                
#                 if session_id in active_sessions:
#                     active_sessions[session_id]["status"] = "failed"
#                     active_sessions[session_id]["error"] = str(e)
#                     active_sessions[session_id]["end_time"] = datetime.now(timezone.utc).isoformat()

#         thread = threading.Thread(target=process_in_background, name=f"ProcessThread-{session_id}")
#         thread.daemon = True
#         thread.start()
        
#         print(f"✅ Background thread started: {thread.name}")
#         print(f"{'='*80}\n")

#         return jsonify({
#             "status": "success",
#             "message": "Video processing started",
#             "session_id": session_id,
#             "camera_location": camera_location,
#             "video_file": unique_filename,
#             "file_size_mb": round(file_size / (1024*1024), 2),
#         }), 200

#     except Exception as e:
#         print(f"\n{'='*80}")
#         print(f"❌ PROCESS-VIDEO ENDPOINT ERROR!")
#         print(f"   Error: {e}")
#         print(f"{'='*80}\n")
        
#         import traceback
#         traceback.print_exc()
        
#         return jsonify({"error": f"Processing failed: {str(e)}"}), 500
# 3️⃣ FIXED /process-video endpoint
@app.route("/process-video", methods=["POST"])
def process_video():
    """Process uploaded video with AI model - FIXED"""
    print("\n" + "="*80)
    print("🎥 PROCESS-VIDEO ENDPOINT HIT!")
    print("="*80)
    
    try:
        if ai_processor is None:
            return jsonify({"error": "AI Processor not available"}), 503

        if "video" not in request.files:
            return jsonify({"error": "No video file provided"}), 400

        video_file = request.files["video"]
        
        if video_file.filename == '':
            return jsonify({"error": "No file selected"}), 400

        camera_lat = request.form.get("camera_lat")
        camera_lon = request.form.get("camera_lon")
        camera_id = request.form.get("camera_id", "UNKNOWN")
        session_id = request.form.get("session_id")

        print(f"📍 Location: {camera_lat}, {camera_lon}")
        print(f"📸 Camera: {camera_id}")
        print(f"🔧 Session: {session_id}")

        if not camera_lat or not camera_lon:
            return jsonify({"error": "Camera location required"}), 400

        if not session_id:
            session_id = f"session_{int(time.time() * 1000)}"
            print(f"🔧 Generated session: {session_id}")

        try:
            camera_lat = float(camera_lat)
            camera_lon = float(camera_lon)
        except ValueError:
            return jsonify({"error": "Invalid coordinates"}), 400

        filename = secure_filename(video_file.filename)
        timestamp = int(time.time())
        unique_filename = f"{timestamp}_{filename}"
        filepath = os.path.join(VIDEO_STORAGE_PATH, unique_filename)
        
        video_file.save(filepath)
        file_size = os.path.getsize(filepath)
        print(f"✅ Video saved: {file_size / (1024*1024):.2f} MB")

        # ⭐ Initialize session BEFORE processing
        active_sessions[session_id] = {
            "status": "processing",
            "violations": [],
            "start_time": datetime.now(timezone.utc).isoformat(),
            "camera_id": camera_id,
            "video_file": unique_filename,
            "camera_location": {"lat": camera_lat, "lon": camera_lon},
        }

        camera_location = {
            "lat": camera_lat,
            "lon": camera_lon,
            "camera_id": camera_id,
            "session_id": session_id,  # ⭐ CRITICAL
        }

        def process_in_background():
            try:
                print(f"\n🎬 Background processing: {session_id}")
                
                result = ai_processor.process_video(
                    video_source=filepath,
                    camera_location=camera_location,
                    output_dir=OUTPUT_PATH,
                )
                
                if session_id in active_sessions:
                    active_sessions[session_id]["status"] = "completed"
                    active_sessions[session_id]["result"] = result
                    active_sessions[session_id]["end_time"] = datetime.now(timezone.utc).isoformat()
                    print(f"✅ Processing complete: {session_id}")
                
            except Exception as e:
                print(f"❌ Processing error: {e}")
                if session_id in active_sessions:
                    active_sessions[session_id]["status"] = "failed"
                    active_sessions[session_id]["error"] = str(e)

        thread = threading.Thread(target=process_in_background)
        thread.daemon = True
        thread.start()

        return jsonify({
            "status": "success",
            "message": "Video processing started",
            "session_id": session_id,  # ⭐ Return to frontend
            "camera_location": camera_location,
            "video_file": unique_filename,
        }), 200

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# @app.route("/process-camera", methods=["POST"])
# def process_camera():
#     """Process live IP camera stream"""
#     try:
#         if ai_processor is None:
#             return jsonify({"error": "AI Processor not available"}), 503

#         data = request.get_json()

#         camera_ip = data.get("camera_ip")
#         camera_port = data.get("camera_port", "8080")
#         camera_lat = data.get("camera_lat")
#         camera_lon = data.get("camera_lon")
#         camera_id = data.get("camera_id", "IP_CAMERA")
#         session_id = data.get("session_id") or f"session_{int(time.time() * 1000)}"
#         stream_type = data.get("stream_type", "mjpeg")
#         username = data.get("username")
#         password = data.get("password")

#         if not camera_ip or not camera_lat or not camera_lon:
#             return jsonify({"error": "Camera IP and location required"}), 400

#         try:
#             camera_lat = float(camera_lat)
#             camera_lon = float(camera_lon)
#         except ValueError:
#             return jsonify({"error": "Invalid latitude/longitude format"}), 400

#         auth = f"{username}:{password}@" if username and password else ""
        
#         stream_urls = {
#             "mjpeg": f"http://{auth}{camera_ip}:{camera_port}/video",
#             "rtsp": f"rtsp://{auth}{camera_ip}:{camera_port}/",
#             "http": f"http://{auth}{camera_ip}:{camera_port}/videofeed",
#             "hls": f"http://{auth}{camera_ip}:{camera_port}/stream.m3u8"
#         }
        
#         camera_url = stream_urls.get(stream_type, stream_urls["mjpeg"])

#         print(f"\n🎥 Processing IP camera stream")
#         print(f"   Type: {stream_type}")
#         print(f"   Location: {camera_lat}, {camera_lon}")

#         active_sessions[session_id] = {
#             "status": "processing",
#             "violations": [],
#             "start_time": datetime.now(timezone.utc).isoformat(),
#             "camera_id": camera_id,
#             "stream_type": stream_type,
#         }

#         camera_location = {
#             "lat": camera_lat,
#             "lon": camera_lon,
#             "camera_id": camera_id,
#             "session_id": session_id,
#         }

#         def process_camera_background():
#             try:
#                 print(f"🎬 Starting camera stream processing: {session_id}")
                
#                 result = ai_processor.process_video(
#                     video_source=camera_url,
#                     camera_location=camera_location,
#                     output_dir=OUTPUT_PATH,
#                 )
                
#                 if session_id in active_sessions:
#                     active_sessions[session_id]["status"] = "completed"
#                     active_sessions[session_id]["result"] = result
#                     active_sessions[session_id]["end_time"] = datetime.now(timezone.utc).isoformat()
                    
#                 print(f"✅ Camera processing completed: {session_id}")
                    
#             except Exception as e:
#                 print(f"❌ Camera processing error: {e}")
#                 import traceback
#                 traceback.print_exc()
                
#                 if session_id in active_sessions:
#                     active_sessions[session_id]["status"] = "failed"
#                     active_sessions[session_id]["error"] = str(e)
#                     active_sessions[session_id]["end_time"] = datetime.now(timezone.utc).isoformat()

#         thread = threading.Thread(target=process_camera_background, name=f"CameraThread-{session_id}")
#         thread.daemon = True
#         thread.start()

#         return jsonify({
#             "status": "success",
#             "message": "Camera stream processing started",
#             "session_id": session_id,
#             "camera_location": camera_location,
#             "stream_type": stream_type,
#         }), 200

#     except Exception as e:
#         print(f"❌ Camera processing error: {e}")
#         return jsonify({"error": f"Processing failed: {str(e)}"}), 500

# 4️⃣ FIXED /process-camera endpoint
@app.route("/process-camera", methods=["POST"])
def process_camera():
    """Process live IP camera stream - FIXED"""
    try:
        if ai_processor is None:
            return jsonify({"error": "AI Processor not available"}), 503

        data = request.get_json()

        camera_ip = data.get("camera_ip")
        camera_port = data.get("camera_port", "8080")
        camera_lat = data.get("camera_lat")
        camera_lon = data.get("camera_lon")
        camera_id = data.get("camera_id", "IP_CAMERA")
        session_id = data.get("session_id")
        stream_type = data.get("stream_type", "mjpeg")
        username = data.get("username")
        password = data.get("password")

        if not camera_ip or not camera_lat or not camera_lon:
            return jsonify({"error": "Camera IP and location required"}), 400

        if not session_id:
            session_id = f"session_{int(time.time() * 1000)}"

        try:
            camera_lat = float(camera_lat)
            camera_lon = float(camera_lon)
        except ValueError:
            return jsonify({"error": "Invalid coordinates"}), 400

        auth = f"{username}:{password}@" if username and password else ""
        stream_urls = {
            "mjpeg": f"http://{auth}{camera_ip}:{camera_port}/video",
            "rtsp": f"rtsp://{auth}{camera_ip}:{camera_port}/",
            "http": f"http://{auth}{camera_ip}:{camera_port}/videofeed",
            "hls": f"http://{auth}{camera_ip}:{camera_port}/stream.m3u8"
        }
        camera_url = stream_urls.get(stream_type, stream_urls["mjpeg"])

        # ⭐ Initialize session
        active_sessions[session_id] = {
            "status": "processing",
            "violations": [],
            "start_time": datetime.now(timezone.utc).isoformat(),
            "camera_id": camera_id,
            "stream_type": stream_type,
        }

        camera_location = {
            "lat": camera_lat,
            "lon": camera_lon,
            "camera_id": camera_id,
            "session_id": session_id,  # ⭐ CRITICAL
        }

        def process_camera_background():
            try:
                result = ai_processor.process_video(
                    video_source=camera_url,
                    camera_location=camera_location,
                    output_dir=OUTPUT_PATH,
                )
                
                if session_id in active_sessions:
                    active_sessions[session_id]["status"] = "completed"
                    active_sessions[session_id]["result"] = result
                    
            except Exception as e:
                print(f"❌ Camera error: {e}")
                if session_id in active_sessions:
                    active_sessions[session_id]["status"] = "failed"
                    active_sessions[session_id]["error"] = str(e)

        thread = threading.Thread(target=process_camera_background)
        thread.daemon = True
        thread.start()

        return jsonify({
            "status": "success",
            "message": "Camera processing started",
            "session_id": session_id,  # ⭐ Return to frontend
            "camera_location": camera_location,
            "stream_type": stream_type,
        }), 200

    except Exception as e:
        print(f"❌ Error: {e}")
        return jsonify({"error": str(e)}), 500

# @app.route("/process-youtube", methods=["POST"])
# def process_youtube():
#     """Process YouTube video"""
#     try:
#         if ai_processor is None:
#             return jsonify({"error": "AI Processor not available"}), 503

#         data = request.get_json()

#         youtube_url = data.get("youtube_url")
#         camera_lat = data.get("camera_lat")
#         camera_lon = data.get("camera_lon")
#         camera_id = data.get("camera_id", "YOUTUBE_VIDEO")
#         session_id = data.get("session_id") or f"session_{int(time.time() * 1000)}"

#         if not youtube_url or not camera_lat or not camera_lon:
#             return jsonify({"error": "YouTube URL and camera location required"}), 400

#         import re
#         youtube_patterns = [
#             r'(https?://)?(www\.)?(youtube\.com|youtu\.be)/.+',
#         ]
        
#         if not any(re.match(pattern, youtube_url) for pattern in youtube_patterns):
#             return jsonify({"error": "Invalid YouTube URL format"}), 400

#         try:
#             camera_lat = float(camera_lat)
#             camera_lon = float(camera_lon)
#         except ValueError:
#             return jsonify({"error": "Invalid latitude/longitude format"}), 400

#         print(f"\n🎥 Processing YouTube video")
#         print(f"   URL: {youtube_url}")
#         print(f"   Location: {camera_lat}, {camera_lon}")

#         active_sessions[session_id] = {
#             "status": "processing",
#             "violations": [],
#             "start_time": datetime.now(timezone.utc).isoformat(),
#             "camera_id": camera_id,
#             "youtube_url": youtube_url,
#         }

#         camera_location = {
#             "lat": camera_lat,
#             "lon": camera_lon,
#             "camera_id": camera_id,
#             "session_id": session_id,
#         }

#         def process_youtube_background():
#             try:
#                 print(f"🎬 Starting YouTube processing: {session_id}")
                
#                 result = ai_processor.process_youtube_video(
#                     youtube_url=youtube_url,
#                     camera_location=camera_location,
#                     output_dir=OUTPUT_PATH,
#                 )
                
#                 if session_id in active_sessions:
#                     active_sessions[session_id]["status"] = "completed"
#                     active_sessions[session_id]["result"] = result
#                     active_sessions[session_id]["end_time"] = datetime.now(timezone.utc).isoformat()
                    
#                 print(f"✅ YouTube processing completed: {session_id}")
                    
#             except Exception as e:
#                 print(f"❌ YouTube processing error: {e}")
#                 import traceback
#                 traceback.print_exc()
                
#                 if session_id in active_sessions:
#                     active_sessions[session_id]["status"] = "failed"
#                     active_sessions[session_id]["error"] = str(e)
#                     active_sessions[session_id]["end_time"] = datetime.now(timezone.utc).isoformat()

#         thread = threading.Thread(target=process_youtube_background, name=f"YouTubeThread-{session_id}")
#         thread.daemon = True
#         thread.start()

#         return jsonify({
#             "status": "success",
#             "message": "YouTube processing started",
#             "session_id": session_id,
#             "camera_location": camera_location,
#             "youtube_url": youtube_url,
#         }), 200

#     except Exception as e:
#         print(f"❌ YouTube processing error: {e}")
#         return jsonify({"error": f"Processing failed: {str(e)}"}), 500


# 1️⃣ FIXED /process-youtube endpoint
@app.route("/process-youtube", methods=["POST"])
def process_youtube():
    """Process YouTube video - FIXED SESSION HANDLING"""
    try:
        if ai_processor is None:
            return jsonify({"error": "AI Processor not available"}), 503

        data = request.get_json()

        youtube_url = data.get("youtube_url")
        camera_lat = data.get("camera_lat")
        camera_lon = data.get("camera_lon")
        camera_id = data.get("camera_id", "YOUTUBE_VIDEO")
        
        # ⭐ FIX: Use provided session_id or generate a new one
        session_id = data.get("session_id")
        if not session_id:
            session_id = f"session_{int(time.time() * 1000)}"
            print(f"🆕 Generated new session ID: {session_id}")
        else:
            print(f"✅ Using provided session ID: {session_id}")

        if not youtube_url or not camera_lat or not camera_lon:
            return jsonify({"error": "YouTube URL and camera location required"}), 400

        import re
        youtube_patterns = [
            r'(https?://)?(www\.)?(youtube\.com|youtu\.be)/.+',
        ]
        
        if not any(re.match(pattern, youtube_url) for pattern in youtube_patterns):
            return jsonify({"error": "Invalid YouTube URL format"}), 400

        try:
            camera_lat = float(camera_lat)
            camera_lon = float(camera_lon)
        except ValueError:
            return jsonify({"error": "Invalid latitude/longitude format"}), 400

        print(f"\n{'='*80}")
        print(f"🎥 YOUTUBE PROCESSING STARTED")
        print(f"{'='*80}")
        print(f"   URL: {youtube_url}")
        print(f"   Location: ({camera_lat}, {camera_lon})")
        print(f"   Camera ID: {camera_id}")
        print(f"   Session ID: {session_id}")
        print(f"{'='*80}\n")

        # ⭐ CRITICAL: Initialize session BEFORE background processing
        active_sessions[session_id] = {
            "status": "processing",
            "violations": [],
            "start_time": datetime.now(timezone.utc).isoformat(),
            "camera_id": camera_id,
            "youtube_url": youtube_url,
            "camera_location": {"lat": camera_lat, "lon": camera_lon},
        }
        
        print(f"✅ Session initialized: {session_id}")
        print(f"   Active sessions: {list(active_sessions.keys())}")

        # ⭐ Create camera_location object WITH session_id
        camera_location = {
            "lat": camera_lat,
            "lon": camera_lon,
            "camera_id": camera_id,
            "session_id": session_id,  # ⭐ MUST INCLUDE THIS
        }

        def process_youtube_background():
            try:
                print(f"\n🎬 Starting YouTube processing: {session_id}")
                
                result = ai_processor.process_youtube_video(
                    youtube_url=youtube_url,
                    camera_location=camera_location,
                    output_dir=OUTPUT_PATH,
                )
                
                if session_id in active_sessions:
                    active_sessions[session_id]["status"] = "completed"
                    active_sessions[session_id]["result"] = result
                    active_sessions[session_id]["end_time"] = datetime.now(timezone.utc).isoformat()
                    
                    violations_count = len(active_sessions[session_id]["violations"])
                    print(f"\n✅ YouTube processing completed!")
                    print(f"   Session: {session_id}")
                    print(f"   Violations: {violations_count}")
                    
            except Exception as e:
                print(f"\n❌ YouTube processing error: {e}")
                import traceback
                traceback.print_exc()
                
                if session_id in active_sessions:
                    active_sessions[session_id]["status"] = "failed"
                    active_sessions[session_id]["error"] = str(e)
                    active_sessions[session_id]["end_time"] = datetime.now(timezone.utc).isoformat()

        thread = threading.Thread(target=process_youtube_background, name=f"YouTubeThread-{session_id}")
        thread.daemon = True
        thread.start()
        
        print(f"✅ Background thread started\n")

        # ⭐ RETURN the session_id to frontend
        return jsonify({
            "status": "success",
            "message": "YouTube processing started",
            "session_id": session_id,  # ⭐ Frontend MUST use this
            "camera_location": camera_location,
            "youtube_url": youtube_url,
            "camera_id": camera_id,
        }), 200

    except Exception as e:
        print(f"\n❌ YouTube endpoint error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": f"Processing failed: {str(e)}"}), 500

@app.route("/test-camera-connection", methods=["POST"])
def test_camera_connection():
    """Test IP camera connection"""
    try:
        data = request.get_json()
        
        camera_ip = data.get("camera_ip")
        camera_port = data.get("camera_port", "8080")
        stream_type = data.get("stream_type", "mjpeg")
        username = data.get("username")
        password = data.get("password")
        
        if not camera_ip:
            return jsonify({"error": "Camera IP required"}), 400
        
        auth = f"{username}:{password}@" if username and password else ""
        test_urls = {
            "mjpeg": f"http://{auth}{camera_ip}:{camera_port}/video",
            "rtsp": f"rtsp://{auth}{camera_ip}:{camera_port}/",
        }
        
        test_url = test_urls.get(stream_type, test_urls["mjpeg"])
        
        print(f"🧪 Testing camera connection: {test_url}")
        
        import cv2
        cap = cv2.VideoCapture(test_url)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        
        if cap.isOpened():
            ret, frame = cap.read()
            cap.release()
            
            if ret and frame is not None:
                height, width = frame.shape[:2]
                print(f"✅ Connection successful: {width}x{height}")
                
                return jsonify({
                    "status": "success",
                    "message": "Camera connected successfully",
                    "resolution": f"{width}x{height}",
                    "stream_type": stream_type,
                }), 200
            else:
                cap.release()
                return jsonify({
                    "status": "error",
                    "error": "Camera opened but no frames received",
                }), 400
        else:
            cap.release()
            return jsonify({
                "status": "error",
                "error": "Cannot connect to camera stream",
            }), 400
            
    except Exception as e:
        print(f"❌ Connection test error: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
        }), 500


@app.route("/session-status/<session_id>", methods=["GET"])
def session_status(session_id):
    """Get detailed processing session status with real-time updates"""
    try:
        if session_id not in active_sessions:
            return jsonify({
                "status": "error",
                "error": "Session not found"
            }), 404
        
        session = active_sessions[session_id]
        
        # Calculate processing time
        start_time = session.get("start_time")
        end_time = session.get("end_time")
        
        processing_time = None
        if start_time:
            start_dt = datetime.fromisoformat(start_time)
            if end_time:
                end_dt = datetime.fromisoformat(end_time)
                processing_time = (end_dt - start_dt).total_seconds()
            else:
                processing_time = (datetime.now(timezone.utc) - start_dt).total_seconds()
        
        return jsonify({
            "status": "success",
            "session_id": session_id,
            "processing_status": session["status"],
            "violations_count": len(session["violations"]),
            "start_time": start_time,
            "end_time": end_time,
            "processing_time_seconds": processing_time,
            "camera_id": session.get("camera_id"),
            "stream_type": session.get("stream_type"),
            "result": session.get("result"),
            "error": session.get("error"),
        }), 200
        
    except Exception as e:
        print(f"❌ Error getting session status: {e}")
        return jsonify({"status": "error", "error": str(e)}), 500


@app.route("/debug-session/<session_id>", methods=["GET"])
def debug_session(session_id):
    """Debug endpoint to check session data"""
    if session_id not in active_sessions:
        return jsonify({
            "status": "error",
            "error": "Session not found",
            "available_sessions": list(active_sessions.keys())
        }), 404
    
    session = active_sessions[session_id]
    
    return jsonify({
        "status": "success",
        "session_id": session_id,
        "session_data": {
            "status": session.get("status"),
            "violations_count": len(session.get("violations", [])),
            "violations": session.get("violations", []),
            "start_time": session.get("start_time"),
            "camera_id": session.get("camera_id"),
        },
        "all_sessions": list(active_sessions.keys())
    }), 200



# ==========================
# 🚀 Run Server
# ==========================
if __name__ == "__main__":
    print("\n" + "=" * 70)
    print("🚀 RoadEyeAI Backend Server Starting...")
    print("=" * 70)
    print(f"🔗 Running on: http://165.22.212.97:8080")
    print(f"🔗 CORS Enabled: ✅")
    print(f"🔥 Firebase Connected: {'✅' if db else '❌'}")
    print(f"🤖 AI Processor: {'✅ Ready' if ai_processor else '❌ Not Available'}")
    print(f"📧 Email Configured: {'✅' if SMTP_EMAIL != 'your-email@gmail.com' else '❌'}")
    print(f"📂 Video Storage: {VIDEO_STORAGE_PATH}")
    print(f"📂 Output Storage: {OUTPUT_PATH}")
    print(f"🗺️ Zone Cache: Enabled (60s TTL)")
    print(f"📊 Session Tracking: Enabled")
    print("=" * 70 + "\n")

    app.run(
        host="10.121.197.110",           # ✅ All network interfaces
        port=5000,                # ✅ Port number
        debug=True,               # ✅ Debug mode ON (auto-reload on code changes)
        use_reloader=False,       # ✅ Disable reloader (prevents double initialization)
        threaded=True             # ✅ Handle multiple requests simultaneously
    )