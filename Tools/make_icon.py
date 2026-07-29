#!/usr/bin/env python3
"""
Kestrel app icon generator (Apple Graphics lead) — three variants.

Concept: the mark *is* the product — a calm baseline rhythm with a single
sharp anomaly spike over an atmospheric gradient. No text, no alpha,
full-bleed 1024.

Variants:
  Classic  — warm dusk (default)
  Midnight — deep blue night
  Mono     — charcoal monochrome

Run:  python3 Tools/make_icon.py
Deps: Pillow
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


PALETTES = {
    "Classic": dict(
        top=(244, 168, 78), mid=(238, 122, 56), lowmid=(150, 78, 70), bottom=(14, 40, 46),
        ink=(255, 246, 236), dot=(255, 255, 255), ring=(238, 122, 56), glow=(255, 210, 150),
        vig=(8, 22, 26),
    ),
    "Midnight": dict(
        top=(58, 96, 168), mid=(36, 60, 120), lowmid=(24, 34, 74), bottom=(8, 12, 30),
        ink=(224, 236, 255), dot=(255, 255, 255), ring=(96, 156, 240), glow=(120, 170, 255),
        vig=(4, 6, 18),
    ),
    "Mono": dict(
        top=(120, 124, 130), mid=(78, 82, 88), lowmid=(48, 50, 54), bottom=(20, 21, 23),
        ink=(245, 246, 248), dot=(255, 255, 255), ring=(160, 162, 166), glow=(210, 212, 216),
        vig=(10, 10, 12),
    ),
}


def gradient_color(p, t):
    if t < 0.40:
        return lerp(p["top"], p["mid"], t / 0.40)
    if t < 0.72:
        return lerp(p["mid"], p["lowmid"], (t - 0.40) / 0.32)
    return lerp(p["lowmid"], p["bottom"], (t - 0.72) / 0.28)


def build_gradient(p):
    base = Image.new("RGB", (1, S))
    px = base.load()
    for y in range(S):
        px[0, y] = gradient_color(p, y / (S - 1))
    return base.resize((S, S))


def radial_vignette(img, p):
    v = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(v)
    cx, cy, r = S * 0.5, S * 0.42, S * 0.78
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(S * 0.18))
    dark = Image.new("RGB", (S, S), p["vig"])
    return Image.composite(img, dark, v)


def rhythm_points():
    pts = []
    baseline = S * 0.60
    amp = S * 0.018
    spike_x, spike_h, spike_w = 0.62, S * 0.30, 0.055
    left, right = int(S * 0.14), int(S * 0.86)
    for x in range(left, right + 1):
        fx = x / S
        y = baseline + amp * math.sin(fx * 22)
        y -= spike_h * math.exp(-((fx - spike_x) ** 2) / (2 * spike_w ** 2))
        pts.append((x, y))
    return pts, (int(spike_x * S), baseline - spike_h)


def draw(name):
    p = PALETTES[name]
    img = radial_vignette(build_gradient(p), p).convert("RGBA")
    pts, apex = rhythm_points()

    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).line([(x, y + 10) for x, y in pts],
                                fill=(0, 0, 0, 90), width=20, joint="curve")
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(9)))

    ImageDraw.Draw(img).line(pts, fill=p["ink"] + (255,), width=17, joint="curve")

    r = 26
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [apex[0] - r * 2.4, apex[1] - r * 2.4, apex[0] + r * 2.4, apex[1] + r * 2.4],
        fill=p["glow"] + (120,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(18)))

    d = ImageDraw.Draw(img)
    d.ellipse([apex[0] - r, apex[1] - r, apex[0] + r, apex[1] + r], fill=p["dot"] + (255,))
    d.ellipse([apex[0] - r, apex[1] - r, apex[0] + r, apex[1] + r], outline=p["ring"] + (255,), width=6)
    return img.convert("RGB")


def rounded_preview(img, radius_frac=0.2237):
    rad = int(S * radius_frac)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S, S], radius=rad, fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


ASSET = "Kestrel/Assets.xcassets"
VARIANTS = {
    "Classic": f"{ASSET}/AppIcon.appiconset/AppIcon-1024.png",
    "Midnight": f"{ASSET}/AppIcon-Midnight.appiconset/AppIcon-Midnight-1024.png",
    "Mono": f"{ASSET}/AppIcon-Mono.appiconset/AppIcon-Mono-1024.png",
}

if __name__ == "__main__":
    imgs = {}
    for name, path in VARIANTS.items():
        img = draw(name)
        imgs[name] = img
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path)
        print("wrote", path)
    os.makedirs("AppStore", exist_ok=True)
    imgs["Classic"].save("AppStore/AppIcon-1024.png")
    print("wrote AppStore/AppIcon-1024.png")
    os.makedirs("docs/img", exist_ok=True)
    for name in imgs:
        rounded_preview(imgs[name]).save(f"docs/img/icon-{name.lower()}.png")
    rounded_preview(imgs["Classic"]).save("docs/img/icon.png")
    print("wrote docs/img previews")
