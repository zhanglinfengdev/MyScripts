import os
import subprocess
import ipaddress

# 设置IP范围
network = ipaddress.ip_network('192.168.1.0/24')

# 扫描IP范围内的设备
for ip in network.hosts():
    try:
        response = subprocess.run(['ping', '-c', '1', str(ip)], stdout=subprocess.DEVNULL)
        if response.returncode == 0:
            print(f"设备发现: {ip}")
            try:
                # 尝试ADB连接
                adb_response = subprocess.run(['adb', 'connect', str(ip)], stdout=subprocess.PIPE)
                if "connected" in adb_response.stdout.decode():
                    print(f"成功连接到 {ip}")
            except Exception as e:
                print(f"无法连接到 {ip}: {e}")
    except Exception as e:
        print(f"扫描错误: {e}")

