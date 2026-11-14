# Modelo de reconocimiento facial

`face_recognition_sface_2021dec.onnx` (SFace, OpenCV Zoo, licencia Apache 2.0, ~37 MB).
No se guarda en git. Para descargarlo y verificar su SHA-256:

    bash tool/descargar_modelo.sh

GitHub Actions lo descarga automáticamente antes de compilar el APK. El servidor usa el
mismo modelo (`laborlog_backend/modelos/descargar_modelo.py`).
