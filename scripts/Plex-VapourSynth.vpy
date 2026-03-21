import os
import sys
import vapoursynth as vs

py_path = os.path.join(os.environ.get("LOCALAPPDATA", ""), r"Programs\Python\Python312")
if not os.path.exists(py_path): py_path = r"C:\Program Files\Python312"
vs_path = os.path.join(os.environ.get("LOCALAPPDATA", ""), r"Programs\VapourSynth\core")
if not os.path.exists(vs_path): vs_path = r"C:\Program Files\VapourSynth\core"

if hasattr(os, 'add_dll_directory'):
    try:
        os.add_dll_directory(py_path)
        os.add_dll_directory(vs_path)
    except: pass

os.environ['PATH'] = py_path + os.pathsep + vs_path + os.pathsep + os.environ['PATH']

import vsmlrt
core = vs.core

my_backend = vsmlrt.Backend.TRT(fp16=True, device_id=0, static_shape=False)

clip = video_in
props = clip.get_frame(0).props

src_matrix = int(props.get('_Matrix', 1))
src_prim = int(props.get('_Primaries', 1))
src_trans = int(props.get('_Transfer', 1))
src_range = int(props.get('_ColorRange', 1))

matrix_s = "2020" if src_matrix >= 9 else "709"
prim_s   = "2020" if src_prim >= 9 else "709"
if src_trans == 16:
    trans_s = "smpte2084"
elif src_trans == 18:
    trans_s = "arib-std-b67"
else:
    trans_s = "709"
range_s = "full" if src_range == 2 else "limited"

requested_w = int(globals().get('target_width', 0))

src_w = video_in.width
src_h = video_in.height

do_scale = (requested_w > 0 and src_w > requested_w)
if do_scale:
    target_w = requested_w
    target_h = int(src_h * target_w / src_w)
    needs_odd_fix = (target_h % 2 != 0)
else:
    target_w = src_w
    target_h = src_h
    needs_odd_fix = (target_h % 2 != 0)

kwargs_in = {
    "format": vs.RGBS,
    "matrix_in_s": matrix_s,
    "primaries_in_s": prim_s,
    "range_in_s": range_s,
    "transfer_in_s": trans_s,
    "transfer_s": "linear",
    "filter_param_a": 0,        # b=0
    "filter_param_b": 0.5       # c=0.5 (Catmull-Rom)
}

if do_scale:
    if needs_odd_fix:
        clip = core.std.AddBorders(video_in, bottom=2)
        clip = core.resize.Bicubic(clip, width=target_w, height=target_h + 1, **kwargs_in)
    else:
        clip = core.resize.Bicubic(video_in, width=target_w, height=target_h, **kwargs_in)
else:
    if needs_odd_fix:
        clip = core.std.AddBorders(video_in, bottom=1)
        clip = core.resize.Bicubic(clip, width=target_w, height=target_h + 1, **kwargs_in)
    else:
        clip = core.resize.Bicubic(video_in, **kwargs_in)

w, h = clip.width, clip.height
p_w = (64 - (w % 64)) % 64
p_h = (64 - (h % 64)) % 64

if p_w > 0 or p_h > 0:
    clip = core.std.AddBorders(clip, right=p_w, bottom=p_h)

rife_model_id = globals().get('target_model', 410)
clip = vsmlrt.RIFE(clip, model=rife_model_id, multi=2, scale=1.0, backend=my_backend)

if p_w > 0 or p_h > 0:
    clip = core.std.CropRel(clip, right=p_w, bottom=p_h)

kwargs_out = {
    "format": vs.YUV420P10,
    "matrix_s": matrix_s,
    "primaries_s": prim_s,
    "range_s": range_s,
    "transfer_in_s": "linear",
    "transfer_s": trans_s
}

clip = core.resize.Bicubic(clip, **kwargs_out)

clip.set_output()