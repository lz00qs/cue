"""Generate Cue launcher assets from the approved white cat artwork.

Requires ImageMagick (`magick`) on PATH.
"""

from __future__ import annotations

import json
import re
import subprocess
from decimal import Decimal
from pathlib import Path
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "design" / "app-icon" / "cue-cat-white-app-icon.png"


def magick(*args: object) -> None:
    subprocess.run(["magick", *(str(arg) for arg in args)], check=True)


def resize(source: Path, destination: Path, size: int, *, opaque: bool = False) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    args: list[object] = [
        source,
        "-filter",
        "Lanczos",
        "-resize",
        f"{size}x{size}!",
        "-strip",
    ]
    if opaque:
        args += ["-background", "white", "-alpha", "remove", "-alpha", "off", "-type", "TrueColor"]
    magick(*args, destination)


def main() -> None:
    with TemporaryDirectory() as temporary_directory:
        temporary = Path(temporary_directory)
        master = temporary / "master-1024.png"
        resize(SOURCE, master, 1024, opaque=True)

        ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
        contents = json.loads((ios / "Contents.json").read_text())
        for item in contents["images"]:
            logical_size = Decimal(item["size"].split("x")[0])
            scale = Decimal(item["scale"].removesuffix("x"))
            resize(master, ios / item["filename"], int(logical_size * scale), opaque=True)

        android = ROOT / "android" / "app" / "src" / "main" / "res"
        for density, size in {
            "mdpi": 48,
            "hdpi": 72,
            "xhdpi": 96,
            "xxhdpi": 144,
            "xxxhdpi": 192,
        }.items():
            resize(master, android / f"mipmap-{density}" / "ic_launcher.png", size, opaque=True)

        web = ROOT / "web"
        resize(master, web / "favicon.png", 32, opaque=True)
        for size in (192, 512):
            resize(master, web / "icons" / f"Icon-{size}.png", size, opaque=True)

        maskable = temporary / "maskable.png"
        magick(
            master,
            "-resize",
            "82%",
            "-gravity",
            "center",
            "-background",
            "white",
            "-extent",
            "1024x1024",
            "-alpha",
            "off",
            maskable,
        )
        for size in (192, 512):
            resize(maskable, web / "icons" / f"Icon-maskable-{size}.png", size, opaque=True)

        rounded_mask = temporary / "rounded-mask.png"
        rounded_icon = temporary / "rounded-icon.png"
        mac_icon = temporary / "mac-icon.png"
        magick(
            "-size",
            "1024x1024",
            "xc:none",
            "-fill",
            "white",
            "-draw",
            "roundrectangle 0,0 1023,1023 230,230",
            rounded_mask,
        )
        magick(master, rounded_mask, "-alpha", "off", "-compose", "CopyOpacity", "-composite", rounded_icon)
        magick(
            rounded_icon,
            "-resize",
            "88%",
            "-gravity",
            "center",
            "-background",
            "none",
            "-extent",
            "1024x1024",
            mac_icon,
        )
        macos = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
        for destination in macos.glob("app_icon_*.png"):
            match = re.search(r"app_icon_(\d+)", destination.stem)
            if match:
                resize(mac_icon, destination, int(match.group(1)))

        magick(
            master,
            "-define",
            "icon:auto-resize=256,128,64,48,32,16",
            ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
        )


if __name__ == "__main__":
    main()
