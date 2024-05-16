def tap(x, y):
    """模拟屏幕点击"""
    subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)])

if __name__ == "__main__":
    if element_location:
        tap(element_location[0], element_location[1])
