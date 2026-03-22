import os
import sys
import vapoursynth as vs
import vsmlrt

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

core = vs.core

my_backend = vsmlrt.Backend.TRT(fp16=True, device_id=0, static_shape=False)

tmp_path = os.path.join(os.environ.get("LOCALAPPDATA", ""), r"Plex\scripts\Plex-HDR-Fix.tmp")
if not os.path.exists(tmp_path):
    raise vs.Error("Data Sync Failed: vpy_data.tmp not found. Lua must run first.")

with open(tmp_path, "r") as f:
    data = f.read().splitlines()
    if len(data) < 3:
        raise vs.Error(f"Data Corruption: Expected 3 lines from Lua, got {len(data)}. Check MPV log.") 
    u_matrix = data[0]
    u_range  = data[1]
    u_prim   = data[2]

# This is workaround as other than 709 will make the scene darker than normal
matrix_s = "709"
prim_s   = "709"
trans_s  = "709"
range_s  = u_range

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
    "range_in_s": range_s,
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
    "range_s": range_s
}

clip = core.resize.Bicubic(clip, **kwargs_out)

m_v = 9 if ("2020" in u_matrix or "dolby" in u_matrix) else 1
p_v = 9 if "2020" in u_prim else 1
t_v = 16 if ("2084" in u_prim or "dolby" in u_matrix or "2020" in u_matrix) else 1
r_v = 1 if "limited" in u_range else 0

clip = core.std.SetFrameProps(clip, _Matrix=m_v, _Primaries=p_v, _Transfer=t_v, _ColorRange=r_v)

clip.set_output()