import os
import sys
import vapoursynth as vs
core = vs.core

py_path = os.path.join(os.environ.get("LOCALAPPDATA", ""), r"Programs\Python\Python312")
if not os.path.exists(py_path): py_path = r"C:\Program Files\Python312"
vs_path = os.path.join(os.environ.get("LOCALAPPDATA", ""), r"Programs\VapourSynth\core")
if not os.path.exists(vs_path): vs_path = r"C:\Program Files\VapourSynth\core"

if hasattr(os, 'add_dll_directory'):
    os.add_dll_directory(py_path)
    os.add_dll_directory(vs_path)
os.environ['PATH'] = py_path + os.pathsep + vs_path + os.pathsep + os.environ['PATH']

import vsmlrt
my_backend = vsmlrt.Backend.TRT(fp16=True, device_id=0, static_shape=False)

clip = video_in
props = clip.get_frame(0).props

src_matrix = props.get('_Matrix', 1)
matrix_s = "2020" if src_matrix == 9 else "709"

src_range = props.get('_ColorRange', 1)
range_s = "limited" if src_range == 1 else "full"

out_format = vs.YUV420P10 if clip.format.bits_per_sample > 8 else vs.YUV420P8

w, h = clip.width, clip.height
p_w = (64 - (w % 64)) % 64
p_h = (64 - (h % 64)) % 64

clip = core.resize.Bicubic(clip, format=vs.RGBS, matrix_in_s=matrix_s, range_in_s=range_s)

if p_w > 0 or p_h > 0:
    clip = core.std.AddBorders(clip, right=p_w, bottom=p_h)

rife_model_id = globals().get('target_model')
clip = vsmlrt.RIFE(clip, model=rife_model_id, multi=2, scale=1.0, backend=my_backend)

if p_w > 0 or p_h > 0:
    clip = core.std.CropRel(clip, right=p_w, bottom=p_h)

clip = core.resize.Bicubic(clip, format=out_format, matrix_s=matrix_s, range_s=range_s)

clip.set_output()

