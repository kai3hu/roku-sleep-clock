"""Offline layout QA from the actual BrightScript settings node coordinates.

Requires Node with brs and Python with Pillow. System font is approximated with
Segoe UI; bundled clock fonts are exact. This is not a Roku device screenshot.
"""
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SYSTEM = Path("C:/Windows/Fonts/segoeui.ttf")


def font(uri, size):
    file = ROOT / "outlook-screensaver" / uri.removeprefix("pkg:/") if uri and uri.startswith("pkg:/") else SYSTEM
    return ImageFont.truetype(str(file), int(size))


def text(draw, node):
    face = font(node.get("uri"), node["size"])
    value = node["text"]
    lines = []
    for paragraph in value.split("\n"):
        current = ""
        for word in paragraph.split(" "):
            candidate = (current + " " + word).strip()
            if node.get("wrap") and current and face.getlength(candidate) > node["width"]:
                lines.append(current)
                current = word
            else:
                current = candidate
        lines.append(current)
    for i, line in enumerate(lines):
        if i * (node["size"] + 5) >= node["height"]:
            break
        if not node.get("wrap") and face.getlength(line) > node["width"]:
            while line and face.getlength(line + "...") > node["width"]:
                line = line[:-1]
            line += "..."
        x = node["x"]
        if node.get("align") == "right":
            x += node["width"] - face.getlength(line)
        draw.text((x, node["y"] + i * (node["size"] + 5)), line, font=face, fill="#" + node["color"][2:8], anchor="lt")


def render(nodes, name):
    image = Image.new("RGB", (1920, 1080), "black")
    draw = ImageDraw.Draw(image)
    # Synthetic dashboard data beneath the native settings overlay.
    for value, x, y, size in [
        ("23:48", 1100, 420, 42), ("TODAY / 2 TASKS", 1105, 480, 12),
        ("09:00  Morning walk", 1105, 510, 14), ("14:00  Read a chapter", 1105, 535, 14),
        ("NEXT 7 DAYS", 1105, 630, 12), ("Tomorrow  10:00  Project review", 1105, 660, 12),
        ("TUSCALOOSA", 1480, 425, 12), ("18 C", 1480, 455, 27),
        ("Clear sky", 1480, 505, 13), ("NEXT 24 HOURS", 1480, 555, 11),
    ]:
        draw.text((x, y), value, font=font(None, size), fill="#242424", anchor="lt")
    for node in nodes:
        if node["kind"] == "Rectangle":
            x, y = node["x"], node["y"]
            draw.rectangle((x, y, x + node["width"] - 1, y + node["height"] - 1), fill="#" + node["color"][2:8])
        elif node["kind"] == "Label":
            text(draw, node)
    image = image.resize((1280, 720), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (1280, 756), "#101010")
    canvas.paste(image, (0, 0))
    ImageDraw.Draw(canvas).text((20, 729), "OFFLINE PREVIEW / Native menu coordinates / Sample data / System font approximated", font=font(None, 16), fill="#888888")
    output = ROOT / "docs" / name
    canvas.save(output)
    print(output)


if __name__ == "__main__":
    result = subprocess.run(["node", "scripts/settings-preview.cjs"], cwd=ROOT, text=True, encoding="utf-8", capture_output=True, check=True)
    screens = json.loads(result.stdout)
    render(screens["settings"], "settings-preview.png")
    render(screens["fonts"], "font-picker-preview.png")
