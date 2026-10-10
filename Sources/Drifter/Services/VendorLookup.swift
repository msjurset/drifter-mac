import Foundation

public final class VendorLookup {
    private static let ouiMap: [String: String] = {
        var map: [String: String] = [:]

        func add(_ prefixes: [String], vendor: String) {
            for p in prefixes {
                map[p.uppercased()] = vendor
            }
        }

        // Raspberry Pi
        add(["A483E7", "DCA632", "B827EB", "E45F01", "28CDC1"], vendor: "Raspberry Pi Trading")

        // Espressif Systems (ESP8266, ESP32, ESPHome, Shelly, WLED)
        add([
            "240AC4", "246F28", "24B2DE", "2C3AE8", "30AEA4", "3C71BF", "40F520", "485519",
            "48E729", "545A46", "5C0272", "600194", "68C63A", "70039F", "7C87CE", "840D8E",
            "84F3EB", "8C4B14", "94B97E", "94B555", "A020A6", "A4CF12", "A842E3", "AC67B2",
            "B4E62D", "BCDD02", "C44F33", "CC50E3", "D8A01D", "DC4F22", "EC94CB"
        ], vendor: "Espressif Systems")

        // Ubiquiti / UniFi
        add([
            "0024A5", "002722", "0418D6", "18E829", "24A43C", "44D9E7", "68D79A", "70A741",
            "7483C2", "788A20", "802AA8", "AA8877", "AC8B03", "B4FBE4", "DC9FDB", "E063DA", "F09FC2"
        ], vendor: "UniFi / Ubiquiti")

        // Synology Inc.
        add(["001132", "00089B", "909C4A"], vendor: "Synology Inc.")

        // Sonoff / Itead
        add(["68C63A", "D8B04C", "600194"], vendor: "Sonoff / Itead")

        // Tuya / Smart Life
        add([
            "102C6B", "10A56C", "1C90FF", "20F41B", "708976", "7C25DA", "84F703", "A09208",
            "BC33AC", "CC8C27"
        ], vendor: "Tuya Smart Life")

        // Philips / Signify Hue
        add(["001788", "ECB5FA"], vendor: "Philips Hue / Signify")

        // Sonos
        add(["000E58", "48A6B8", "5C313E", "5C334E", "7828CA", "949F3E", "B8E937"], vendor: "Sonos Inc.")

        // Apple Inc.
        add([
            "A45E60", "B0A737", "001122", "A4B805", "70EC4C", "BC5436", "38C986", "68AE20",
            "90FD61", "ACDE48", "F0D1A9", "B8098A", "F83880", "14109F", "88665A", "F01898",
            "3C0754", "58404E", "B8782E", "C0847D", "6476BA", "48D705", "30074D", "F4F15A"
        ], vendor: "Apple Inc.")

        // Intel
        add([
            "0002B3", "000423", "001302", "001500", "001676", "001B21", "001E67", "00216A",
            "081196", "244BFE", "3413E8", "4851B7", "680571", "806CE8", "94659C", "A0369F",
            "B49691", "C85B76", "DC5360", "F832E4"
        ], vendor: "Intel Corporation")

        // Dell
        add([
            "00065B", "000874", "001422", "0019B9", "002219", "1866DA", "24B6FD", "44A842",
            "74867A", "847BEB", "989096", "B82A72", "C84B44", "D481D7", "F8BC12"
        ], vendor: "Dell Technologies")

        // Supermicro
        add(["002590", "003048", "0C4DE9", "AC1F6B"], vendor: "Supermicro")

        // TP-Link
        add([
            "000A3A", "0019E0", "002586", "14CC20", "1C3BF3", "30DE4B", "50BD5F", "54C80F",
            "60A44C", "74DA38", "90F652", "AC84C6", "C04A00", "CC32E5", "DC4A3E", "EC086B"
        ], vendor: "TP-Link")

        // Netgear
        add([
            "00095B", "00146C", "00184D", "001F33", "0024B2", "0836C9", "10DA43", "204E7F",
            "288088", "4494FC", "744401", "841B5E", "9C3DCF", "A42B8C", "C0FFD4", "E091F5"
        ], vendor: "Netgear")

        // MikroTik
        add(["000C42", "18FD74", "2C3996", "488F5A", "64D154", "744D28", "789A18", "B869F4"], vendor: "MikroTik")

        // Google / Nest
        add(["001A11", "1C56FE", "3C5AB4", "546009", "641666", "70EE50", "94EB2C", "D86C63"], vendor: "Google / Nest")

        // Amazon / Ring
        add(["00FC8B", "0C47C9", "18742E", "24F5AA", "34D270", "44650D", "50DC01", "68545A", "78E103"], vendor: "Amazon / Ring")

        return map
    }()

    public static func lookup(mac: String) -> String {
        let clean = mac
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()

        guard clean.count >= 6 else { return "Local Network Device" }
        let prefix = String(clean.prefix(6))
        return ouiMap[prefix] ?? "Local Network Device"
    }
}
