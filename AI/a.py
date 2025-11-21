import cv2

for i in range(5):
    cap = cv2.VideoCapture(i)
    if cap.isOpened():
        print(f"Camera {i}: Working")
        ret, frame = cap.read()
        if ret:
            cv2.imshow(f"Camera {i}", frame)
            cv2.waitKey(1000)
        cap.release()
    cv2.destroyAllWindows()