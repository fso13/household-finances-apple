import Foundation

// MARK: - Импорт/экспорт квартиры в XLSX

package struct ApartmentMonthData: Identifiable, Equatable, Sendable {
    package var year: Int
    package var month: Int
    package var rent: Double
    package var capitalRepair: Double
    package var utilities: Double
    package var electricity: Double
    package var paid: Double

    package var id: String { "\(year)-\(month)" }

    package init(
        year: Int,
        month: Int,
        rent: Double = 0,
        capitalRepair: Double = 0,
        utilities: Double = 0,
        electricity: Double = 0,
        paid: Double = 0
    ) {
        self.year = year
        self.month = month
        self.rent = rent
        self.capitalRepair = capitalRepair
        self.utilities = utilities
        self.electricity = electricity
        self.paid = paid
    }

    package init(_ month: ApartmentMonth) {
        year = month.year
        self.month = month.month
        rent = month.rent
        capitalRepair = month.capitalRepair
        utilities = month.utilities
        electricity = month.electricity
        paid = month.paid
    }
}

package enum ApartmentXLSXCodec {
    package static func export(months: [ApartmentMonthData], to url: URL) throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("apartment-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        try write("[Content_Types].xml", contentTypes, to: temp)
        try write("_rels/.rels", rootRels, to: temp)
        try write("xl/workbook.xml", workbook, to: temp)
        try write("xl/_rels/workbook.xml.rels", workbookRels, to: temp)
        try write("xl/styles.xml", styles, to: temp)
        try write("xl/worksheets/sheet1.xml", sheetXML(months: months), to: temp)

        try? FileManager.default.removeItem(at: url)
        try run("/usr/bin/zip", ["-r", "-X", url.path, "."], in: temp)
    }

    package static func importFile(from url: URL) throws -> [ApartmentMonthData] {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("apartment-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        try run("/usr/bin/unzip", ["-o", "-q", url.path, "-d", temp.path], in: temp)
        let shared = parseSharedStrings(at: temp)
        let cells = try parseSheet(at: temp, sharedStrings: shared)
        return months(from: cells)
    }

    // MARK: - XLSX generation

    private static func write(_ path: String, _ content: String, to root: URL) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.data(using: .utf8)?.write(to: url)
    }

    private static let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """

    private static let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """

    private static let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets><sheet name="Квартира" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
        """

    private static let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """

    private static let styles = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>
        <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
        <borders count="1"><border/></borders>
        <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
        <cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>
        </styleSheet>
        """

    private static func sheetXML(months: [ApartmentMonthData]) -> String {
        var rows: [String] = []
        let header = [
            "Месяц", "Аренда", "Капремонт", "Коммуналка", "Свет",
            "Итого", "Заплатил", "Переплата", "Запас",
        ]
        rows.append(
            "<row r=\"1\">"
                + header.enumerated().map { index, title in
                    let ref = "\(column(index))1"
                    return "<c r=\"\(ref)\" t=\"inlineStr\" s=\"1\"><is><t>\(escape(title))</t></is></c>"
                }.joined()
                + "</row>"
        )

        var running = 0.0
        for (offset, month) in months.sorted(by: { ($0.year, $0.month) < ($1.year, $1.month) }).enumerated() {
            let row = offset + 2
            let values: [(String, Double)] = [
                ("B", month.rent),
                ("C", month.capitalRepair),
                ("D", month.utilities),
                ("E", month.electricity),
                ("G", month.paid),
            ]
            var cells: [String] = [
                "<c r=\"A\(row)\" t=\"inlineStr\"><is><t>\(escape(monthTitle(month)))</t></is></c>"
            ]
            for (column, value) in values {
                cells.append("<c r=\"\(column)\(row)\"><v>\(number(value))</v></c>")
            }
            let total = month.rent + month.capitalRepair + month.utilities + month.electricity
            cells.append(
                "<c r=\"F\(row)\"><f>SUM(B\(row):E\(row))</f><v>\(number(total))</v></c>"
            )
            let monthly = month.paid - total
            running += monthly
            cells.append(
                "<c r=\"H\(row)\"><f>G\(row)-F\(row)</f><v>\(number(monthly))</v></c>"
            )
            cells.append("<c r=\"I\(row)\"><v>\(number(running))</v></c>")
            rows.append("<row r=\"\(row)\">\(cells.joined())</row>")
        }

        return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <cols>
            <col min="1" max="1" width="18" customWidth="1"/>
            <col min="2" max="9" width="14" customWidth="1"/>
            </cols>
            <sheetData>\(rows.joined())</sheetData>
            </worksheet>
            """
    }

    private static func monthTitle(_ month: ApartmentMonthData) -> String {
        MonthFormat.monthTitle(Date.make(year: month.year, month: month.month))
    }

    private static func column(_ index: Int) -> String {
        String(UnicodeScalar(65 + index)!)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    // MARK: - XLSX reading

    private static func parseSharedStrings(at root: URL) -> [String] {
        let url = root.appendingPathComponent("xl/sharedStrings.xml")
        guard let data = try? Data(contentsOf: url) else { return [] }
        let delegate = SharedStringsDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    private static func parseSheet(at root: URL, sharedStrings: [String]) throws -> [Int: [Int: Cell]] {
        let url = root.appendingPathComponent("xl/worksheets/sheet1.xml")
        let data = try Data(contentsOf: url)
        let delegate = SheetDelegate(sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw AppError.importFailed }
        return delegate.rows
    }

    private static func months(from rows: [Int: [Int: Cell]]) -> [ApartmentMonthData] {
        var result: [ApartmentMonthData] = []
        for (_, row) in rows.sorted(by: { $0.key < $1.key }) {
            guard let dateCell = row[0], let date = monthDate(from: dateCell) else { continue }
            let rent = number(row[1])
            let capital = number(row[2])
            let utilities = number(row[3])
            let electricity = number(row[4])
            let paid = number(row[6])
            if rent == 0 && capital == 0 && utilities == 0 && electricity == 0 && paid == 0 {
                continue
            }
            let month = Calendar.current.component(.month, from: date)
            let year = Calendar.current.component(.year, from: date)
            result.append(
                ApartmentMonthData(
                    year: year,
                    month: month,
                    rent: rent,
                    capitalRepair: capital,
                    utilities: utilities,
                    electricity: electricity,
                    paid: paid
                )
            )
        }
        return result
    }

    private static func number(_ cell: Cell?) -> Double {
        guard let cell else { return 0 }
        return Double(cell.value.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private static func monthDate(from cell: Cell) -> Date? {
        if let serial = Double(cell.value), serial > 20_000 {
            return Date(timeInterval: (serial - 25_569) * 86_400, since: Date(timeIntervalSince1970: 0))
        }

        var text = cell.value
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: " г.", with: "")
        text = text.replacingOccurrences(of: "г.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let locale = Locale(identifier: "ru_RU")
        for format in ["LLLL yyyy", "MM.yyyy", "yyyy-MM", "LLLL yyyy 'г.'"] {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = .current
            formatter.dateFormat = format
            formatter.isLenient = false
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return CSVCodec.parseDate(text)
    }

    private static func run(_ path: String, _ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw AppError.importFailed }
    }
}

// MARK: - XML delegates

private struct Cell {
    var value: String
}

private final class SharedStringsDelegate: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var inString = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "si" { current = "" }
        if elementName == "t" { inString = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inString { current += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "t" { inString = false }
        if elementName == "si" { strings.append(current) }
    }
}

private final class SheetDelegate: NSObject, XMLParserDelegate {
    let sharedStrings: [String]
    var rows: [Int: [Int: Cell]] = [:]
    private var rowIndex = -1
    private var columnIndex = -1
    private var cellType = ""
    private var cellValue = ""
    private var inValue = false
    private var inInlineString = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "row", let raw = attributeDict["r"], let index = Int(raw) {
            rowIndex = index - 1
        }
        if elementName == "c" {
            cellType = attributeDict["t"] ?? ""
            cellValue = ""
            if let ref = attributeDict["r"] {
                columnIndex = columnIndex(from: ref)
            }
        }
        if elementName == "v" { inValue = true }
        if elementName == "t", cellType == "inlineStr" { inInlineString = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValue || inInlineString {
            cellValue += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "v" { inValue = false }
        if elementName == "t", cellType == "inlineStr" { inInlineString = false }
        if elementName == "c", rowIndex >= 0, columnIndex >= 0 {
            let value: String
            if cellType == "s", let index = Int(cellValue), sharedStrings.indices.contains(index) {
                value = sharedStrings[index]
            } else {
                value = cellValue
            }
            rows[rowIndex, default: [:]][columnIndex] = Cell(value: value)
        }
    }

    private func columnIndex(from reference: String) -> Int {
        let letters = reference.prefix { $0.isLetter }
        var result = 0
        for letter in letters.uppercased().unicodeScalars {
            result = result * 26 + Int(letter.value) - 64
        }
        return max(0, result - 1)
    }
}
