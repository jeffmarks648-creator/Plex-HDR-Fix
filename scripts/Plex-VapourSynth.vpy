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
    if len(data) < 5:
        raise vs.Error(f"Data Corruption: Expected 5 lines from Lua, got {len(data)}. Check MPV log.") 
    u_matrix = data[0]
    u_range  = data[1]
    u_prim   = data[2]
    u_gamma  = data[3]
    u_cloc   = data[4]

m_v = 9 if ("2020" in u_matrix or "dolby" in u_matrix) else 1
p_v = 12 if ("p3" in u_prim or "dci" in u_prim) else (11 if ("display" in u_prim) else (9 if m_v==9 else 1))
t_v = 18 if ("arib" in u_gamma or "b67" in u_gamma or "hlg" in u_gamma) else (16 if m_v==9 else (13 if ("1886" in u_gamma) else 1))
r_v = 1 if "limited" in u_range else 0
c_v = 2 if ("uhd" in u_cloc or "topleft" in u_cloc) else (1 if ("h264" in u_cloc or "mpeg" in u_cloc or "left" in u_cloc) else 0)

# Need set colour range of "limit" to prevent darken and brighten both the limit/full film during Resize().
r_v_fixed = 1

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
    "filter_param_a": 0,        # b=0
    "filter_param_b": 0.5       # c=0.5 (Catmull-Rom)
}

clip = video_in
clip = core.std.SetFrameProps(clip, _Matrix=m_v, _Primaries=p_v, _Transfer=t_v, _ColorRange=r_v_fixed, _ChromaLocation=c_v)

if do_scale:
    if needs_odd_fix:
        clip = core.std.AddBorders(clip, bottom=2)
        clip = core.resize.Bicubic(clip, width=target_w, height=target_h + 1, **kwargs_in)
    else:
        clip = core.resize.Bicubic(clip, width=target_w, height=target_h, **kwargs_in)
else:
    if needs_odd_fix:
        clip = core.std.AddBorders(clip, bottom=1)
        clip = core.resize.Bicubic(clip, width=target_w, height=target_h + 1, **kwargs_in)
    else:
        clip = core.resize.Bicubic(clip, **kwargs_in)

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
    "matrix": m_v,
    "primaries": p_v,
    "transfer": t_v,
    "chromaloc": c_v
}

clip = core.resize.Bicubic(clip, **kwargs_out)

clip.set_output()