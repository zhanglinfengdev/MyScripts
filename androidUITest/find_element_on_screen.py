import cv2
import numpy as np

def find_element_on_screen(element_image_path, screen_image_path):
    """在屏幕截图中查找元素"""
    screen = cv2.imread(screen_image_path, cv2.IMREAD_GRAYSCALE)
    template = cv2.imread(element_image_path, cv2.IMREAD_GRAYSCALE)
    w, h = template.shape[::-1]

    res = cv2.matchTemplate(screen, template, cv2.TM_CCOEFF_NORMED)
    threshold = 0.8
    loc = np.where(res >= threshold)

    print(loc)
    if loc[0].size and loc[1].size:
        pt = loc[1][0], loc[0][0]
        return (pt[0] + w/2, pt[1] + h/2)  # 返回元素中心点
    return None

if __name__ == "__main__":
    # 示例：寻找屏幕上的元素并获取其坐标
    element_location = find_element_on_screen('/Users/didi/scripts/androidUITest/2024-05-08_19-16.png', 'screen.png')
