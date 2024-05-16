import subprocess

def capture_screen(filename="screen.png"):
    """捕获屏幕截图并保存到本地文件"""
    subprocess.run(["adb", "shell", "screencap", "-p", f"/sdcard/{filename}"])
    subprocess.run(["adb", "pull", f"/sdcard/{filename}", filename])
    subprocess.run(["adb", "shell", "rm", f"/sdcard/{filename}"])

if __name__ == "__main__":
    capture_screen()
