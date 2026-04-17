import re
import socket
import os

def get_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Doesn't even have to be reachable
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def update_file(new_ip):
    path = os.path.join('mobile', 'lib', 'core', 'network', 'api_constants.dart')
    if not os.path.exists(path):
        print(f"Error: {path} not found")
        return

    with open(path, 'r') as f:
        content = f.read()

    # Regex to find IP patterns like 192.168.x.x
    pattern = r'http://\d+\.\d+\.\d+\.\d+:8086'
    replacement = f'http://{new_ip}:8086'
    
    new_content = re.sub(pattern, replacement, content)
    
    with open(path, 'w') as f:
        f.write(new_content)
    
    print(f"Successfully updated {path} with IP: {new_ip}")

if __name__ == "__main__":
    ip = get_ip()
    print(f"Current Machine IP: {ip}")
    update_file(ip)
