from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 1024
OUT_DIR = Path('assets/branding')
OUT_DIR.mkdir(parents=True, exist_ok=True)


def draw_diagonal_gradient(size: int, c1: tuple[int, int, int], c2: tuple[int, int, int]) -> Image.Image:
    img = Image.new('RGB', (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            r = int(c1[0] * (1 - t) + c2[0] * t)
            g = int(c1[1] * (1 - t) + c2[1] * t)
            b = int(c1[2] * (1 - t) + c2[2] * t)
            px[x, y] = (r, g, b)
    return img.convert('RGBA')


def rounded_rect_layer(size: int, box: tuple[int, int, int, int], radius: int, color: tuple[int, int, int, int]) -> Image.Image:
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle(box, radius=radius, fill=color)
    return layer


def add_symbol(base: Image.Image) -> Image.Image:
    size = base.width
    symbol = Image.new('RGBA', (size, size), (0, 0, 0, 0))

    # soft glow behind symbol
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse((150, 130, 900, 900), fill=(255, 255, 255, 34))
    glow = glow.filter(ImageFilter.GaussianBlur(20))
    symbol = Image.alpha_composite(symbol, glow)

    # left and right book pages (slight perspective)
    left = rounded_rect_layer(size, (258, 236, 505, 812), 82, (255, 255, 255, 248)).rotate(
        -5, resample=Image.Resampling.BICUBIC, center=(382, 524)
    )
    right = rounded_rect_layer(size, (518, 236, 766, 812), 82, (255, 255, 255, 248)).rotate(
        5, resample=Image.Resampling.BICUBIC, center=(642, 524)
    )

    # drop shadows
    left_shadow = left.filter(ImageFilter.GaussianBlur(10))
    right_shadow = right.filter(ImageFilter.GaussianBlur(10))
    left_shadow = ImageChops.offset(left_shadow, 0, 8)
    right_shadow = ImageChops.offset(right_shadow, 0, 8)

    shadow_tint = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow_tint.paste((17, 42, 70, 58), mask=left_shadow.split()[-1])
    symbol = Image.alpha_composite(symbol, shadow_tint)
    shadow_tint = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow_tint.paste((17, 42, 70, 58), mask=right_shadow.split()[-1])
    symbol = Image.alpha_composite(symbol, shadow_tint)

    symbol = Image.alpha_composite(symbol, left)
    symbol = Image.alpha_composite(symbol, right)

    d = ImageDraw.Draw(symbol)

    # spine highlight
    d.rounded_rectangle((492, 246, 532, 804), radius=20, fill=(227, 239, 247, 255))

    # page lines
    for i in range(5):
        y = 340 + i * 86
        d.rounded_rectangle((304, y, 454, y + 16), radius=8, fill=(222, 235, 244, 255))
    for i in range(5):
        y = 340 + i * 86
        d.rounded_rectangle((570, y, 720, y + 16), radius=8, fill=(222, 235, 244, 255))

    # source nodes accent (modern network hint)
    d.line((690, 248, 786, 188), fill=(255, 255, 255, 220), width=14)
    d.line((764, 236, 862, 266), fill=(255, 255, 255, 220), width=14)
    d.ellipse((752, 176, 822, 246), fill=(255, 255, 255, 245))
    d.ellipse((838, 242, 904, 308), fill=(255, 255, 255, 245))
    d.ellipse((720, 216, 786, 282), fill=(255, 255, 255, 245))

    # active source node
    d.ellipse((740, 196, 802, 258), fill=(34, 197, 146, 255))

    return Image.alpha_composite(base, symbol)


def create_background() -> Image.Image:
    bg = draw_diagonal_gradient(SIZE, (19, 64, 116), (15, 138, 173))

    # warm accent blob for contrast
    blob = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(blob)
    d.ellipse((590, -80, 1140, 480), fill=(251, 146, 60, 120))
    d.ellipse((-180, 640, 340, 1160), fill=(56, 189, 248, 80))
    blob = blob.filter(ImageFilter.GaussianBlur(40))
    return Image.alpha_composite(bg, blob)


def create_foreground() -> Image.Image:
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(fg)

    # cleaner symbol for adaptive foreground
    d.rounded_rectangle((280, 236, 498, 804), radius=76, fill=(255, 255, 255, 255))
    d.rounded_rectangle((526, 236, 744, 804), radius=76, fill=(255, 255, 255, 255))
    d.rounded_rectangle((492, 246, 532, 804), radius=20, fill=(232, 239, 245, 255))

    for i in range(5):
        y = 340 + i * 86
        d.rounded_rectangle((324, y, 450, y + 14), radius=7, fill=(226, 237, 245, 255))
    for i in range(5):
        y = 340 + i * 86
        d.rounded_rectangle((572, y, 698, y + 14), radius=7, fill=(226, 237, 245, 255))

    d.line((684, 248, 776, 192), fill=(255, 255, 255, 240), width=12)
    d.line((754, 234, 844, 262), fill=(255, 255, 255, 240), width=12)
    d.ellipse((744, 184, 810, 250), fill=(255, 255, 255, 255))
    d.ellipse((824, 238, 886, 300), fill=(255, 255, 255, 255))
    d.ellipse((714, 210, 776, 272), fill=(255, 255, 255, 255))
    d.ellipse((736, 196, 796, 256), fill=(34, 197, 146, 255))

    return fg


def main() -> None:
    app_icon = add_symbol(create_background())
    app_icon.save(OUT_DIR / 'app_icon.png')

    fg = create_foreground()
    fg.save(OUT_DIR / 'app_icon_foreground.png')

    print('Generated V2 icons:')
    print(OUT_DIR / 'app_icon.png')
    print(OUT_DIR / 'app_icon_foreground.png')


if __name__ == '__main__':
    main()
