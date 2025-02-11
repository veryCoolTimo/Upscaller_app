import sys
import os
import pkg_resources

def check_dependencies():
    required = {
        'torch': '>=1.7.0',
        'basicsr': '>=1.4.2',
        'facexlib': '>=0.2.5',
        'gfpgan': '>=1.3.5',
        'numpy': '>=1.23.5',
        'opencv-python': '>=4.6.0',
        'Pillow': '>=9.3.0',
        'realesrgan': '>=0.3.0'
    }
    
    missing = []
    
    for package, version in required.items():
        try:
            pkg_resources.require(f"{package}{version}")
        except pkg_resources.DistributionNotFound:
            missing.append(package)
        except pkg_resources.VersionConflict:
            print(f"Warning: {package} version conflict")
    
    return missing

def main():
    print(f"Python version: {sys.version}")
    print(f"Python executable: {sys.executable}")
    print(f"Script directory: {os.path.dirname(os.path.abspath(__file__))}")
    
    missing = check_dependencies()
    if missing:
        print(f"Missing packages: {', '.join(missing)}")
        sys.exit(1)
    else:
        print("All required packages are installed")
        sys.exit(0)

if __name__ == '__main__':
    main() 