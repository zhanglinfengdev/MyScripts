import capture_screen
import find_element_on_screen
import tap


if __name__ == "__main__":
    capture_screen.capture_screen()
    element = find_element_on_screen.find_element_on_screen('/Users/didi/scripts/androidUITest/2024-05-08_19-16.png', '/Users/didi/scripts/androidUITest/screen.png')
    print(element)
    tap.tap(element[0],element[1])
