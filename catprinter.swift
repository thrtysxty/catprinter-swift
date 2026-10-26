import Foundation
import CoreBluetooth
import CoreGraphics
import CoreImage
import AppKit

// CRC-8 table matching cat printer specifications
let crc8Table: [UInt8] = [
    0x00, 0x07, 0x0e, 0x09, 0x1c, 0x1b, 0x12, 0x15, 0x38, 0x3f, 0x36, 0x31,
    0x24, 0x23, 0x2a, 0x2d, 0x70, 0x77, 0x7e, 0x79, 0x6c, 0x6b, 0x62, 0x65,
    0x48, 0x4f, 0x46, 0x41, 0x54, 0x53, 0x5a, 0x5d, 0xe0, 0xe7, 0xee, 0xe9,
    0xfc, 0xfb, 0xf2, 0xf5, 0xd8, 0xdf, 0xd6, 0xd1, 0xc4, 0xc3, 0xca, 0xcd,
    0x90, 0x97, 0x9e, 0x99, 0x8c, 0x8b, 0x82, 0x85, 0xa8, 0xaf, 0xa6, 0xa1,
    0xb4, 0xb3, 0xba, 0xbd, 0xc7, 0xc0, 0xc9, 0xce, 0xdb, 0xdc, 0xd5, 0xd2,
    0xff, 0xf8, 0xf1, 0xf6, 0xe3, 0xe4, 0xed, 0xea, 0xb7, 0xb0, 0xb9, 0xbe,
    0xab, 0xac, 0xa5, 0xa2, 0x8f, 0x88, 0x81, 0x86, 0x93, 0x94, 0x9d, 0x9a,
    0x27, 0x20, 0x29, 0x2e, 0x3b, 0x3c, 0x35, 0x32, 0x1f, 0x18, 0x11, 0x16,
    0x03, 0x04, 0x0d, 0x0a, 0x57, 0x50, 0x59, 0x5e, 0x4b, 0x4c, 0x45, 0x42,
    0x6f, 0x68, 0x61, 0x66, 0x73, 0x74, 0x7d, 0x7a, 0x89, 0x8e, 0x87, 0x80,
    0x95, 0x92, 0x9b, 0x9c, 0xb1, 0xb6, 0xbf, 0xb8, 0xad, 0xaa, 0xa3, 0xa4,
    0xf9, 0xfe, 0xf7, 0xf0, 0xe5, 0xe2, 0xeb, 0xec, 0xc1, 0xc6, 0xcf, 0xc8,
    0xdd, 0xda, 0xd3, 0xd4, 0x69, 0x6e, 0x67, 0x60, 0x75, 0x72, 0x7b, 0x7c,
    0x51, 0x56, 0x5f, 0x58, 0x4d, 0x4a, 0x43, 0x44, 0x19, 0x1e, 0x17, 0x10,
    0x05, 0x02, 0x0b, 0x0c, 0x21, 0x26, 0x2f, 0x28, 0x3d, 0x3a, 0x33, 0x34,
    0x4e, 0x49, 0x40, 0x47, 0x52, 0x55, 0x5c, 0x5b, 0x76, 0x71, 0x78, 0x7f,
    0x6a, 0x6d, 0x64, 0x63, 0x3e, 0x39, 0x30, 0x37, 0x22, 0x25, 0x2c, 0x2b,
    0x06, 0x01, 0x08, 0x0f, 0x1a, 0x1d, 0x14, 0x13, 0xae, 0xa9, 0xa0, 0xa7,
    0xb2, 0xb5, 0xbc, 0xbb, 0x96, 0x91, 0x98, 0x9f, 0x8a, 0x8d, 0x84, 0x83,
    0xde, 0xd9, 0xd0, 0xd7, 0xc2, 0xc5, 0xcc, 0xcb, 0xe6, 0xe1, 0xe8, 0xef,
    0xfa, 0xfd, 0xf4, 0xf3
]

func chkSum(_ data: [UInt8], start: Int, length: Int) -> UInt8 {
    var crc: UInt8 = 0
    for i in start..<(start + length) {
        let index = Int(crc ^ data[i]) & 0xFF
        crc = crc8Table[index]
    }
    return crc & 0xFF
}

let CMD_GET_DEV_STATE: [UInt8] = [0x51, 0x78, 0xA3, 0x00, 0x01, 0x00, 0x00, 0x00, 0xFF]

func cmdSetQuality(_ level: UInt8 = 54) -> [UInt8] {
    // 54 = 0x36 ('6') = Ultra Quality / Maximum print density
    var arr: [UInt8] = [0x51, 0x78, 0xA4, 0x00, 0x01, 0x00, level, 0, 0xFF]
    arr[7] = chkSum(arr, start: 6, length: 1)
    return arr
}

let CMD_LATTICE_START: [UInt8] = [0x51, 0x78, 0xA6, 0x00, 11, 0x00, 170, 85, 23, 56, 68, 95, 95, 95, 68, 56, 44, 161, 0xFF]
let CMD_LATTICE_END: [UInt8] = [0x51, 0x78, 0xA6, 0x00, 11, 0x00, 170, 85, 23, 0, 0, 0, 0, 0, 0, 0, 23, 17, 0xFF]
let CMD_SET_PAPER: [UInt8] = [0x51, 0x78, 0xA1, 0x00, 2, 0x00, 48, 0, 249, 0xFF]

func cmdSetEnergy(_ val: UInt16 = 0xFFFF) -> [UInt8] {
    // 0xAF: Set Energy - 2-byte Little Endian (Low byte, High byte)
    var arr: [UInt8] = [0x51, 0x78, 0xAF, 0x00, 2, 0x00, UInt8(val & 0xFF), UInt8((val >> 8) & 0xFF), 0, 0xFF]
    arr[8] = chkSum(arr, start: 6, length: 2)
    return arr
}

func cmdSetDrawingMode(_ mode: UInt8 = 0) -> [UInt8] {
    // 0xBE: Drawing Mode - 0 for Images/Bitmaps, 1 for Text
    var arr: [UInt8] = [0x51, 0x78, 0xBE, 0x00, 1, 0x00, mode, 0, 0xFF]
    arr[7] = chkSum(arr, start: 6, length: 1)
    return arr
}

func cmdFeedPaper(_ howMuch: UInt8) -> [UInt8] {
    var arr: [UInt8] = [0x51, 0x78, 0xBD, 0x00, 1, 0x00, howMuch, 0, 0xFF]
    arr[7] = chkSum(arr, start: 6, length: 1)
    return arr
}

func encodeRunLengthRepetition(_ n: Int, _ val: Int) -> [UInt8] {
    var res: [UInt8] = []
    var count = n
    while count > 0x7F {
        res.append(UInt8(0x7F | (val << 7)))
        count -= 0x7F
    }
    if count > 0 {
        res.append(UInt8((val << 7) | count))
    }
    return res
}

func runLengthEncode(_ row: [UInt8]) -> [UInt8] {
    var res: [UInt8] = []
    var count = 0
    var lastVal: Int = -1
    for val in row {
        let v = Int(val)
        if v == lastVal {
            count += 1
        } else {
            if lastVal != -1 {
                res.append(contentsOf: encodeRunLengthRepetition(count, lastVal))
            }
            count = 1
            lastVal = v
        }
    }
    if count > 0 && lastVal != -1 {
        res.append(contentsOf: encodeRunLengthRepetition(count, lastVal))
    }
    return res
}

func byteEncode(_ row: [UInt8]) -> [UInt8] {
    var res: [UInt8] = []
    for chunkStart in stride(from: 0, to: row.count, by: 8) {
        var byte: UInt8 = 0
        for bitIndex in 0..<8 {
            if (chunkStart + bitIndex) < row.count && row[chunkStart + bitIndex] != 0 {
                byte |= (1 << bitIndex)
            }
        }
        res.append(byte)
    }
    return res
}

func cmdPrintRow(_ row: [UInt8]) -> [UInt8] {
    let rle = runLengthEncode(row)
    if rle.count > (384 / 8) {
        let rawBytes = byteEncode(row)
        var arr: [UInt8] = [0x51, 0x78, 0xA2, 0x00, UInt8(rawBytes.count & 0xFF), 0x00]
        arr.append(contentsOf: rawBytes)
        arr.append(0x00) // placeholder for checksum
        arr.append(0xFF)
        let lastIdx = arr.count - 2
        arr[lastIdx] = chkSum(arr, start: 6, length: rawBytes.count)
        return arr
    } else {
        var arr: [UInt8] = [0x51, 0x78, 0xBF, 0x00, UInt8(rle.count & 0xFF), 0x00]
        arr.append(contentsOf: rle)
        arr.append(0x00) // placeholder for checksum
        arr.append(0xFF)
        let lastIdx = arr.count - 2
        arr[lastIdx] = chkSum(arr, start: 6, length: rle.count)
        return arr
    }
}

// Generate SKU Label Bitmap (Width: 384 px)
func renderSkuLabel(sku: String, title: String, crate: String, category: String, price: String, flipHorizontal: Bool = true) -> [[UInt8]] {
    let width = 384
    let height = 340
    let colorSpace = CGColorSpaceCreateDeviceGray()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else {
        return []
    }

    // Fill background with white (255)
    context.setFillColor(gray: 1.0, alpha: 1.0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = graphicsContext

    // 1. Inverted Header Banner (Solid Black Box with Crisp White Text - 15pt Bold)
    let bannerRect = CGRect(x: 8, y: height - 34, width: width - 16, height: 28)
    context.setFillColor(gray: 0.0, alpha: 1.0)
    context.fill(bannerRect)

    let headerStyle = NSMutableParagraphStyle()
    headerStyle.alignment = .center
    let headerAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 15),
        .foregroundColor: NSColor.white,
        .paragraphStyle: headerStyle
    ]
    NSString(string: "=== RESALE OS INVENTORY ===").draw(in: CGRect(x: 8, y: height - 31, width: width - 16, height: 22), withAttributes: headerAttr)

    // 2. Extra Heavy Bold SKU with Dynamic Font Auto-Fit
    let skuStyle = NSMutableParagraphStyle()
    skuStyle.alignment = .center

    // Dynamically calculate font size to comfortably fit within 384px with 20px margins
    let maxSkuW = CGFloat(width - 40)
    var skuFontSize: CGFloat = 46.0
    while skuFontSize > 18.0 {
        let testFont = NSFont.systemFont(ofSize: skuFontSize, weight: .heavy)
        let testSize = (sku as NSString).size(withAttributes: [.font: testFont])
        if testSize.width <= maxSkuW {
            break
        }
        skuFontSize -= 1.0
    }

    let skuAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: skuFontSize, weight: .heavy),
        .foregroundColor: NSColor.black,
        .paragraphStyle: skuStyle
    ]
    NSString(string: sku).draw(in: CGRect(x: 0, y: height - 84, width: width, height: 48), withAttributes: skuAttr)

    // 3. Crisp Barcode (Code 128) - Exact Integer Scaling & Interpolation Quality None
    let barcodeY: CGFloat = CGFloat(height) - 134.0
    let barcodeH: CGFloat = 42.0
    if let filter = CIFilter(name: "CICode128BarcodeGenerator") {
        filter.setValue(sku.data(using: .ascii), forKey: "inputMessage")
        if let output = filter.outputImage {
            let availableW = CGFloat(width - 48)
            var moduleScale = floor(availableW / output.extent.width)
            if moduleScale < 1.0 { moduleScale = 1.0 }
            var scaleX = moduleScale
            if (output.extent.width * scaleX) > availableW {
                scaleX = availableW / output.extent.width
            }
            let finalBarcodeW = output.extent.width * scaleX
            let startX = (CGFloat(width) - finalBarcodeW) / 2.0
            let scaleY = barcodeH / output.extent.height
            let scaledImage = output.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            let ciContext = CIContext(options: [.useSoftwareRenderer: false])
            if let cgBarcode = ciContext.createCGImage(scaledImage, from: scaledImage.extent) {
                context.saveGState()
                context.interpolationQuality = .none
                context.draw(cgBarcode, in: CGRect(x: startX, y: barcodeY, width: finalBarcodeW, height: barcodeH))
                context.restoreGState()
            }
        }
    }

    // 4. Item Title (Prominent 18pt Bold with crisp kerning)
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.alignment = .center
    titleStyle.lineBreakMode = .byTruncatingTail
    let titleAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: titleStyle,
        .kern: 0.4
    ]
    NSString(string: title).draw(in: CGRect(x: 8, y: height - 176, width: width - 16, height: 34), withAttributes: titleAttr)

    // 5. Crate & Category box (Crisp 2.5 pt border, 17pt Crate/Price, 15pt Category)
    context.setStrokeColor(gray: 0.0, alpha: 1.0)
    context.setLineWidth(2.5)
    context.stroke(CGRect(x: 10, y: height - 256, width: width - 20, height: 72))

    let metaStyle = NSMutableParagraphStyle()
    metaStyle.alignment = .left
    let metaAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 17, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: metaStyle,
        .kern: 0.3
    ]
    let crateText = "CRATE: \(crate.isEmpty ? "None" : crate)   •   \(price.isEmpty ? "" : price)"
    NSString(string: crateText).draw(in: CGRect(x: 18, y: height - 222, width: width - 36, height: 26), withAttributes: metaAttr)

    let catStyle = NSMutableParagraphStyle()
    catStyle.alignment = .left
    let catAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: catStyle,
        .kern: 0.3
    ]
    NSString(string: "CATEGORY: \(category.isEmpty ? "General" : category)").draw(in: CGRect(x: 18, y: height - 248, width: width - 36, height: 22), withAttributes: catAttr)

    // 6. Footer date (12pt Bold)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
    let dateStr = dateFormatter.string(from: Date())
    let footerStyle = NSMutableParagraphStyle()
    footerStyle.alignment = .center
    let footerAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: footerStyle,
        .kern: 0.5
    ]
    NSString(string: "* * *   INTAKE: \(dateStr)   * * *").draw(in: CGRect(x: 0, y: height - 286, width: width, height: 20), withAttributes: footerAttr)

    // Extract pixel buffer
    guard let dataPtr = context.data else { return [] }
    let ptr = dataPtr.bindMemory(to: UInt8.self, capacity: width * height)

    // Binarize with threshold 210:
    // Segments dark strokes cleanly from white paper with open counters and zero muddy blur
    var rawGrid = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)
    for y in 0..<height {
        let flippedY = (height - 1) - y // top to bottom
        for x in 0..<width {
            let pixelVal = ptr[flippedY * width + x]
            rawGrid[y][x] = (pixelVal < 210) ? 1 : 0
        }
    }

    // The mini thermal printer hardware scans dots physically from right-to-left.
    // When flipHorizontal is true, reverse each row horizontally so text and barcodes print correctly left-to-right (unmirrored).
    var outputRows: [[UInt8]] = []
    for row in rawGrid {
        if flipHorizontal {
            outputRows.append(Array(row.reversed()))
        } else {
            outputRows.append(row)
        }
    }

    // Add trailing blank rows for paper separation
    let blankRow = [UInt8](repeating: 0, count: width)
    for _ in 0..<20 {
        outputRows.append(blankRow)
    }

    return outputRows
}

func deriveAbbrFromId(_ id: String) -> String {
    let clean = id.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    return clean.isEmpty ? id : String(clean.prefix(6)).uppercased()
}

// Generate Crate / Tote Creation Label Bitmap (Width: 384 px, Height: 420 px)
func renderCrateLabel(
    crateId: String,
    name: String,
    location: String,
    category: String,
    abbr: String,
    crateType: String,
    nfcUri: String,
    flipHorizontal: Bool = true
) -> [[UInt8]] {
    let width = 384
    let height = 420
    let colorSpace = CGColorSpaceCreateDeviceGray()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else {
        return []
    }

    // Fill background with white (255)
    context.setFillColor(gray: 1.0, alpha: 1.0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = graphicsContext

    // 1. Inverted Header Banner (Solid Black Box with Crisp White Text - 15pt Bold)
    let bannerRect = CGRect(x: 8, y: height - 34, width: width - 16, height: 28)
    context.setFillColor(gray: 0.0, alpha: 1.0)
    context.fill(bannerRect)

    let headerStyle = NSMutableParagraphStyle()
    headerStyle.alignment = .center
    let headerAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 15),
        .foregroundColor: NSColor.white,
        .paragraphStyle: headerStyle,
        .kern: 0.4
    ]
    NSString(string: "=== STORAGE CRATE MANIFEST ===").draw(in: CGRect(x: 8, y: height - 31, width: width - 16, height: 22), withAttributes: headerAttr)

    // 2. Extra Heavy Bold Crate ID (48pt Heavy)
    let idStyle = NSMutableParagraphStyle()
    idStyle.alignment = .center
    let idAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 48, weight: .heavy),
        .foregroundColor: NSColor.black,
        .paragraphStyle: idStyle,
        .kern: 0.8
    ]
    NSString(string: crateId).draw(in: CGRect(x: 0, y: height - 86, width: width, height: 50), withAttributes: idAttr)

    // 3. Crate Name / Descriptor (18pt Heavy Bold)
    let nameStyle = NSMutableParagraphStyle()
    nameStyle.alignment = .center
    nameStyle.lineBreakMode = .byTruncatingTail
    let nameAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .heavy),
        .foregroundColor: NSColor.black,
        .paragraphStyle: nameStyle,
        .kern: 0.4
    ]
    let displayName = name.isEmpty ? "Storage Tote Manifest" : name
    NSString(string: displayName).draw(in: CGRect(x: 8, y: height - 118, width: width - 16, height: 28), withAttributes: nameAttr)

    // 4. Interactive QR Code & NFC Fob Target Zone
    let targetUri = nfcUri.isEmpty ? "http://localhost:8000/crate/\(crateId)" : nfcUri
    let qrSize: CGFloat = 92.0
    let qrX: CGFloat = 20.0
    let qrY: CGFloat = CGFloat(height) - 222.0

    // 4a. QR Code on Left (Integer scaled, nearest neighbor)
    if let qrFilter = CIFilter(name: "CIQRCodeGenerator") {
        qrFilter.setValue(targetUri.data(using: .utf8), forKey: "inputMessage")
        qrFilter.setValue("M", forKey: "inputCorrectionLevel")
        if let output = qrFilter.outputImage {
            var scale = floor(qrSize / output.extent.width)
            if scale < 1.0 { scale = 1.0 }
            let finalQrSize = output.extent.width * scale
            let scaledImage = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let ciContext = CIContext(options: [.useSoftwareRenderer: false])
            if let cgQr = ciContext.createCGImage(scaledImage, from: scaledImage.extent) {
                context.saveGState()
                context.interpolationQuality = .none
                let centeredQrX = qrX + (qrSize - finalQrSize) / 2.0
                let centeredQrY = qrY + (qrSize - finalQrSize) / 2.0
                context.draw(cgQr, in: CGRect(x: centeredQrX, y: centeredQrY, width: finalQrSize, height: finalQrSize))
                context.restoreGState()
            }
        }
    }

    let qrLabelStyle = NSMutableParagraphStyle()
    qrLabelStyle.alignment = .center
    let qrLabelAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: qrLabelStyle
    ]
    NSString(string: "CAMERA SCAN").draw(in: CGRect(x: 10, y: qrY - 16, width: 112, height: 16), withAttributes: qrLabelAttr)

    // 4b. Physical NFC Fob Placement Target on Right
    let targetCenterX: CGFloat = CGFloat(width) - 105.0
    let targetCenterY: CGFloat = qrY + (qrSize / 2.0)
    let radius: CGFloat = 38.0

    context.saveGState()
    context.setStrokeColor(gray: 0.0, alpha: 1.0)
    context.setLineWidth(2.5)
    let dashPattern: [CGFloat] = [4.0, 3.0]
    context.setLineDash(phase: 0, lengths: dashPattern)
    let circleRect = CGRect(x: targetCenterX - radius, y: targetCenterY - radius, width: radius * 2, height: radius * 2)
    context.strokeEllipse(in: circleRect)
    context.restoreGState()

    // Crosshair alignment marks
    context.setStrokeColor(gray: 0.0, alpha: 1.0)
    context.setLineWidth(1.5)
    context.strokeLineSegments(between: [
        CGPoint(x: targetCenterX - radius - 5, y: targetCenterY), CGPoint(x: targetCenterX - radius + 5, y: targetCenterY),
        CGPoint(x: targetCenterX + radius - 5, y: targetCenterY), CGPoint(x: targetCenterX + radius + 5, y: targetCenterY),
        CGPoint(x: targetCenterX, y: targetCenterY - radius - 5), CGPoint(x: targetCenterX, y: targetCenterY - radius + 5),
        CGPoint(x: targetCenterX, y: targetCenterY + radius - 5), CGPoint(x: targetCenterX, y: targetCenterY + radius + 5)
    ])

    let fobTitleStyle = NSMutableParagraphStyle()
    fobTitleStyle.alignment = .center
    let fobTitleAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .heavy),
        .foregroundColor: NSColor.black,
        .paragraphStyle: fobTitleStyle
    ]
    NSString(string: "📡 NFC FOB").draw(in: CGRect(x: targetCenterX - 45, y: targetCenterY + 8, width: 90, height: 16), withAttributes: fobTitleAttr)

    let fobSubStyle = NSMutableParagraphStyle()
    fobSubStyle.alignment = .center
    let fobSubAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 9, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: fobSubStyle
    ]
    NSString(string: "STICK HERE").draw(in: CGRect(x: targetCenterX - 45, y: targetCenterY - 8, width: 90, height: 14), withAttributes: fobSubAttr)

    let fobDimStyle = NSMutableParagraphStyle()
    fobDimStyle.alignment = .center
    let fobDimAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 8, weight: .semibold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: fobDimStyle
    ]
    NSString(string: "25-30mm").draw(in: CGRect(x: targetCenterX - 45, y: targetCenterY - 22, width: 90, height: 12), withAttributes: fobDimAttr)

    // 4c. NFC URI Bar (clean monospace / bold)
    let uriStyle = NSMutableParagraphStyle()
    uriStyle.alignment = .center
    uriStyle.lineBreakMode = .byTruncatingMiddle
    let uriAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: uriStyle,
        .kern: 0.3
    ]
    NSString(string: "NFC LINK: \(targetUri)").draw(in: CGRect(x: 10, y: height - 250, width: width - 20, height: 18), withAttributes: uriAttr)

    // 5. Crate Demographics Box (Thick 3.0 pt border)
    context.setStrokeColor(gray: 0.0, alpha: 1.0)
    context.setLineWidth(3.0)
    context.stroke(CGRect(x: 10, y: height - 346, width: width - 20, height: 90))

    let demoStyle = NSMutableParagraphStyle()
    demoStyle.alignment = .left
    let locAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 16),
        .foregroundColor: NSColor.black,
        .paragraphStyle: demoStyle,
        .kern: 0.3
    ]
    let locText = "📍 LOCATION: \(location.isEmpty ? "Bench Staging" : location)"
    NSString(string: locText).draw(in: CGRect(x: 18, y: height - 280, width: width - 36, height: 24), withAttributes: locAttr)

    let skuPrefix = abbr.isEmpty ? deriveAbbrFromId(crateId) : abbr
    let skuAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: demoStyle,
        .kern: 0.3
    ]
    let skuText = "🏷️ SKU FORMAT: \(skuPrefix)-XXX  •  ABBR: \(skuPrefix)"
    NSString(string: skuText).draw(in: CGRect(x: 18, y: height - 306, width: width - 36, height: 22), withAttributes: skuAttr)

    let typeAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: demoStyle,
        .kern: 0.3
    ]
    let typeText = "📦 TYPE: \(crateType.uppercased())  •  CAT: \(category.isEmpty ? "General" : category)"
    NSString(string: typeText).draw(in: CGRect(x: 18, y: height - 332, width: width - 36, height: 20), withAttributes: typeAttr)

    // 6. Footer / Packing Status (12pt Bold)
    let footerStyle = NSMutableParagraphStyle()
    footerStyle.alignment = .center
    let statusAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: footerStyle,
        .kern: 0.4
    ]
    NSString(string: "* * *   STATUS: ACTIVE PACKING TOTE   * * *").draw(in: CGRect(x: 0, y: height - 374, width: width, height: 18), withAttributes: statusAttr)

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
    let dateStr = dateFormatter.string(from: Date())
    let dateAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: footerStyle,
        .kern: 0.4
    ]
    NSString(string: "INITIALIZED: \(dateStr)").draw(in: CGRect(x: 0, y: height - 396, width: width, height: 18), withAttributes: dateAttr)

    // Extract pixel buffer
    guard let dataPtr = context.data else { return [] }
    let ptr = dataPtr.bindMemory(to: UInt8.self, capacity: width * height)

    // Binarize with threshold 210:
    // Crisp segmentation without muddy thermal bleed or closed letter counters
    var rawGrid = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)
    for y in 0..<height {
        let flippedY = (height - 1) - y
        for x in 0..<width {
            let pixelVal = ptr[flippedY * width + x]
            rawGrid[y][x] = (pixelVal < 210) ? 1 : 0
        }
    }

    var outputRows: [[UInt8]] = []
    for row in rawGrid {
        if flipHorizontal {
            outputRows.append(Array(row.reversed()))
        } else {
            outputRows.append(row)
        }
    }

    let blankRow = [UInt8](repeating: 0, count: width)
    for _ in 0..<20 {
        outputRows.append(blankRow)
    }

    return outputRows
}

// Bluetooth Print Manager
class CatPrintManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var central: CBCentralManager!
    var peripheral: CBPeripheral?
    var txChar: CBCharacteristic?
    let targetUUID = UUID(uuidString: "95229D94-9396-57A1-861A-C34C186E6D21")!
    var rowsToPrint: [[UInt8]] = []
    var isSuccess = false
    var isFinished = false
    var errorMessage: String?

    init(rows: [[UInt8]]) {
        self.rowsToPrint = rows
        super.init()
        self.central = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            let peripherals = central.retrievePeripherals(withIdentifiers: [targetUUID])
            if let p = peripherals.first {
                self.peripheral = p
                p.delegate = self
                print("Connecting to \(p.name ?? "Mini Printer")...")
                central.connect(p, options: nil)
            } else {
                print("Scanning for Mini Printer...")
                central.scanForPeripherals(withServices: nil, options: nil)
            }
        } else {
            errorMessage = "Bluetooth is not powered on (state: \(central.state.rawValue))"
            isFinished = true
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.identifier == targetUUID || (peripheral.name?.contains("Mini") == true) {
            central.stopScan()
            self.peripheral = peripheral
            peripheral.delegate = self
            print("Discovered \(peripheral.name ?? "Mini Printer"). Connecting...")
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected! Discovering services...")
        peripheral.discoverServices([CBUUID(string: "AE30")])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        errorMessage = "Failed to connect: \(error?.localizedDescription ?? "unknown error")"
        isFinished = true
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let s = peripheral.services?.first(where: { $0.uuid == CBUUID(string: "AE30") }) else {
            errorMessage = "AE30 print service not found"
            isFinished = true
            return
        }
        peripheral.discoverCharacteristics([CBUUID(string: "AE01"), CBUUID(string: "AE02")], for: s)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for c in chars {
            if c.uuid == CBUUID(string: "AE01") {
                self.txChar = c
            } else if c.uuid == CBUUID(string: "AE02") {
                peripheral.setNotifyValue(true, for: c)
            }
        }

        guard let tx = self.txChar else {
            errorMessage = "TX characteristic AE01 not found"
            isFinished = true
            return
        }

        print("Preparing print commands...")
        var fullPayload: [UInt8] = []
        fullPayload.append(contentsOf: CMD_GET_DEV_STATE)
        fullPayload.append(contentsOf: cmdSetQuality(54)) // Level 54 (0x36) = Maximum print quality / burn time
        fullPayload.append(contentsOf: cmdSetEnergy(0xE000)) // Balanced high thermal energy (57344 / 87.5%) for rich dark text without dot bloom
        fullPayload.append(contentsOf: cmdSetDrawingMode(0)) // Mode 0 = Image / Bitmap
        fullPayload.append(contentsOf: CMD_LATTICE_START)

        for row in rowsToPrint {
            fullPayload.append(contentsOf: cmdPrintRow(row))
        }

        fullPayload.append(contentsOf: cmdFeedPaper(50))
        fullPayload.append(contentsOf: CMD_SET_PAPER)
        fullPayload.append(contentsOf: CMD_SET_PAPER)
        fullPayload.append(contentsOf: CMD_LATTICE_END)
        fullPayload.append(contentsOf: CMD_GET_DEV_STATE)

        print("Total print stream size: \(fullPayload.count) bytes. Transmitting over BLE...")

        // Send in MTU chunks (chunk size: 100 bytes) with 22ms pacing for crisp, well-formed thermal dots without overdwell muddying
        let chunkSize = 100
        var offset = 0
        while offset < fullPayload.count {
            let end = min(offset + chunkSize, fullPayload.count)
            let chunk = fullPayload[offset..<end]
            peripheral.writeValue(Data(chunk), for: tx, type: .withoutResponse)
            offset = end
            Thread.sleep(forTimeInterval: 0.022)
        }

        print("Print stream transmission complete!")
        self.isSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isFinished = true
        }
    }
}

// CLI Argument Parsing
var labelType = "sku" // "sku" or "crate"
var sku = "C01-001"
var title = "Vintage Ceramic Planter"
var crate = "C01"
var category = "Ceramics"
var price = "$38.00"

// Crate Demographics & NFC arguments
var crateId = "C01"
var crateName = "Vintage Kitchen & Enamelware"
var crateLocation = "Bench Staging"
var crateAbbr = "C01"
var crateType = "physical"
var nfcUri = "http://localhost:8000/crate/C01"
var flipHorizontal = true

let args = CommandLine.arguments
var i = 1
while i < args.count {
    switch args[i] {
    case "--label-type", "--type":
        if i + 1 < args.count { labelType = args[i+1].lowercased(); i += 1 }
    case "--sku":
        if i + 1 < args.count { sku = args[i+1]; i += 1 }
    case "--title":
        if i + 1 < args.count { title = args[i+1]; i += 1 }
    case "--crate":
        if i + 1 < args.count { crate = args[i+1]; i += 1 }
    case "--crate-id":
        if i + 1 < args.count { crateId = args[i+1]; i += 1 }
    case "--name":
        if i + 1 < args.count { crateName = args[i+1]; i += 1 }
    case "--location":
        if i + 1 < args.count { crateLocation = args[i+1]; i += 1 }
    case "--abbr":
        if i + 1 < args.count { crateAbbr = args[i+1]; i += 1 }
    case "--crate-type":
        if i + 1 < args.count { crateType = args[i+1]; i += 1 }
    case "--nfc-uri":
        if i + 1 < args.count { nfcUri = args[i+1]; i += 1 }
    case "--category":
        if i + 1 < args.count { category = args[i+1]; i += 1 }
    case "--price":
        if i + 1 < args.count { price = args[i+1]; i += 1 }
    case "--no-flip":
        flipHorizontal = false
    case "--flip", "--flip-h":
        flipHorizontal = true
    default:
        break
    }
    i += 1
}

let rows: [[UInt8]]
if labelType == "crate" {
    print("=== Mini Thermal Printer: Crate Demographics & NFC Fob Label ===")
    print("Crate ID: \(crateId)")
    print("Name: \(crateName)")
    print("Location: \(crateLocation)")
    print("Category: \(category)")
    print("Abbr: \(crateAbbr)")
    print("Type: \(crateType)")
    print("NFC URI: \(nfcUri)")
    print("Flip Horizontal: \(flipHorizontal)")
    rows = renderCrateLabel(
        crateId: crateId,
        name: crateName,
        location: crateLocation,
        category: category,
        abbr: crateAbbr,
        crateType: crateType,
        nfcUri: nfcUri,
        flipHorizontal: flipHorizontal
    )
} else {
    print("=== Mini Thermal Printer: SKU Label Generator ===")
    print("SKU: \(sku)")
    print("Title: \(title)")
    print("Crate: \(crate)")
    print("Price: \(price)")
    print("Flip Horizontal: \(flipHorizontal)")
    rows = renderSkuLabel(sku: sku, title: title, crate: crate, category: category, price: price, flipHorizontal: flipHorizontal)
}
print("Rendered \(rows.count) bitmap rows.")

let manager = CatPrintManager(rows: rows)
let start = Date()
while !manager.isFinished && Date().timeIntervalSince(start) < 15 {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}

if manager.isSuccess {
    print("SUCCESS: Label printed successfully!")
    exit(0)
} else {
    print("ERROR: \(manager.errorMessage ?? "Printing timed out")")
    exit(1)
}
