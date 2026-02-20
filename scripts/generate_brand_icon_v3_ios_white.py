from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 1024
OUT_DIR = Path('assets/branding')
OUT_DIR.mkdir(parents=True, exist_ok=True)


def _lerp(a: int, b: int, t: float) -> int:
    return int(a * (1 - t) + b * t)


def build_background() -> Image.Image:
    image = Image.new('RGBA', (SIZE, SIZE), (255, 255, 255, 255))
    draw = ImageDraw.Draw(image)

    top = (245, 249, 255)
    bottom = (255, 255, 255)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        color = (
            _lerp(top[0], bottom[0], t),
            _lerp(top[1], bottom[1], t),
            _lerp(top[2], bottom[2], t),
            255,
        )
        draw.line([(0, y), (SIZE, y)], fill=color)

    # soft top highlight
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse((100, -280, 980, 420), fill=(130, 180, 255, 30))
    glow = glow.filter(ImageFilter.GaussianBlur(48))
    image = Image.alpha_composite(image, glow)

    return image


def build_symbol(with_shadow: bool) -> Image.Image:
    symbol = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))

    body = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)

    # iOS style accent palette
    blue = (10, 132, 255, 255)
    blue_soft = (90, 184, 255, 255)
    cyan = (64, 200, 224, 255)
    green = (48, 209, 88, 255)

    # open-book pages (minimal, smooth)
    d.rounded_rectangle((266, 250, 494, 790), radius=78, fill=blue)
    d.rounded_rectangle((530, 250, 758, 790), radius=78, fill=blue_soft)

    # book spine / split
    d.rounded_rectangle((490, 268, 534, 788), radius=22, fill=(232, 244, 255, 255))

    # page lines
    for i in range(5):
        y = 346 + i * 82
        d.rounded_rectangle((310, y, 450, y + 14), radius=7, fill=(180, 225, 255, 190))
        d.rounded_rectangle((574, y, 714, y + 14), radius=7, fill=(210, 238, 255, 190))

    # source node mark (clean and modern)
    d.line((670, 262, 760, 214), fill=(95, 188, 255, 255), width=12)
    d.line((742, 242, 834, 274), fill=(95, 188, 255, 255), width=12)

    d.ellipse((728, 198, 792, 262), fill=cyan)
    d.ellipse((816, 244, 878, 306), fill=cyan)
    d.ellipse((694, 226, 756, 288), fill=cyan)
    d.ellipse((734, 206, 786, 258), fill=green)

    if with_shadow:
        shadow = body.filter(ImageFilter.GaussianBlur(16))
        shadow = ImageChops.offset(shadow, 0, 12)
        shadow_tint = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        shadow_tint.paste((27, 74, 129, 46), mask=shadow.split()[-1])
        symbol = Image.alpha_composite(symbol, shadow_tint)

    symbol = Image.alpha_composite(symbol, body)
    return symbol


def generate() -> None:
    icon = build_background()
    icon = Image.alpha_composite(icon, build_symbol(with_shadow=True))
    icon.save(OUT_DIR / 'app_icon.png')

    fg = build_symbol(with_shadow=False)
    fg.save(OUT_DIR / 'app_icon_foreground.png')

    print('Generated iOS-style white-base icon set:')
    print(OUT_DIR / 'app_icon.png')
    print(OUT_DIR / 'app_icon_foreground.png')


if __name__ == '__main__':
    generate()
