import Foundation

enum BatteryDetailFormatter {
    static func powerStateDescription(for info: BatteryInfo, locale: Locale = AppLocaleStore.currentLocale) -> String {
        if info.isCharging {
            return localized("Charging", locale: locale)
        }
        if info.isPluggedIn {
            return localized("AC Power", locale: locale)
        }
        return localized("Battery Power", locale: locale)
    }

    static func sourceDescription(for info: BatteryInfo, locale: Locale = AppLocaleStore.currentLocale) -> String? {
        if let source = info.source?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty {
            switch source {
            case "AC Power":
                return localized("Power Adapter", locale: locale)
            case "Battery Power":
                return localized("Internal Battery", locale: locale)
            default:
                return source
            }
        }

        guard info.hasBattery else { return nil }
        return localized(info.isPluggedIn ? "Power Adapter" : "Internal Battery", locale: locale)
    }

    static func runtimeDescription(for info: BatteryInfo, locale: Locale = AppLocaleStore.currentLocale) -> String? {
        guard let minutes = info.timeRemainingMinutes, minutes >= 0 else { return nil }
        if minutes == 0 {
            return localized(info.isCharging ? "Finishing soon" : "Less than 1m remaining", locale: locale)
        }

        let formattedDuration = durationDescription(minutes: minutes, locale: locale)
        if info.isCharging {
            return String(format: localized("%@ until full", locale: locale), locale: locale, formattedDuration)
        }
        return String(format: localized("%@ remaining", locale: locale), locale: locale, formattedDuration)
    }

    static func durationDescription(minutes: Int, locale: Locale = AppLocaleStore.currentLocale) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar
        return formatter.string(from: TimeInterval(max(0, minutes)) * 60) ?? "0"
    }

    static func temperatureDescription(_ temperature: Double?, locale: Locale = AppLocaleStore.currentLocale) -> String? {
        guard let temperature else { return nil }
        return String(format: "%.1f °C", locale: locale, temperature)
    }

    static func voltageDescription(_ voltage: Double?, locale: Locale = AppLocaleStore.currentLocale) -> String? {
        guard let voltage else { return nil }
        return String(format: "%.2f V", locale: locale, voltage)
    }

    static func amperageDescription(_ amperage: Double?, locale: Locale = AppLocaleStore.currentLocale) -> String? {
        guard let amperage else { return nil }
        return String(format: "%.2f A", locale: locale, amperage)
    }

    private static func localized(_ key: String, locale: Locale) -> String {
        let language = Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: [locale.identifier]).first ?? "en"
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) else { return key }
        let battery = bundle.localizedString(forKey: key, value: key, table: "BatteryDetails")
        if battery != key { return battery }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
