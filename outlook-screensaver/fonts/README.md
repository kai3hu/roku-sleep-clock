# Bundled fonts

## Clock choices

- **System** keeps Roku's original system font.
- **Roboto Mono Light** is the unmodified static font from
  `https://github.com/googlefonts/RobotoMono`, path
  `fonts/ttf/RobotoMono-Light.ttf`. See `RobotoMono-OFL.txt`.
- **Rajdhani Light** is the unmodified static font from
  `https://github.com/google/fonts`, path `ofl/rajdhani/Rajdhani-Light.ttf`.
  See `Rajdhani-OFL.txt`.
- **DSEG7 Classic Light** is the unmodified static font from the author's
  `https://github.com/keshikan/DSEG/releases/tag/v0.46` release,
  `fonts-DSEG_v046/DSEG7-Classic/DSEG7Classic-Light.ttf`.
  See `DSEG-LICENSE.txt`. Its reserved font name is unchanged.
- **Lora Regular** uses the original design at weight 400. For predictable
  native-device rendering, the upstream `ofl/lora/Lora[wght].ttf` from
  `https://github.com/google/fonts` is instantiated as a static font.
  Its internal family is renamed **SleepClockSerif** to respect the upstream
  reserved font name. See `Lora-OFL.txt`. Regenerate it with
  `scripts/prepare-clock-serif.py` and fontTools 4.60.1.

All four are SIL OFL 1.1 fonts. Their complete licenses and copyright notices
are distributed with the Roku package. No font download occurs on the TV.
AM/PM is rendered with a separate system-font label so digital segment glyph
limitations cannot remove the period indicator. Advance widths used by the
clock are precomputed from these exact assets; native font metrics never run
on the SceneGraph render thread.

## Telegram font

`NotoSansSC-Regular.otf` is an unmodified Noto Sans SC font from the
[Noto CJK project](https://github.com/notofonts/noto-cjk), licensed under
the SIL Open Font License 1.1. See `LICENSE.txt` and the font's embedded
copyright metadata. This font supports the channel's original Chinese
text; application labels and source documentation remain English.

Source revision: `f8d157532fbfaeda587e826d4cd5b21a49186f7c`

Source path: `Sans/SubsetOTF/SC/NotoSansSC-Regular.otf`

SHA-256: `faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9`

Unsupported glyphs, such as some emoji, use a blank fallback rather than
bright images. No external font request is needed on the Roku.
