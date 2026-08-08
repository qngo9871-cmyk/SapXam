#!/usr/bin/env python3
"""Capture REAL in-app App Store screenshots for Sập Xám via the simulator and
DEBUG SX_CAPTURE/SX_LANG launch args. Adds a navy/gold caption band matching the
app icon. Every shot is the actual app UI (App Review 2.3.3).
Output: screenshots/final/{en,vi}/*.png"""
import os, re, subprocess, sys, time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

APP_DIR = Path("/Users/q/Projects/SapXam")
PROJECT = APP_DIR / "SapXam.xcodeproj"
SCHEME = "SapXam"
BUNDLE = "com.quyenngo.sapxam"
W, H = 1320, 2868
BAND = 470

# capture value of None/"" means: no SX_CAPTURE env var at all (falls through
# to HomeView via SX_SKIP_ONBOARDING, see ContentView.swift's #if DEBUG block).
SHOTS = {
    "en": [
        ("01-home",    None,          "Sập Xám —\nVietnamese 13-Card Poker"),
        ("02-arrange", "arrange",     "Arrange 13 cards into\nBack, Middle, Front"),
        ("03-results", "results",     "See exactly how each\nhand won or lost"),
        ("04-special", "onboarding1", "Special hands explained\nwith worked examples"),
        ("05-upgrade", "upgrade",     "Hard AI, unlocked once —\nno subscription"),
    ],
    "vi": [
        ("01-home",    None,          "Sập Xám —\nBài 13 Lá Việt Nam"),
        ("02-arrange", "arrange",     "Xếp 13 lá thành\nChi Sau, Chi Giữa, Chi Trước"),
        ("03-results", "results",     "Xem rõ từng chi\nthắng hay thua"),
        ("04-special", "onboarding1", "Bài đặc biệt có\nví dụ minh họa"),
        ("05-upgrade", "upgrade",     "Mở khóa AI Khó một lần,\ndùng mãi mãi"),
    ],
}

FONT_PATHS = ["/System/Library/Fonts/SFNSDisplay.ttf", "/System/Library/Fonts/SFNS.ttf",
              "/System/Library/Fonts/Supplemental/Arial Bold.ttf"]


def sh(*a, **k): return subprocess.run(a, check=True, capture_output=True, text=True, **k)


DEDICATED_SIM_NAME = "SapXam-Screenshots"


def find_device():
    """Uses a DEDICATED, freshly-created simulator instead of scanning for a
    shared one — see Pallanguzhi's capture_shots.py for the reproducible
    cross-app flakiness this avoids (a stale foreground app from a
    different installed app winning a fixed-sleep screenshot race)."""
    out = subprocess.run(["xcrun", "simctl", "list", "devices"], capture_output=True, text=True).stdout
    for line in out.splitlines():
        if DEDICATED_SIM_NAME in line:
            m = re.search(r"\(([0-9A-F\-]{36})\)", line)
            if m:
                return m.group(1), DEDICATED_SIM_NAME
    out = subprocess.run(["xcrun", "simctl", "create", DEDICATED_SIM_NAME,
                          "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max",
                          "com.apple.CoreSimulator.SimRuntime.iOS-26-5"],
                         capture_output=True, text=True)
    udid = out.stdout.strip()
    if not udid:
        raise SystemExit(f"failed to create dedicated simulator: {out.stderr}")
    return udid, DEDICATED_SIM_NAME


def build_app():
    sh("xcodebuild", "-project", str(PROJECT), "-scheme", SCHEME, "-configuration", "Debug",
       "-sdk", "iphonesimulator", "-derivedDataPath", str(APP_DIR / "build/sim"), "build",
       cwd=str(APP_DIR))
    app = APP_DIR / "build/sim/Build/Products/Debug-iphonesimulator/SapXam.app"
    if not app.exists():
        raise SystemExit(f"built app not found at {app}")
    return app


def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def font(size):
    for c in FONT_PATHS:
        if Path(c).exists():
            try: return ImageFont.truetype(c, size)
            except Exception: continue
    return ImageFont.load_default()


def compose(raw_png, headline, out_png):
    shot = Image.open(raw_png).convert("RGB").resize((W, H), Image.LANCZOS)
    canvas = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(canvas)
    top, bot = (10, 24, 56), (4, 9, 24)  # navy gradient, matches app icon
    for y in range(H):
        d.line([(0, y), (W, y)], fill=lerp(top, bot, y / H))
    lines = headline.split("\n")
    size = 92
    max_w = W * 0.9
    f = font(size)
    while size > 52 and max(d.textlength(line, font=f) for line in lines) > max_w:
        size -= 4
        f = font(size)
    lh = int(size * 1.22)
    y = (BAND - lh * len(lines)) // 2 + 8
    for line in lines:
        w = d.textlength(line, font=f)
        d.text(((W - w) / 2, y), line, font=f, fill=(224, 178, 96)); y += lh  # gold
    avail_h = H - BAND - 70
    sw = int(W * 0.84); sh_ = int(shot.height * sw / shot.width)
    if sh_ > avail_h: sh_ = avail_h; sw = int(shot.width * sh_ / shot.height)
    shot = shot.resize((sw, sh_), Image.LANCZOS)
    mask = Image.new("L", (sw, sh_), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw, sh_], radius=54, fill=255)
    px = (W - sw) // 2; py = BAND + (avail_h - sh_) // 2 + 35
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([px, py + 16, px + sw, py + sh_ + 16], radius=54, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB")
    canvas.paste(shot, (px, py), mask)
    canvas.save(out_png); print(f"  wrote {out_png.name}")


def main():
    DEVICE, name = find_device()
    print(f"==> device {name} ({DEVICE})")
    APP = build_app()
    subprocess.run(["xcrun", "simctl", "shutdown", DEVICE], capture_output=True)
    subprocess.run(["xcrun", "simctl", "erase", DEVICE], capture_output=True)
    subprocess.run(["xcrun", "simctl", "boot", DEVICE], capture_output=True)
    sh("xcrun", "simctl", "bootstatus", DEVICE, "-b")
    subprocess.run(["xcrun", "simctl", "status_bar", DEVICE, "override", "--time", "9:41",
                    "--batteryLevel", "100", "--batteryState", "charged",
                    "--cellularBars", "4", "--wifiBars", "3"], capture_output=True)
    sh("xcrun", "simctl", "install", DEVICE, str(APP))

    # Warm-up launch: a freshly-erased simulator fires a one-time system
    # notification ("Ready for Apple Intelligence") shortly after first boot,
    # which was observed landing directly on top of the very first capture
    # (the Home screenshot) — not part of the app's real UI, so it must not
    # ship in App Store screenshots. Launch once, wait long enough for that
    # banner to appear and auto-dismiss, then terminate before real captures.
    subprocess.run(["xcrun", "simctl", "launch", DEVICE, BUNDLE],
                    env=dict(os.environ, SIMCTL_CHILD_SX_SKIP_ONBOARDING="1"),
                    capture_output=True, text=True)
    time.sleep(20)
    subprocess.run(["xcrun", "simctl", "terminate", DEVICE, BUNDLE], capture_output=True)
    time.sleep(1)

    raw = APP_DIR / "screenshots" / "_raw.png"

    def launch_and_verify(cap, lang, attempts=3):
        """simctl launch is fire-and-forget and was observed elsewhere in this
        portfolio to silently leave a stale foreground app under rapid
        terminate/launch cycling. Verify the target bundle is actually the
        running foreground process via the launched PID + launchctl list,
        retrying on failure instead of trusting a single fire-and-forget call."""
        for attempt in range(1, attempts + 1):
            subprocess.run(["xcrun", "simctl", "terminate", DEVICE, BUNDLE], capture_output=True)
            time.sleep(1)
            env = dict(os.environ, SIMCTL_CHILD_SX_LANG=lang, SIMCTL_CHILD_SX_SKIP_ONBOARDING="1")
            if cap:
                env["SIMCTL_CHILD_SX_CAPTURE"] = cap
            result = subprocess.run(
                ["xcrun", "simctl", "launch", DEVICE, BUNDLE],
                env=env, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"  !! launch attempt {attempt} failed (rc={result.returncode}): {result.stderr.strip()}")
                time.sleep(2)
                continue
            # stdout looks like "com.quyenngo.sapxam: 12345"
            pid = result.stdout.strip().split(":")[-1].strip()
            time.sleep(9 if cap == "upgrade" else 6)
            check = subprocess.run(["xcrun", "simctl", "spawn", DEVICE, "launchctl", "list"],
                                    capture_output=True, text=True)
            if pid and pid in check.stdout:
                return True
            print(f"  !! attempt {attempt}: pid {pid} not found alive after wait, retrying")
            time.sleep(2)
        return False

    for lang, shots in SHOTS.items():
        out = APP_DIR / "screenshots" / "final" / lang
        out.mkdir(parents=True, exist_ok=True)
        for shotname, cap, headline in shots:
            ok = launch_and_verify(cap, lang)
            if not ok:
                raise SystemExit(f"FATAL: could not get {BUNDLE} verified alive for {lang}/{shotname}")
            sh("xcrun", "simctl", "io", DEVICE, "screenshot", str(raw))
            compose(raw, headline, out / f"{shotname}.png")
    raw.unlink(missing_ok=True)
    subprocess.run(["xcrun", "simctl", "terminate", DEVICE, BUNDLE], capture_output=True)
    print("==> done.", APP_DIR / "screenshots" / "final")


if __name__ == "__main__":
    main()
