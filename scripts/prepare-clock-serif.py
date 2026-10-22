"""Create the bundled static serif face; requires fontTools for regeneration only."""
import argparse
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'outlook-screensaver/fonts/SleepClockSerif-Regular.ttf')
args = parser.parse_args()
face = instantiateVariableFont(TTFont(args.source), {'wght': 400}, inplace=False)
# The upstream OFL reserves "Lora". Rename the static derivative internally.
for record in face['name'].names:
    text = record.toUnicode()
    # Rename identity fields only; retain original copyright/license metadata.
    if record.nameID in (1, 2, 3, 4, 6, 16, 17, 18, 25) and 'Lora' in text:
        face['name'].setName(text.replace('Lora', 'SleepClockSerif'), record.nameID, record.platformID, record.platEncID, record.langID)
face.save(args.output)
print('Generated static SleepClockSerif-Regular.ttf (upstream Lora Regular design).')
