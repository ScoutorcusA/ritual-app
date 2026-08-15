#!/usr/bin/env python3
"""Generate deterministic PNG exports from Ritual's vector logo geometry."""

from __future__ import annotations

import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets" / "branding"
EXPORTS = BRAND / "exports"
IOS_SET = EXPORTS / "ios" / "AppIcon.appiconset"
WEB = ROOT / "web"
WEB_ASSETS = WEB / "assets"

CANVAS = 1024
SUPERSAMPLE = 4
CREAM = "#F6F1E7"
CHARCOAL = "#1E2A2D"
SAGE = "#71826B"


def scaled(value: float) -> int:
    return round(value * SUPERSAMPLE)


def bezier(
    start: tuple[float, float],
    control_1: tuple[float, float],
    control_2: tuple[float, float],
    end: tuple[float, float],
    steps: int = 48,
) -> list[tuple[int, int]]:
    points = []
    for index in range(steps + 1):
        t = index / steps
        inverse = 1 - t
        x = (
            inverse**3 * start[0]
            + 3 * inverse**2 * t * control_1[0]
            + 3 * inverse * t**2 * control_2[0]
            + t**3 * end[0]
        )
        y = (
            inverse**3 * start[1]
            + 3 * inverse**2 * t * control_1[1]
            + 3 * inverse * t**2 * control_2[1]
            + t**3 * end[1]
        )
        points.append((scaled(x), scaled(y)))
    return points


def rounded_line(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    color: str,
    width: float,
) -> None:
    rendered = [(scaled(x), scaled(y)) for x, y in points]
    line_width = scaled(width)
    radius = line_width // 2
    draw.line(rendered, fill=color, width=line_width, joint="curve")
    for x, y in rendered:
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def curved_line(
    draw: ImageDraw.ImageDraw,
    segments: list[
        tuple[
            tuple[float, float],
            tuple[float, float],
            tuple[float, float],
            tuple[float, float],
        ]
    ],
    color: str,
    width: float,
) -> None:
    points: list[tuple[int, int]] = []
    for segment in segments:
        segment_points = bezier(*segment)
        points.extend(segment_points if not points else segment_points[1:])
    line_width = scaled(width)
    radius = line_width // 2
    draw.line(points, fill=color, width=line_width, joint="curve")
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def render_icon(include_background: bool, monochrome: bool = False) -> Image.Image:
    mode = "RGB" if include_background else "RGBA"
    background = CREAM if include_background else (0, 0, 0, 0)
    image = Image.new(mode, (scaled(CANVAS), scaled(CANVAS)), background)
    draw = ImageDraw.Draw(image)
    primary = "#000000" if monochrome else CHARCOAL
    accent = primary if monochrome else SAGE

    rounded_line(draw, [(320, 224), (232, 224), (232, 312)], primary, 64)
    rounded_line(draw, [(704, 224), (792, 224), (792, 312)], primary, 64)
    rounded_line(draw, [(232, 712), (232, 800), (320, 800)], primary, 64)
    rounded_line(draw, [(792, 712), (792, 800), (704, 800)], primary, 64)

    curved_line(
        draw,
        [
            ((468, 500), (426, 466), (420, 426), (462, 388)),
            ((462, 388), (506, 350), (504, 304), (478, 270)),
        ],
        accent,
        48,
    )
    curved_line(
        draw,
        [
            ((560, 502), (524, 470), (524, 438), (556, 410)),
            ((556, 410), (586, 384), (590, 350), (568, 322)),
        ],
        accent,
        40,
    )

    bowl = [(scaled(276), scaled(576))]
    bowl.extend(
        bezier((276, 576), (292, 720), (384, 812), (512, 812))[1:]
    )
    bowl.extend(
        bezier((512, 812), (640, 812), (732, 720), (748, 576))[1:]
    )
    draw.polygon(bowl, fill=primary)
    draw.ellipse(
        (scaled(276), scaled(532), scaled(748), scaled(624)), fill=primary
    )
    opening = (scaled(310), scaled(553), scaled(714), scaled(607))
    draw.ellipse(opening, fill=CREAM if include_background else (0, 0, 0, 0))
    return image


def save_resized(source: Image.Image, destination: Path, size: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    resized = source.resize((size, size), Image.Resampling.LANCZOS)
    if destination.suffix.lower() in {".jpg", ".jpeg"}:
        resized = resized.convert("RGB")
    resized.save(destination, optimize=True)


def create_ios_set(source: Image.Image) -> None:
    images = [
        ("iphone", "20x20", "2x", 40, "Icon-App-20x20@2x.png"),
        ("iphone", "20x20", "3x", 60, "Icon-App-20x20@3x.png"),
        ("iphone", "29x29", "2x", 58, "Icon-App-29x29@2x.png"),
        ("iphone", "29x29", "3x", 87, "Icon-App-29x29@3x.png"),
        ("iphone", "40x40", "2x", 80, "Icon-App-40x40@2x.png"),
        ("iphone", "40x40", "3x", 120, "Icon-App-40x40@3x.png"),
        ("iphone", "60x60", "2x", 120, "Icon-App-60x60@2x.png"),
        ("iphone", "60x60", "3x", 180, "Icon-App-60x60@3x.png"),
        ("ipad", "20x20", "1x", 20, "Icon-App-20x20@1x.png"),
        ("ipad", "20x20", "2x", 40, "Icon-App-20x20@2x-ipad.png"),
        ("ipad", "29x29", "1x", 29, "Icon-App-29x29@1x.png"),
        ("ipad", "29x29", "2x", 58, "Icon-App-29x29@2x-ipad.png"),
        ("ipad", "40x40", "1x", 40, "Icon-App-40x40@1x.png"),
        ("ipad", "40x40", "2x", 80, "Icon-App-40x40@2x-ipad.png"),
        ("ipad", "76x76", "1x", 76, "Icon-App-76x76@1x.png"),
        ("ipad", "76x76", "2x", 152, "Icon-App-76x76@2x.png"),
        ("ipad", "83.5x83.5", "2x", 167, "Icon-App-83.5x83.5@2x.png"),
        ("ios-marketing", "1024x1024", "1x", 1024, "Icon-App-1024x1024@1x.png"),
    ]
    contents = {"images": [], "info": {"author": "xcode", "version": 1}}
    for idiom, logical_size, scale, pixels, filename in images:
        save_resized(source, IOS_SET / filename, pixels)
        contents["images"].append(
            {
                "filename": filename,
                "idiom": idiom,
                "scale": scale,
                "size": logical_size,
            }
        )
    IOS_SET.mkdir(parents=True, exist_ok=True)
    (IOS_SET / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    full = render_icon(include_background=True)
    foreground = render_icon(include_background=False)
    monochrome = render_icon(include_background=False, monochrome=True)

    save_resized(full, BRAND / "ritual-logo-1024.png", 1024)
    save_resized(foreground, BRAND / "ritual-logo-foreground-1024.png", 1024)
    save_resized(monochrome, BRAND / "ritual-logo-monochrome-1024.png", 1024)
    for size in (1024, 2048, 4096):
        save_resized(full, EXPORTS / "high-resolution" / f"ritual-logo-{size}.png", size)

    create_ios_set(full)

    shutil.copyfile(BRAND / "ritual-logo.svg", WEB_ASSETS / "ritual-logo.svg")
    save_resized(full, WEB_ASSETS / "ritual-logo.png", 512)
    save_resized(full, WEB_ASSETS / "ritual-logo-192.png", 192)
    save_resized(full, WEB_ASSETS / "ritual-logo-512.png", 512)
    save_resized(full, WEB / "apple-touch-icon.png", 180)
    save_resized(full, WEB / "favicon-32.png", 32)
    save_resized(full, WEB / "favicon-48.png", 48)
    favicon = full.resize((256, 256), Image.Resampling.LANCZOS)
    favicon.save(WEB / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])

    print("Generated Ritual brand exports.")


if __name__ == "__main__":
    main()
