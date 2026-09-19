# Soft noise

`soft_noise.wav` is generated specifically for FocusHaven by
`tool/generate_soft_noise.py` from deterministic pseudorandom numbers.
No third-party recordings or samples are used. It may be bundled with FocusHaven;
it does not require a stock-audio attribution or external asset download.

Format: 30 seconds, 24 kHz mono 16-bit PCM, filtered noise with a one-second
equal-power overlap for looping. Peak amplitude is bounded to 45% full scale;
the app starts at 25% player volume. This is not a guarantee of a safe physical
listening level, which depends on the device/headphones and system volume.

Listening quality, the loop seam, and playback on target devices still require
human audition. No therapeutic or performance claim is made.
