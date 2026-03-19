import os
import sys
import vapoursynth as vs

target_model = 406
target_width = 2560

current_dir = os.path.dirname(os.path.abspath(__file__))
core_file = os.path.join(current_dir, "Plex-VapourSynth.vpy")
with open(core_file, 'r', encoding='utf-8') as f:
    exec(f.read(), globals())