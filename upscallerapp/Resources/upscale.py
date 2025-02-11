import sys
import os
from PIL import Image
import torch
from torch.backends import cudnn
from basicsr.utils.download_util import load_file_from_url
from basicsr.utils import imwrite
from realesrgan import RealESRGANer
from realesrgan.archs.srvgg_arch import SRVGGNetCompact

def log_progress(message):
    print(f"PROGRESS: {message}", flush=True)

def upscale_image(input_path, output_path, scale=2):
    try:
        log_progress("Инициализация модели...")
        # Initialize model
        model = SRVGGNetCompact(num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=16, upscale=4, act_type='prelu')
        model_path = os.path.join(os.path.dirname(__file__), 'realesr-animevideov3.pth')
        
        if not os.path.exists(model_path):
            log_progress("Загрузка модели...")
            model_url = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesr-animevideov3.pth'
            load_file_from_url(model_url, model_dir=os.path.dirname(__file__))
        
        log_progress("Загрузка модели...")
        # Load model
        upsampler = RealESRGANer(
            scale=4,
            model_path=model_path,
            model=model,
            tile=0,
            tile_pad=10,
            pre_pad=0,
            half=True
        )
        
        log_progress("Загрузка изображения...")
        # Read and process image
        img = Image.open(input_path)
        
        log_progress("Обработка изображения...")
        output = upsampler.enhance(img, outscale=scale)[0]
        
        log_progress("Сохранение результата...")
        # Save result
        imwrite(output, output_path)
        
        log_progress("Готово!")
        return True
    except Exception as e:
        print(f"ERROR: {str(e)}", flush=True)
        return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python upscale.py input_path output_path [scale]")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    scale = int(sys.argv[3]) if len(sys.argv) > 3 else 2
    
    success = upscale_image(input_path, output_path, scale)
    sys.exit(0 if success else 1) 