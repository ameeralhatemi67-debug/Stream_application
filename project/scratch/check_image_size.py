import os
from PIL import Image

p = r"C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app\project\assets\images\Amir_Alhatemi\amir_person_pic.jpg"
if os.path.exists(p):
    with Image.open(p) as img:
        print(f"Size: {img.size}, Format: {img.format}, Mode: {img.mode}")
else:
    print("File does not exist")
