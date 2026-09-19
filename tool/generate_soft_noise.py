"""Create FocusHaven's original deterministic, filtered-noise loop; no inputs.

The generated PCM file uses no recording, sample library, network or user data.
Run from any directory. A one-second overlap blends the end into the beginning.
"""
from array import array
import math
from pathlib import Path
import random
import sys
import wave

RATE = 24000
OVERLAP = RATE
LENGTH = RATE * 31
random_source = random.Random(218)
samples = []
low = 0.0
for _ in range(LENGTH):
    low = 0.93 * low + 0.07 * random_source.uniform(-1, 1)
    samples.append(low)

# Equal-power crossfade, with continuity into sample OVERLAP at the wrap.
for index in range(OVERLAP):
    angle = index / (OVERLAP - 1) * math.pi / 2
    samples[LENGTH - OVERLAP + index] = (
        samples[LENGTH - OVERLAP + index] * math.cos(angle)
        + samples[index] * math.sin(angle)
    )
loop = samples[OVERLAP:]
gain = 0.45 / max(abs(value) for value in loop)
pcm = array('h', (round(value * gain * 32767) for value in loop))
if sys.byteorder != 'little':
    pcm.byteswap()
destination = Path(__file__).resolve().parents[1] / 'assets/audio/soft_noise.wav'
destination.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(destination), 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(RATE)
    output.writeframes(pcm.tobytes())
print(f'Generated {len(pcm) / RATE:.0f}s mono PCM: {destination.name}')
