import subprocess

url = "https://www.youtube.com/live/UemFRPrl1hk?si=hIjOSLsUH3jLudf0"
cmd = ["yt-dlp", "-f", "best", "-g", url]
res = subprocess.run(cmd, capture_output=True, text=True)
print(res.stdout)