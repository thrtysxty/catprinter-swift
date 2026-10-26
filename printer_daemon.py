#!/usr/bin/env python3
"""
Native macOS Thermal Printer Relay Service
Runs locally on macOS packing station to bridge print jobs from browser and Bizinfra
to Mini Printer-1125 over Bluetooth Low Energy (CoreBluetooth).
Zero external dependencies.
"""

import sys
import os
import json
import subprocess
import threading
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
CATPRINTER_BIN = SCRIPT_DIR / "catprinter"
PORT = int(os.environ.get("PRINTER_DAEMON_PORT", 8001))

def derive_abbr(crate_id):
    if not crate_id:
        return "GEN"
    cid = crate_id.strip().upper()
    if cid.startswith("STUDIO"):
        return "ST01"
    if cid.startswith("OVERSIZE"):
        return "OV01"
    if cid.startswith("APP"):
        return "APP01"
    if cid.startswith("BTN") or cid.startswith("BUTTON"):
        return "BTN01"
    if cid.startswith("CARD"):
        return "CARD01"
    return cid[:5]

def execute_print_job(payload):
    if not CATPRINTER_BIN.exists():
        return False, f"Binary not found: {CATPRINTER_BIN}"

    job_type = payload.get("type", "item").lower()
    
    if job_type == "crate":
        crate_id = str(payload.get("crate_id") or payload.get("id") or "").strip()
        if not crate_id:
            return False, "Crate ID is required for crate label"
        name = str(payload.get("name") or "").strip()
        location = str(payload.get("location") or "").strip()
        category = str(payload.get("category") or "General Resale").strip()
        abbr = str(payload.get("abbr") or derive_abbr(crate_id)).strip()
        crate_type = str(payload.get("crate_type") or "physical").strip()
        nfc_uri = str(payload.get("nfc_uri") or f"http://localhost:8000/crate/{crate_id}").strip()
        
        cmd = [
            str(CATPRINTER_BIN),
            "--label-type", "crate",
            "--crate-id", crate_id,
            "--name", name,
            "--location", location,
            "--category", category,
            "--abbr", abbr,
            "--crate-type", crate_type,
            "--nfc-uri", nfc_uri
        ]
        label_desc = f"Crate '{crate_id}'"
    else:
        sku = str(payload.get("sku") or "").strip().upper()
        title = str(payload.get("title") or "").strip()
        crate = str(payload.get("crate") or payload.get("crate_id") or "").strip()
        category = str(payload.get("category") or "General Resale").strip()
        price = str(payload.get("price") or payload.get("est_sale_price") or "").strip()
        if price and not price.startswith("$") and price.replace(".", "", 1).isdigit():
            try:
                price = f"${float(price):.2f}"
            except ValueError:
                pass

        if not sku:
            return False, "SKU is required for item label"

        cmd = [
            str(CATPRINTER_BIN),
            "--sku", sku,
            "--title", title,
            "--crate", crate,
            "--category", category,
            "--price", price
        ]
        label_desc = f"SKU '{sku}'"

    try:
        print(f"[PrinterDaemon] Invoking catprinter for {label_desc}...")
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=25)
        if res.returncode == 0:
            print(f"[PrinterDaemon] SUCCESS: Printed {label_desc}")
            return True, f"Printed {label_desc} successfully"
        else:
            err = res.stderr.strip() or res.stdout.strip()
            print(f"[PrinterDaemon] Notice ({res.returncode}): {err}")
            return False, err
    except Exception as e:
        print(f"[PrinterDaemon] Error: {e}")
        return False, str(e)


class PrinterRequestHandler(BaseHTTPRequestHandler):
    def _send_cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors()
        self.end_headers()

    def do_GET(self):
        if self.path in ["/status", "/api/status", "/api/printer/status"]:
            has_bin = CATPRINTER_BIN.exists()
            data = {
                "status": "ready" if has_bin else "missing_binary",
                "service": "Native macOS BLE Thermal Printer Relay",
                "printer": "Mini Printer-1125",
                "binary": str(CATPRINTER_BIN),
                "ready": has_bin
            }
            body = json.dumps(data).encode("utf-8")
            self.send_response(200)
            self._send_cors()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self._send_cors()
            self.end_headers()
            self.wfile.write(b"Not found")

    def do_POST(self):
        if self.path in ["/print", "/api/print", "/api/print-label"]:
            try:
                content_len = int(self.headers.get("Content-Length", 0))
                raw_body = self.rfile.read(content_len).decode("utf-8")
                payload = json.loads(raw_body) if raw_body else {}
            except Exception as e:
                self.send_response(400)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": f"Invalid JSON: {e}"}).encode("utf-8"))
                return

            # Execute print in background or synchronously
            success, msg = execute_print_job(payload)
            resp = {
                "success": success,
                "message": msg,
                "sku": payload.get("sku"),
                "crate_id": payload.get("crate_id")
            }
            body = json.dumps(resp).encode("utf-8")
            self.send_response(200 if success else 500)
            self._send_cors()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self._send_cors()
            self.end_headers()
            self.wfile.write(b"Not found")

    def log_message(self, format, *args):
        # Concise logging
        sys.stderr.write(f"[PrinterDaemon] {self.address_string()} - {format % args}\n")


def run():
    # Bind to all interfaces so reverse tunnel and local browser can connect
    server_address = ("0.0.0.0", PORT)
    httpd = HTTPServer(server_address, PrinterRequestHandler)
    print(f"==================================================")
    print(f"  Mini Printer Relay Daemon Active on port {PORT}")
    print(f"  Target Binary: {CATPRINTER_BIN}")
    print(f"==================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Printer Relay Daemon...")
        httpd.server_close()


if __name__ == "__main__":
    run()
