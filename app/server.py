#!/usr/bin/env python3
# Archivo: app/server.py
# Ubicacion: app/server.py (se despliega automaticamente en /opt/caribeshop/server.py via cloud-init)

import hashlib
import json
import os
import socket
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 80
UNHEALTHY_FLAG = "/tmp/unhealthy.flag"
KEY_VAULT_NAME = os.environ.get("KEY_VAULT_NAME", "")
SECRET_NAME = os.environ.get("SECRET_NAME", "db-connection-secret")


def get_imds_metadata():
    """Consulta metadatos de instancia (zona de disponibilidad y nombre VM) desde IMDS."""
    url = "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01"
    req = urllib.request.Request(url, headers={"Metadata": "true"})
    try:
        with urllib.request.urlopen(req, timeout=2) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return {
                "vm_name": data.get("name", socket.gethostname()),
                "zone": data.get("zone", "desconocida"),
                "vm_size": data.get("vmSize", "desconocido"),
                "location": data.get("location", "desconocida"),
            }
    except Exception:
        return {
            "vm_name": socket.gethostname(),
            "zone": "local",
            "vm_size": "local",
            "location": "local",
        }


def fetch_secret_fingerprint():
    """Obtiene token de Managed Identity via IMDS y lee el secreto en Key Vault sin exponer su valor."""
    if not KEY_VAULT_NAME:
        return {"status": "ERROR", "detail": "Variable KEY_VAULT_NAME no configurada"}

    # 1. Solicitar token OAuth2 a Azure IMDS
    token_url = (
        "http://169.254.169.254/metadata/identity/oauth2/token"
        "?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net"
    )
    token_req = urllib.request.Request(token_url, headers={"Metadata": "true"})
    with urllib.request.urlopen(token_req, timeout=3) as token_resp:
        token_data = json.loads(token_resp.read().decode("utf-8"))
        access_token = token_data["access_token"]

    # 2. Consultar secreto en Key Vault usando Bearer Token
    secret_url = f"https://{KEY_VAULT_NAME}.vault.azure.net/secrets/{SECRET_NAME}?api-version=7.4"
    secret_req = urllib.request.Request(
        secret_url,
        headers={"Authorization": f"Bearer {access_token}"},
    )
    with urllib.request.urlopen(secret_req, timeout=4) as secret_resp:
        secret_data = json.loads(secret_resp.read().decode("utf-8"))
        raw_value = secret_data.get("value", "")

    # 3. Calcular huella SHA-256 truncada y longitud (NUNCA retornar raw_value)
    sha256_prefix = hashlib.sha256(raw_value.encode("utf-8")).hexdigest()[:12]
    return {
        "status": "OK",
        "key_vault": KEY_VAULT_NAME,
        "secret_name": SECRET_NAME,
        "secret_length": len(raw_value),
        "sha256_fingerprint": sha256_prefix,
        "note": "Valor real protegido en memoria; solo se expone huella verificable.",
    }


class CaribeShopHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code, payload):
        body = json.dumps(payload, indent=2, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        meta = get_imds_metadata()

        # Endpoint 1: Sonda de salud para Azure Load Balancer (Requisito E2 y Prueba P2.1)
        if self.path == "/health":
            if os.path.exists(UNHEALTHY_FLAG):
                self._send_json(503, {
                    "status": "UNHEALTHY",
                    "reason": "Falla logica simulada activa (/tmp/unhealthy.flag)",
                    "instance": meta,
                })
            else:
                self._send_json(200, {
                    "status": "HEALTHY",
                    "instance": meta,
                })
            return

        # Endpoint 2: Verificacion de lectura de secreto desde Key Vault (Requisito S3)
        if self.path == "/secret-check":
            try:
                kv_result = fetch_secret_fingerprint()
                kv_result["served_by"] = meta
                self._send_json(200, kv_result)
            except urllib.error.HTTPError as e:
                self._send_json(e.code, {
                    "status": "HTTP_ERROR",
                    "code": e.code,
                    "reason": str(e.reason),
                    "served_by": meta,
                })
            except Exception as ex:
                self._send_json(500, {
                    "status": "INTERNAL_ERROR",
                    "error": type(ex).__name__,
                    "served_by": meta,
                })
            return

        # Endpoint 3: Carga controlada de CPU para pruebas de escalamiento (P1)
        if self.path.startswith("/catalog"):
            acc = 0
            for i in range(1, 35000):
                acc += (i * i) % 97
            self._send_json(200, {
                "service": "CaribeShop API - Temporada Alta",
                "endpoint": "/catalog",
                "checksum": acc,
                "served_by": meta,
            })
            return

        # Ruta Principal (/)
        self._send_json(200, {
            "application": "CaribeShop E-Commerce Platform",
            "status": "ONLINE",
            "served_by": meta,
            "endpoints": ["/", "/catalog", "/health", "/secret-check"],
        })

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), CaribeShopHandler)
    print(f"CaribeShop server escuchando en puerto {PORT}...")
    server.serve_forever()


