#!/usr/bin/env bash
# Descarga el modelo de reconocimiento facial SFace (OpenCV Zoo, licencia Apache 2.0)
# a assets/modelos/ y verifica su SHA-256. Lo usa GitHub Actions antes de compilar.
#
#   bash tool/descargar_modelo.sh
set -euo pipefail

NOMBRE="face_recognition_sface_2021dec.onnx"
URL="https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/$NOMBRE"
SHA256="0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79"
DESTINO="$(cd "$(dirname "$0")/.." && pwd)/assets/modelos/$NOMBRE"

mkdir -p "$(dirname "$DESTINO")"
if [ -f "$DESTINO" ] && echo "$SHA256  $DESTINO" | sha256sum -c --status; then
  echo "Modelo ya presente: $DESTINO"
  exit 0
fi
curl -fsSL -o "$DESTINO.tmp" "$URL"
if ! echo "$SHA256  $DESTINO.tmp" | sha256sum -c --status; then
  rm -f "$DESTINO.tmp"
  echo "ERROR: el modelo descargado no coincide con la suma SHA-256 esperada" >&2
  exit 1
fi
mv "$DESTINO.tmp" "$DESTINO"
echo "Modelo verificado: $DESTINO"
