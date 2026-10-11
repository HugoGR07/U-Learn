from PIL import Image
import os, sys

src = sys.argv[1]
img = Image.open(src).convert("RGBA")
alpha = img.split()[3]

if alpha.getextrema()[0] == 255:
    gray = img.convert("L")
    alpha = gray.point(lambda v: 255 - v)

side = max(img.size)
canvas = Image.new("L", (side, side), 0)
canvas.paste(alpha, ((side - img.width) // 2, (side - img.height) // 2))

sizes = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}
base = "android/app/src/main/res"

for density, px in sizes.items():
    folder = os.path.join(base, f"drawable-{density}")
    os.makedirs(folder, exist_ok=True)
    mask = canvas.resize((px, px), Image.LANCZOS)
    out = Image.new("RGBA", (px, px), (255, 255, 255, 0))
    out.putalpha(mask)
    white = Image.new("RGBA", (px, px), (255, 255, 255, 255))
    white.putalpha(mask)
    white.save(os.path.join(folder, "ic_notification.png"))
    print("creado", folder)