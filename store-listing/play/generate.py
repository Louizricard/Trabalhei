#!/usr/bin/env python3
"""Gera as imagens da ficha da Google Play a partir das capturas em raw/.

Uso (na raiz do repositório ou em qualquer pasta):

    python3 store-listing/play/generate.py

Saídas nesta pasta:
    01-...png a 06-...png  capturas de celular 1080x1920 (RGB)
    feature-graphic.png    gráfico de recursos 1024x500 (RGB)
    icon-512.png           ícone 512x512

Precisa só do Python 3 e do Pillow. As capturas brutas vêm de
freelanceflow/tool/showcase/store.mjs (ver README.md).
"""
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageMath

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
REPO = HERE.parent.parent
ICON_SOURCE = REPO / "freelanceflow" / "assets" / "icons" / "app_logo.png"

# Paleta de freelanceflow/lib/core/theme/app_colors.dart e site/assets/css/site.css.
BG = (8, 26, 47)  # bgDark
SURFACE = (16, 39, 67)  # surfaceDark
BORDER_STRONG = (44, 74, 107)
PRIMARY = (25, 230, 167)
TEXT = (255, 255, 255)
TEXT_SECONDARY = (183, 195, 208)
FRAME = (6, 17, 31)
BEZEL = 0.026  # borda do celular, em fração da largura da tela

# Ordem de conversão. Entre colchetes: palavras em verde no título.
SCREENS = [
    ("01-vagas", "phone-jobs",
     "Contrate freelancers ou [encontre projetos]",
     "Do anúncio à entrega, tudo em um só lugar."),
    ("02-propostas", "phone-proposals",
     "Compare [propostas] na mesma tela",
     "Valor, prazo e carta de cada freelancer."),
    ("03-chat-entregas", "phone-chat",
     "Chat e [entregas por marcos]",
     "Converse, receba arquivos e aprove cada etapa."),
    ("04-sem-comissao", "phone-job-detail",
     "Sem comissão. [O valor é seu.]",
     "Pagamento combinado direto entre as partes."),
    ("05-publicar-vaga", "phone-create-job",
     "Publique sua vaga [em minutos]",
     "Grátis para quem contrata. Receba propostas."),
    ("06-talentos", "phone-freelancers",
     "Encontre o [talento certo]",
     "Busque por habilidade e compare avaliações."),
]

# (captura, largura da tela, inclinação em graus, posição): o de trás primeiro.
FEATURE_PHONES = [
    ("phone-chat", 230, -6, (725, 8)),
    ("phone-jobs", 250, -9, (540, 40)),
]
FEATURE_TAGLINE = ["Contrate freelancers ou", "encontre projetos."]
FEATURE_ACCENT = "Sem comissão sobre o projeto."


# ---------------------------------------------------------------- fontes

def _fc_match(pattern):
    if not shutil.which("fc-match"):
        return None
    out = subprocess.run(["fc-match", "-f", "%{file}", pattern],
                         capture_output=True, text=True, check=False).stdout.strip()
    return out or None


def font_path(weight):
    """Plus Jakarta Sans (fonte do app e do site); sem ela, uma sans do sistema."""
    local = HERE / "fonts" / f"PlusJakartaSans-{weight}.ttf"
    if local.exists():
        return str(local)
    style = "Bold" if weight >= 600 else "Medium"
    for family in ("Plus Jakarta Sans", "Noto Sans", "DejaVu Sans"):
        found = _fc_match(f"{family}:style={style}")
        if found:
            return found
    raise SystemExit("Nenhuma fonte encontrada; coloque PlusJakartaSans-700.ttf em fonts/.")


def font(weight, size):
    return ImageFont.truetype(font_path(weight), size)


# ---------------------------------------------------------------- desenho

def background(w, h, glow_center):
    """Fundo da marca: gradiente vertical azul-marinho com brilho verde suave."""
    grad = Image.linear_gradient("L").resize((w, h))
    top = Image.new("RGB", (w, h), SURFACE)
    base = Image.composite(Image.new("RGB", (w, h), BG), top, grad)
    # Brilho verde (radial) atrás do conteúdo principal.
    size = int(max(w, h) * 1.1)
    radial = Image.radial_gradient("L").resize((size, size))
    # Some antes da borda da imagem, sem faixa visível onde termina o brilho.
    radial = radial.point(lambda v: int(max(0, 200 - v) * 0.28))
    glow = Image.new("L", (w, h), 0)
    glow.paste(radial, (glow_center[0] - size // 2, glow_center[1] - size // 2))
    return Image.composite(Image.new("RGB", (w, h), PRIMARY), base, glow)


def rounded_mask(size, radius, scale=4):
    """Máscara de cantos arredondados com antisserrilhado (desenha 4x e reduz)."""
    w, h = size
    big = Image.new("L", (w * scale, h * scale), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, w * scale - 1, h * scale - 1), radius * scale, fill=255)
    return big.resize((w, h), Image.LANCZOS)


def phone(screen, screen_w):
    """Captura real dentro de uma moldura de celular arredondada, sem marca."""
    sw = screen_w
    sh = round(screen.height * sw / screen.width)
    bezel = max(8, round(sw * BEZEL))
    fw, fh = sw + bezel * 2, sh + bezel * 2
    outer_r = round(fw * 0.105)
    inner_r = outer_r - bezel

    frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    body = Image.new("RGBA", (fw, fh), BORDER_STRONG + (255,))
    frame.paste(body, (0, 0), rounded_mask((fw, fh), outer_r))
    edge = max(2, round(bezel * 0.2))
    inner_body = Image.new("RGBA", (fw - edge * 2, fh - edge * 2), FRAME + (255,))
    frame.paste(inner_body, (edge, edge),
                rounded_mask(inner_body.size, outer_r - edge))
    shot = screen.convert("RGB").resize((sw, sh), Image.LANCZOS)
    frame.paste(shot, (bezel, bezel), rounded_mask((sw, sh), inner_r))
    return frame, outer_r


def drop_shadow(canvas, box, radius, blur, offset, color, alpha):
    """Sombra (ou brilho) desfocada sob um retângulo arredondado."""
    x0, y0, x1, y1 = box
    pad = blur * 3
    layer = Image.new("L", (x1 - x0 + pad * 2, y1 - y0 + pad * 2), 0)
    ImageDraw.Draw(layer).rounded_rectangle(
        (pad, pad, pad + x1 - x0, pad + y1 - y0), radius, fill=int(255 * alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    tint = Image.new("RGB", layer.size, color)
    canvas.paste(tint, (x0 - pad + offset[0], y0 - pad + offset[1]), layer)


def parse_accent(text):
    """'Compare [propostas] já' -> [('Compare', False), ('propostas', True), ('já', False)]."""
    words, accent = [], False
    for token in text.replace("[", " [ ").replace("]", " ] ").split():
        if token == "[":
            accent = True
        elif token == "]":
            accent = False
        else:
            words.append((token, accent))
    return words


def wrap(words, fnt, max_w):
    lines, line = [], []
    for word in words:
        trial = " ".join(w for w, _ in line + [word])
        if line and fnt.getlength(trial) > max_w:
            lines.append(line)
            line = [word]
        else:
            line.append(word)
    if line:
        lines.append(line)
    if len(lines) == 2:
        # Equilibra as duas linhas (evita uma palavra sozinha embaixo).
        width = lambda ws: fnt.getlength(" ".join(w for w, _ in ws))
        best = min(range(1, len(words)),
                   key=lambda i: max(width(words[:i]), width(words[i:])))
        if max(width(words[:best]), width(words[best:])) <= max_w:
            lines = [words[:best], words[best:]]
    return lines


def fit_text(text, weight, size, max_w, max_lines, min_size):
    words = parse_accent(text)
    while True:
        fnt = font(weight, size)
        lines = wrap(words, fnt, max_w)
        if len(lines) <= max_lines or size <= min_size:
            return fnt, lines
        size -= 2


def draw_lines(draw, lines, fnt, x_center, y, line_h, color, accent_color):
    space = fnt.getlength(" ")
    for line in lines:
        total = sum(fnt.getlength(w) for w, _ in line) + space * (len(line) - 1)
        x = x_center - total / 2
        for word, accent in line:
            draw.text((x, y), word, font=fnt, fill=accent_color if accent else color)
            x += fnt.getlength(word) + space
        y += line_h
    return y


def check_raw(name):
    path = RAW / f"{name}.png"
    if not path.exists():
        raise SystemExit(f"Falta {path}. Rode freelanceflow/tool/showcase/store.mjs antes.")
    return Image.open(path)


# ---------------------------------------------------------------- saídas

def screenshot(out_name, raw_name, title, subtitle):
    W, H = 1080, 1920
    margin = 72
    canvas = background(W, H, (W // 2, 1150))
    draw = ImageDraw.Draw(canvas)

    title_font, title_lines = fit_text(title, 700, 88, W - margin * 2, 2, 64)
    y = 104
    y = draw_lines(draw, title_lines, title_font, W / 2, y,
                   round(title_font.size * 1.14), TEXT, PRIMARY)
    sub_font, sub_lines = fit_text(subtitle, 500, 40, W - margin * 2, 2, 32)
    draw_lines(draw, sub_lines, sub_font, W / 2, y + 30,
               round(sub_font.size * 1.35), TEXT_SECONDARY, TEXT_SECONDARY)

    # Celular com tamanho fixo em todas as telas (fica alinhado na galeria).
    top, bottom = 470, H - 56
    raw = check_raw(raw_name)
    screen_h = (bottom - top) / (1 + 2 * BEZEL * raw.width / raw.height)
    screen_w = round(screen_h * raw.width / raw.height)
    frame, radius = phone(raw, screen_w)
    x = (W - frame.width) // 2
    box = (x, top, x + frame.width, top + frame.height)
    drop_shadow(canvas, box, radius, 70, (0, 0), PRIMARY, 0.22)
    drop_shadow(canvas, box, radius, 36, (0, 28), (0, 0, 0), 0.55)
    canvas.paste(frame, (x, top), frame)

    out = HERE / f"{out_name}.png"
    canvas.convert("RGB").save(out, optimize=True)
    return out


def app_icon_tile(size):
    """Ícone do app em quadrado cheio, sem os cantos brancos da arte original.

    A arte tem um quadrado escuro de cantos arredondados sobre fundo branco. Os
    cantos brancos viram a cor da borda do quadrado; a Google Play aplica a
    própria máscara arredondada por cima.
    """
    src = Image.open(ICON_SOURCE).convert("RGB")
    dark = src.convert("L").point(lambda v: 255 if v < 200 else 0)
    x0, y0, x1, y1 = dark.getbbox()
    side = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    box = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
    tile = src.crop(box)
    shrink = round(side * 0.012)  # descarta o contorno claro do antisserrilhado
    inner = (side - shrink * 2, side - shrink * 2)
    mask = Image.new("L", tile.size, 0)
    mask.paste(rounded_mask(inner, round(side * 0.22)), (shrink, shrink))
    # Estende as cores da borda para os cantos (convolução normalizada), assim
    # o degradê do quadrado continua sem emenda visível.
    blur = ImageFilter.GaussianBlur(round(side * 0.06))
    spread = Image.composite(tile, Image.new("RGB", tile.size), mask).filter(blur)
    weight = mask.filter(blur)
    bands = [ImageMath.eval("convert(float(c) * 255 / max(float(w), 1), 'L')", c=c, w=weight)
             for c in spread.split()]
    full = Image.composite(tile, Image.merge("RGB", bands), mask)
    return full.resize((size, size), Image.LANCZOS)


def icon():
    out = HERE / "icon-512.png"
    app_icon_tile(512).save(out, optimize=True)
    return out


def feature_graphic():
    W, H = 1024, 500
    canvas = background(W, H, (800, 250))
    draw = ImageDraw.Draw(canvas)

    # Dois celulares inclinados à direita (decorativos; saem pela borda de baixo).
    for raw_name, width, angle, pos in FEATURE_PHONES:
        frame, radius = phone(check_raw(raw_name), width)
        layer = Image.new("RGBA", (frame.width + 160, frame.height + 160), (0, 0, 0, 0))
        mask = Image.new("L", layer.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (80, 100, 80 + frame.width, 100 + frame.height), radius, fill=150)
        layer.paste((0, 0, 0, 255), (0, 0), mask.filter(ImageFilter.GaussianBlur(26)))
        layer.alpha_composite(frame, (80, 80))
        tilted = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
        canvas.paste(tilted, pos, tilted)

    # Logo, nome e frase à esquerda, dentro da área segura.
    x, logo = 72, 104
    tile = app_icon_tile(logo)
    canvas.paste(tile, (x, 112), rounded_mask((logo, logo), round(logo * 0.23)))
    name_font = font(700, 76)
    draw.text((x + logo + 26, 112 + logo / 2), "Trabalhei", font=name_font,
              fill=TEXT, anchor="lm")
    tag_font = font(700, 38)
    y = 262
    for line in FEATURE_TAGLINE:
        draw.text((x, y), line, font=tag_font, fill=TEXT)
        y += 48
    draw.text((x, y + 10), FEATURE_ACCENT, font=font(500, 30), fill=PRIMARY)

    out = HERE / "feature-graphic.png"
    canvas.convert("RGB").save(out, optimize=True)
    return out


def main():
    outputs = [screenshot(*screen) for screen in SCREENS]
    outputs += [feature_graphic(), icon()]
    for path in outputs:
        with Image.open(path) as im:
            print(f"{path.name}: {im.width}x{im.height} {im.mode}, "
                  f"{path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
