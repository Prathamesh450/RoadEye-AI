import cv2

cap = cv2.VideoCapture(0)
if cap.isOpened():
    print("✅ Webcam is working!")
    ret, frame = cap.read()
    if ret:
        cv2.imshow("Webcam Test", frame)
        cv2.waitKey(3000)  # 3 seconds
else:
    print("❌ Webcam not found")
cap.release()
cv2.destroyAllWindows()