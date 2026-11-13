"""Scene Builder - find the face points on a front photo automatically.

Run by Avatar Studio ("Find Points Automatically") with Blender's own Python:
    blender -b --python face_points.py -- <photo> <out.json> <library folder>

Uses Google's MediaPipe Face Landmarker. The first time, it installs the
mediapipe package into <library folder> and downloads the small face model
(about 4 MB), so it needs an internet connection once. The result is written to
<out.json> as {"points": {name: [u, v]}} with u, v from 0 to 1 measured from the
picture's top-left, or {"error": "..."} if it couldn't find a face.
"""
import json
import os
import subprocess
import sys
import urllib.request

MODEL_URL = "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"

# MediaPipe face mesh indices -> Scene Builder face points. "Left"/"right"
# mean the picture's left/right (the person's right eye is on the left).
POINTS = {
    "eye_l_out": [33], "eye_l_in": [133], "eye_r_in": [362], "eye_r_out": [263],
    "brow_l": [105, 52], "brow_r": [334, 282],
    "nose_tip": [1], "nose_l": [129], "nose_r": [358],
    "mouth_l": [61], "mouth_r": [291], "lip_top": [0], "lip_bottom": [17], "chin": [152],
}
# The outline of the face, going round from the top of the forehead.
FACE_OVAL = [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152,
             148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109]


def log(text):
    print("[face points] " + text, flush=True)


def argv():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if len(args) < 3:
        raise SystemExit("usage: face_points.py -- <photo> <out.json> <library folder>")
    return args[0], args[1], args[2]


def python_exe():
    """Blender's Python program (sys.executable is Blender itself in old versions)."""
    exe = sys.executable
    if os.path.basename(exe).lower().startswith("python"):
        return exe
    try:
        import bpy  # noqa: F401
        from bpy.app import binary_path_python  # Blender < 2.91
        return binary_path_python
    except Exception:  # noqa: BLE001
        pass
    base = os.path.join(sys.prefix, "bin")
    for name in os.listdir(base) if os.path.isdir(base) else []:
        if name.lower().startswith("python"):
            return os.path.join(base, name)
    return exe


def ensure_mediapipe(lib):
    os.makedirs(lib, exist_ok=True)
    if lib not in sys.path:
        sys.path.insert(0, lib)
    try:
        import mediapipe  # noqa: F401
        return True
    except Exception:  # noqa: BLE001
        pass
    log("Installing MediaPipe (one time only, needs the internet)...")
    exe = python_exe()
    subprocess.call([exe, "-m", "ensurepip", "--upgrade"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    result = subprocess.run([exe, "-m", "pip", "install", "--upgrade", "--target", lib, "mediapipe"],
                            capture_output=True, text=True)
    if result.returncode != 0:
        log((result.stdout + result.stderr)[-1500:])
        return False
    import importlib
    importlib.invalidate_caches()
    try:
        import mediapipe  # noqa: F401
        return True
    except Exception as error:  # noqa: BLE001
        log("MediaPipe was installed but can't be loaded: %s" % error)
        return False


def ensure_model(lib):
    path = os.path.join(lib, "face_landmarker.task")
    if os.path.exists(path) and os.path.getsize(path) > 100000:
        return path
    log("Downloading the face model...")
    urllib.request.urlretrieve(MODEL_URL, path + ".part")
    os.replace(path + ".part", path)
    return path


def _crossing(outline, y, side_sign, centre_x):
    """Where the face outline crosses height y on one side of the face."""
    best = None
    for i in range(len(outline)):
        (x0, y0), (x1, y1) = outline[i], outline[(i + 1) % len(outline)]
        if (y0 - y) * (y1 - y) > 0 or y0 == y1:
            continue
        t = (y - y0) / (y1 - y0)
        x = x0 + (x1 - x0) * t
        if (x - centre_x) * side_sign <= 0:
            continue
        if best is None or abs(x - centre_x) > abs(best - centre_x):
            best = x
    return best


def find_points(photo, model):
    import mediapipe as mp
    from mediapipe.tasks import python as mp_tasks
    from mediapipe.tasks.python import vision

    options = vision.FaceLandmarkerOptions(base_options=mp_tasks.BaseOptions(model_asset_path=model), num_faces=1)
    with vision.FaceLandmarker.create_from_options(options) as landmarker:
        image = mp.Image.create_from_file(photo)
        result = landmarker.detect(image)
    if not result.face_landmarks:
        return None
    marks = result.face_landmarks[0]
    w, h = image.width, image.height

    def px(i):
        return (marks[i].x * w, marks[i].y * h)

    points = {}
    for name, indices in POINTS.items():
        xs = [px(i)[0] for i in indices]
        ys = [px(i)[1] for i in indices]
        points[name] = (sum(xs) / len(xs), sum(ys) / len(ys))
    outline = [px(i) for i in FACE_OVAL]
    centre_x = (points["eye_l_in"][0] + points["eye_r_in"][0]) / 2.0
    eye_y = (points["eye_l_out"][1] + points["eye_l_in"][1] + points["eye_r_in"][1] + points["eye_r_out"][1]) / 4.0
    mouth_y = (points["mouth_l"][1] + points["mouth_r"][1]) / 2.0
    for name, y, sign in (("cheek_l", eye_y, -1), ("cheek_r", eye_y, 1), ("jaw_l", mouth_y, -1), ("jaw_r", mouth_y, 1)):
        x = _crossing(outline, y, sign, centre_x)
        if x is None:
            x = min(p[0] for p in outline) if sign < 0 else max(p[0] for p in outline)
        points[name] = (x, y)
    return {k: [min(max(x / w, 0.0), 1.0), min(max(y / h, 0.0), 1.0)] for k, (x, y) in points.items()}


def detect(photo, out, lib):
    """Runs in a fresh Python (not inside Blender), so MediaPipe's own numpy and
    OpenCV never clash with the ones Blender has loaded."""
    sys.path.insert(0, lib)
    try:
        points = find_points(photo, os.path.join(lib, "face_landmarker.task"))
        answer = {"points": points} if points else \
            {"error": "No face was found in the photo. Try a clearer, front-facing photo, or mark the points by hand."}
    except Exception as error:  # noqa: BLE001
        answer = {"error": "Automatic points failed (%s). Mark the points by hand instead." % error}
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(answer, handle, indent=1)


def main():
    if "--detect" in sys.argv:
        i = sys.argv.index("--detect")
        detect(*sys.argv[i + 1:i + 4])
        return
    photo, out, lib = argv()
    answer = None
    try:
        if not ensure_mediapipe(lib):
            answer = {"error": "MediaPipe couldn't be installed (is the computer online?). Mark the points by hand instead."}
        else:
            ensure_model(lib)
            if os.path.exists(out):
                os.remove(out)
            env = dict(os.environ, PYTHONNOUSERSITE="1")
            env.pop("PYTHONPATH", None)
            result = subprocess.run([python_exe(), os.path.abspath(__file__), "--detect", photo, out, lib],
                                    capture_output=True, text=True, env=env)
            if not os.path.exists(out):
                answer = {"error": "Automatic points failed: " + (result.stderr or result.stdout)[-600:]}
    except Exception as error:  # noqa: BLE001
        answer = {"error": "Automatic points failed (%s). Mark the points by hand instead." % error}
    if answer is not None:
        with open(out, "w", encoding="utf-8") as handle:
            json.dump(answer, handle, indent=1)
    with open(out, encoding="utf-8") as handle:
        result = json.load(handle)
    log(result["error"] if "error" in result else "Found %d face points." % len(result["points"]))


if __name__ == "__main__":
    main()
