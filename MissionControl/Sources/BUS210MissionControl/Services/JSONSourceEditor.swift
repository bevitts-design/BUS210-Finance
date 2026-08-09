import Foundation

enum JSONSourceEditorError: LocalizedError {
    case invalidStructure(String)

    var errorDescription: String? {
        switch self {
        case .invalidStructure(let detail): "The course map cannot be edited narrowly. \(detail)"
        }
    }
}

enum JSONSourceEditor {
    static func updatingLessonVisibility(in data: Data, desired: [String: Bool]) throws -> Data {
        let bytes = [UInt8](data)
        let scanner = JSONByteScanner(bytes: bytes)
        let rootRange = 0..<bytes.count
        let rootProperties = try scanner.objectProperties(in: rootRange)
        guard let lessonsRange = rootProperties.first(where: { $0.key == "lessons" })?.valueRange else {
            throw JSONSourceEditorError.invalidStructure("The root lessons array is missing.")
        }

        let lessonRanges = try scanner.arrayElements(in: lessonsRange)
        var foundIDs = Set<String>()
        var replacements: [(range: Range<Int>, bytes: [UInt8])] = []

        for lessonRange in lessonRanges {
            let properties = try scanner.objectProperties(in: lessonRange)
            guard let idRange = properties.first(where: { $0.key == "id" })?.valueRange,
                  let id = try scanner.decodeString(in: idRange) else {
                throw JSONSourceEditorError.invalidStructure("Every lesson must have one string id field.")
            }
            guard foundIDs.insert(id).inserted else {
                throw JSONSourceEditorError.invalidStructure("Duplicate lesson id \(id) prevents a safe narrow edit.")
            }
            guard let desiredValue = desired[id] else { continue }
            let visibleProperties = properties.filter { $0.key == "visible" }
            guard visibleProperties.count == 1 else {
                throw JSONSourceEditorError.invalidStructure("Lesson \(id) must have exactly one visible field.")
            }
            let valueRange = scanner.trimmingWhitespace(from: visibleProperties[0].valueRange)
            let currentText = String(decoding: bytes[valueRange], as: UTF8.self)
            guard currentText == "true" || currentText == "false" else {
                throw JSONSourceEditorError.invalidStructure("Lesson \(id).visible is not a JSON boolean.")
            }
            if (currentText == "true") != desiredValue {
                replacements.append((valueRange, Array((desiredValue ? "true" : "false").utf8)))
            }
        }

        for id in desired.keys where !foundIDs.contains(id) {
            throw JSONSourceEditorError.invalidStructure("Lesson \(id) no longer exists.")
        }

        var updated = bytes
        for replacement in replacements.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            updated.replaceSubrange(replacement.range, with: replacement.bytes)
        }
        return Data(updated)
    }
}

private struct JSONProperty {
    let key: String
    let valueRange: Range<Int>
}

private struct JSONByteScanner {
    let bytes: [UInt8]

    func objectProperties(in range: Range<Int>) throws -> [JSONProperty] {
        var index = skipWhitespace(from: range.lowerBound, limit: range.upperBound)
        guard index < range.upperBound, bytes[index] == ascii("{") else {
            throw JSONSourceEditorError.invalidStructure("Expected a JSON object.")
        }
        index += 1
        var properties: [JSONProperty] = []

        while true {
            index = skipWhitespace(from: index, limit: range.upperBound)
            guard index < range.upperBound else { throw JSONSourceEditorError.invalidStructure("An object is incomplete.") }
            if bytes[index] == ascii("}") { return properties }
            let keyRange = try stringRange(startingAt: index, limit: range.upperBound)
            guard let key = try decodeString(in: keyRange) else {
                throw JSONSourceEditorError.invalidStructure("An object key is not a string.")
            }
            index = skipWhitespace(from: keyRange.upperBound, limit: range.upperBound)
            guard index < range.upperBound, bytes[index] == ascii(":") else {
                throw JSONSourceEditorError.invalidStructure("Object key \(key) is missing a colon.")
            }
            index = skipWhitespace(from: index + 1, limit: range.upperBound)
            let valueStart = index
            let valueEnd = try endOfValue(startingAt: valueStart, limit: range.upperBound)
            properties.append(.init(key: key, valueRange: valueStart..<valueEnd))
            index = skipWhitespace(from: valueEnd, limit: range.upperBound)
            guard index < range.upperBound else { throw JSONSourceEditorError.invalidStructure("An object is incomplete.") }
            if bytes[index] == ascii(",") { index += 1; continue }
            if bytes[index] == ascii("}") { return properties }
            throw JSONSourceEditorError.invalidStructure("Object key \(key) has an invalid separator.")
        }
    }

    func arrayElements(in range: Range<Int>) throws -> [Range<Int>] {
        var index = skipWhitespace(from: range.lowerBound, limit: range.upperBound)
        guard index < range.upperBound, bytes[index] == ascii("[") else {
            throw JSONSourceEditorError.invalidStructure("lessons is not a JSON array.")
        }
        index += 1
        var elements: [Range<Int>] = []
        while true {
            index = skipWhitespace(from: index, limit: range.upperBound)
            guard index < range.upperBound else { throw JSONSourceEditorError.invalidStructure("The lessons array is incomplete.") }
            if bytes[index] == ascii("]") { return elements }
            let end = try endOfValue(startingAt: index, limit: range.upperBound)
            elements.append(index..<end)
            index = skipWhitespace(from: end, limit: range.upperBound)
            guard index < range.upperBound else { throw JSONSourceEditorError.invalidStructure("The lessons array is incomplete.") }
            if bytes[index] == ascii(",") { index += 1; continue }
            if bytes[index] == ascii("]") { return elements }
            throw JSONSourceEditorError.invalidStructure("The lessons array has an invalid separator.")
        }
    }

    func decodeString(in range: Range<Int>) throws -> String? {
        let trimmed = trimmingWhitespace(from: range)
        guard !trimmed.isEmpty, bytes[trimmed.lowerBound] == ascii("\"") else { return nil }
        return try JSONSerialization.jsonObject(with: Data(bytes[trimmed]), options: .fragmentsAllowed) as? String
    }

    func trimmingWhitespace(from range: Range<Int>) -> Range<Int> {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper, isWhitespace(bytes[lower]) { lower += 1 }
        while upper > lower, isWhitespace(bytes[upper - 1]) { upper -= 1 }
        return lower..<upper
    }

    private func endOfValue(startingAt start: Int, limit: Int) throws -> Int {
        guard start < limit else { throw JSONSourceEditorError.invalidStructure("A JSON value is missing.") }
        if bytes[start] == ascii("\"") { return try stringRange(startingAt: start, limit: limit).upperBound }
        if bytes[start] == ascii("{") || bytes[start] == ascii("[") {
            var index = start
            var stack: [UInt8] = []
            var inString = false
            var escaped = false
            while index < limit {
                let byte = bytes[index]
                if inString {
                    if escaped { escaped = false }
                    else if byte == ascii("\\") { escaped = true }
                    else if byte == ascii("\"") { inString = false }
                } else if byte == ascii("\"") {
                    inString = true
                } else if byte == ascii("{") || byte == ascii("[") {
                    stack.append(byte)
                } else if byte == ascii("}") || byte == ascii("]") {
                    guard let opener = stack.popLast(),
                          (opener == ascii("{") && byte == ascii("}")) || (opener == ascii("[") && byte == ascii("]")) else {
                        throw JSONSourceEditorError.invalidStructure("JSON containers are mismatched.")
                    }
                    if stack.isEmpty { return index + 1 }
                }
                index += 1
            }
            throw JSONSourceEditorError.invalidStructure("A JSON container is incomplete.")
        }

        var index = start
        while index < limit, bytes[index] != ascii(","), bytes[index] != ascii("}"), bytes[index] != ascii("]") { index += 1 }
        return trimmingWhitespace(from: start..<index).upperBound
    }

    private func stringRange(startingAt start: Int, limit: Int) throws -> Range<Int> {
        guard start < limit, bytes[start] == ascii("\"") else {
            throw JSONSourceEditorError.invalidStructure("Expected a JSON string.")
        }
        var index = start + 1
        var escaped = false
        while index < limit {
            let byte = bytes[index]
            if escaped { escaped = false }
            else if byte == ascii("\\") { escaped = true }
            else if byte == ascii("\"") { return start..<(index + 1) }
            index += 1
        }
        throw JSONSourceEditorError.invalidStructure("A JSON string is incomplete.")
    }

    private func skipWhitespace(from start: Int, limit: Int) -> Int {
        var index = start
        while index < limit, isWhitespace(bytes[index]) { index += 1 }
        return index
    }
}

private func ascii(_ character: Character) -> UInt8 {
    character.asciiValue!
}

private func isWhitespace(_ byte: UInt8) -> Bool {
    byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
}
