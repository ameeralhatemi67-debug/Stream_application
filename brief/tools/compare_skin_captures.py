# Compares two folders of screen pictures made by
# project/test/skin_regression_capture_test.dart (or any two folders of PNG
# files with the same names), pixel by pixel.
#
# usage: python brief/tools/compare_skin_captures.py <before> <after> [--diff <folder>] [--sheet <folder>]
#
# Prints one line per file and a total. Exit code 1 when any picture differs
# or a file is missing on one side. With --diff, writes a picture of each
# difference (changed pixels in red over a faded copy). With --sheet, writes
# before and after side by side for every file, for a report.
import os
import sys

from PIL import Image, ImageChops


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        sys.exit(__doc__ or 'usage: compare_skin_captures.py <before> <after>')
    before, after = args[0], args[1]
    diff_dir = args[args.index('--diff') + 1] if '--diff' in args else None
    sheet_dir = args[args.index('--sheet') + 1] if '--sheet' in args else None
    for folder in (diff_dir, sheet_dir):
        if folder:
            os.makedirs(folder, exist_ok=True)
    names = sorted({f for f in os.listdir(before) if f.endswith('.png')} |
                   {f for f in os.listdir(after) if f.endswith('.png')})
    changed = missing = 0
    for name in names:
        a_path, b_path = os.path.join(before, name), os.path.join(after, name)
        if not os.path.exists(a_path) or not os.path.exists(b_path):
            missing += 1
            print(f'MISSING  {name} ({"before" if not os.path.exists(a_path) else "after"})')
            continue
        a, b = Image.open(a_path).convert('RGB'), Image.open(b_path).convert('RGB')
        if a.size != b.size:
            changed += 1
            print(f'DIFFERENT {name}: size {a.size} -> {b.size}')
        else:
            box = ImageChops.difference(a, b).getbbox()
            if box is None:
                print(f'same      {name}')
            else:
                changed += 1
                mask = ImageChops.difference(a, b).convert('L').point(lambda v: 255 if v else 0)
                count = sum(1 for v in mask.getdata() if v)
                print(f'DIFFERENT {name}: {count} pixels, inside {box}')
                if diff_dir:
                    faded = Image.blend(b, Image.new('RGB', b.size, (255, 255, 255)), .7)
                    faded.paste((220, 0, 0), mask=mask)
                    faded.save(os.path.join(diff_dir, name))
        if sheet_dir:
            width, height = a.width + b.width + 24, max(a.height, b.height)
            sheet = Image.new('RGB', (width, height), (255, 255, 255))
            sheet.paste(a, (0, 0))
            sheet.paste(b, (a.width + 24, 0))
            sheet.save(os.path.join(sheet_dir, name))
    print(f'{len(names)} pictures: {len(names) - changed - missing} same, '
          f'{changed} different, {missing} missing')
    sys.exit(1 if changed or missing else 0)


if __name__ == '__main__':
    main()
