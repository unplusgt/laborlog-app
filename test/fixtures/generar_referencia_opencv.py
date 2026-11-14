"""Genera la referencia para test/rostro_test.dart: una imagen sintética y su recorte
alineado hecho por OpenCV (FaceRecognizerSF.alignCrop, el mismo método del servidor).

    python test/fixtures/generar_referencia_opencv.py RUTA/face_recognition_sface_2021dec.onnx
"""
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
ANCHO, ALTO = 200, 160
# Ojos, nariz y comisuras (cara ligeramente inclinada), en el orden de YuNet
PUNTOS = [(70.0, 60.0), (120.0, 55.0), (97.0, 85.0), (75.0, 110.0), (118.0, 106.0)]

y, x = np.mgrid[0:ALTO, 0:ANCHO].astype(np.float64)
r = 128 + 100 * np.sin(x / 17.0) * np.cos(y / 23.0)
g = 128 + 90 * np.cos(x / 11.0 + y / 29.0)
b = 128 + 80 * np.sin((x + y) / 19.0)
rgb = np.clip(np.stack([r, g, b], axis=-1), 0, 255).round().astype(np.uint8)

rec = cv2.FaceRecognizerSF.create(sys.argv[1], "")
cara = np.array([[0, 0, ANCHO, ALTO, *[c for p in PUNTOS for c in p], 0.99]], dtype=np.float32)
recorte_bgr = rec.alignCrop(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), cara)
recorte_rgb = cv2.cvtColor(recorte_bgr, cv2.COLOR_BGR2RGB)

open(os.path.join(AQUI, "imagen_200x160.rgb"), "wb").write(rgb.tobytes())
open(os.path.join(AQUI, "recorte_opencv_112.rgb"), "wb").write(recorte_rgb.tobytes())
print("ok", recorte_rgb.shape)
