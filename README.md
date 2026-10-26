# CatPrinter Swift 🖨️⚡

**Native macOS CoreBluetooth driver & HTTP relay daemon for portable Bluetooth Low Energy (BLE) thermal mini-printers.**

Designed for high-velocity packing stations, warehouse crate labeling, and inventory management. Directly interfaces macOS with standard 58mm BLE thermal printers (e.g., Cat Printer, GB01, MX06, POS-58) without requiring third-party drivers, CUPS filters, or proprietary iOS/Android vendor apps.

---

## 🌟 Highlights

- **Native Apple CoreBluetooth:** Built in pure Swift using Apple's native `CoreBluetooth`, `CoreGraphics`, and `AppKit` frameworks. Zero external binary or SPM dependencies.
- **Reverse-Engineered Protocol:** Direct binary packet framing, custom CRC-8 checksum calculation, thermal energy/density control (`0xAF`), drawing mode modulation (`0xBE`), and lattice feed commands.
- **Dual Label Pipeline:**
  - **Item / SKU Labels:** Formatted SKU, title, crate identifier, and automated Code-128 / QR-compatible bitmapped rendering.
  - **Warehouse Crate Labels:** Large bold typography, tote sequence, category designation, and direct NDEF/NFC URI integration.
- **Local HTTP Relay Daemon:** A lightweight, zero-dependency Python service that bridges incoming JSON print requests from browser interfaces, ERPs, or remote warehouse servers directly to the printer over BLE.
- **Live Preview & Test Modes:** Supports off-device preview generation, rendering directly to `.png` or simulated bitmap output for layout verification.

---

## 🏗️ Architecture & Packet Framing

The driver implements the reverse-engineered binary protocol used by BLE micro thermal printers:

```
┌───────────┬───────────┬───────────┬─────────────┬──────────────┬────────────┬───────────┐
│ Preamble  │  Command  │ Reserved  │ Payload Len │ Data Payload │ Checksum   │ Postamble │
│ 0x51 0x78 │ 1 byte    │ 0x00      │ 2 bytes (LE)│ N bytes      │ 1 byte CRC │ 0xFF      │
└───────────┴───────────┴───────────┴─────────────┴──────────────┴────────────┴───────────┘
```

### Key Protocol Commands
- `0xA4`: Set print quality / thermal density level (Default: `0x36` Ultra Quality)
- `0xAF`: Set printhead heating energy (2-byte Little Endian)
- `0xBE`: Drawing mode selection (`0x00` Bitmap Graphics, `0x01` Plain Text)
- `0xBD`: Paper feed line count
- `0xA6`: Lattice print bracket control (Start / End)

---

## 🚀 Quickstart

### 1. Prerequisites
- macOS 12.0+ with Bluetooth enabled
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3.9+ (for relay daemon)

### 2. Build the Swift CLI
You can compile the binary using `make` or directly with `swiftc`:

```bash
# Using Makefile
make build

# Or direct compilation
swiftc -O -framework Foundation -framework CoreBluetooth -framework CoreGraphics -framework CoreImage -framework AppKit catprinter.swift -o catprinter
```

### 3. Print Directly via CLI
Power on your BLE thermal printer and run:

```bash
# Print an item SKU label
./catprinter --label-type item --sku "C01-004" --title "Mid-Century Ceramic Vase" --crate "C01"

# Print a warehouse crate label
./catprinter --label-type crate --crate-id "C01" --name "Vintage Ceramics & Pottery" --location "Shelf A2" --category "Ceramics"

# Generate a visual PNG preview without sending to Bluetooth
./catprinter --preview preview.png --label-type item --sku "C01-004" --title "Mid-Century Ceramic Vase"
```

---

## 📡 HTTP Relay Daemon

To allow web dashboards (e.g., [ResaleOS Inventory Engine](https://github.com/thrtysxty/resaleos-inventory-engine)) to trigger physical labels seamlessly:

```bash
# Start relay daemon on port 8001
python3 printer_daemon.py
```

### Sample HTTP Print Request:
```bash
curl -X POST http://localhost:8001/print \
  -H "Content-Type: application/json" \
  -d '{
    "type": "item",
    "sku": "C01-005",
    "title": "Haeger Pottery 1950s Planter",
    "crate": "C01"
  }'
```

---

## 📁 Repository Structure

```
.
├── catprinter.swift       # Native Swift CoreBluetooth CLI & bitmap rendering engine
├── printer_daemon.py      # HTTP relay service bridging webhooks/browsers to BLE CLI
├── Makefile               # Compilation and installation recipes
├── LICENSE                # MIT License
└── README.md
```

---

## 📄 License

MIT License. Designed and maintained by **Jeremy Thiessen** ([@thrtysxty](https://github.com/thrtysxty)).
