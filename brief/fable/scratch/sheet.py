# Splits a tall page capture into slices and lays them side by side.
# usage: python sheet.py <png> <outPrefix> [sliceHeight=1150] [columns=4]
import sys
from PIL import Image
src, prefix = sys.argv[1], sys.argv[2]
sh = int(sys.argv[3]) if len(sys.argv) > 3 else 1150
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 4
im = Image.open(src).convert('RGB')
w, h = im.size
slices = [im.crop((0, y, w, min(y + sh, h))) for y in range(0, h, sh)]
n = 0
for i in range(0, len(slices), cols):
    group = slices[i:i + cols]
    sheet = Image.new('RGB', (len(group) * (w + 12) - 12, sh), (120, 120, 120))
    for j, s in enumerate(group):
        sheet.paste(s, (j * (w + 12), 0))
    n += 1
    sheet.save(f'{prefix}-{n}.png')
print(prefix, w, h, 'sheets', n)
