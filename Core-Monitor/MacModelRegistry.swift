import Foundation

enum MacFamily: String, CaseIterable, Identifiable {
    case macBookAirMSeries = "MacBook Air M-series"
    case macBookAirIntel = "MacBook Air Intel"
    case macBookProMSeries = "MacBook Pro M-series"
    case macBookProIntel = "MacBook Pro Intel"
    case macMini = "Mac mini"
    case iMac = "iMac"
    case macStudio = "Mac Studio"
    case macPro = "Mac Pro"

    var id: String { rawValue }
}

struct MacModelEntry: Identifiable, Hashable {
    let hwModel: String
    let friendlyName: String
    let family: MacFamily

    var id: String { hwModel }
}

enum MacModelRegistry {
    static let entries: [MacModelEntry] = [
        .init(hwModel: "MacBookAir7,2", friendlyName: "MacBook Air (13-inch, Early 2015)", family: .macBookAirIntel),
        .init(hwModel: "MacBookAir8,1", friendlyName: "MacBook Air (Retina, 13-inch, 2018)", family: .macBookAirIntel),
        .init(hwModel: "MacBookAir8,2", friendlyName: "MacBook Air (Retina, 13-inch, 2019)", family: .macBookAirIntel),
        .init(hwModel: "MacBookAir9,1", friendlyName: "MacBook Air (Retina, 13-inch, 2020 Intel)", family: .macBookAirIntel),
        .init(hwModel: "MacBookAir10,1", friendlyName: "MacBook Air (M1, 2020)", family: .macBookAirMSeries),
        .init(hwModel: "Mac14,2", friendlyName: "MacBook Air (M2, 2022)", family: .macBookAirMSeries),
        .init(hwModel: "Mac14,15", friendlyName: "MacBook Air (15-inch, M2, 2023)", family: .macBookAirMSeries),
        .init(hwModel: "Mac15,12", friendlyName: "MacBook Air (13-inch, M3, 2024)", family: .macBookAirMSeries),
        .init(hwModel: "Mac15,13", friendlyName: "MacBook Air (15-inch, M3, 2024)", family: .macBookAirMSeries),
        .init(hwModel: "MacBookPro11,1", friendlyName: "MacBook Pro (13-inch, Late 2013)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro11,2", friendlyName: "MacBook Pro (Retina, 15-inch, Late 2013)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro12,1", friendlyName: "MacBook Pro (13-inch, Early 2015)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro13,1", friendlyName: "MacBook Pro (13-inch, 2016 Two Thunderbolt 3)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro13,2", friendlyName: "MacBook Pro (13-inch, 2016 Four Thunderbolt 3)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro13,3", friendlyName: "MacBook Pro (15-inch, 2016)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro14,1", friendlyName: "MacBook Pro (13-inch, 2017 Two Thunderbolt 3)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro14,2", friendlyName: "MacBook Pro (13-inch, 2017 Four Thunderbolt 3)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro14,3", friendlyName: "MacBook Pro (15-inch, 2017)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro15,1", friendlyName: "MacBook Pro (15-inch, 2018)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro15,2", friendlyName: "MacBook Pro (13-inch, 2018 Four Thunderbolt 3)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro15,3", friendlyName: "MacBook Pro (15-inch, 2019)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro15,4", friendlyName: "MacBook Pro (13-inch, 2019 Two Thunderbolt 3)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro16,1", friendlyName: "MacBook Pro (16-inch, 2019)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro16,2", friendlyName: "MacBook Pro (13-inch, 2020 Four Thunderbolt 3)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro16,3", friendlyName: "MacBook Pro (13-inch, 2020 Two Thunderbolt 3)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro16,4", friendlyName: "MacBook Pro (16-inch, 2019 Radeon)", family: .macBookProIntel),
        .init(hwModel: "MacBookPro17,1", friendlyName: "MacBook Pro (13-inch, M1, 2020)", family: .macBookProMSeries),
        .init(hwModel: "Mac14,7", friendlyName: "MacBook Pro (13-inch, M2, 2022)", family: .macBookProMSeries),
        .init(hwModel: "Mac14,5", friendlyName: "MacBook Pro (14-inch, M2 Pro/Max, 2023)", family: .macBookProMSeries),
        .init(hwModel: "Mac14,6", friendlyName: "MacBook Pro (16-inch, M2 Pro/Max, 2023)", family: .macBookProMSeries),
        .init(hwModel: "Mac15,3", friendlyName: "MacBook Pro (14-inch, M3 Pro/Max, 2023)", family: .macBookProMSeries),
        .init(hwModel: "Mac15,6", friendlyName: "MacBook Pro (16-inch, M3 Pro/Max, 2023)", family: .macBookProMSeries),
        .init(hwModel: "Mac15,10", friendlyName: "MacBook Pro (14-inch, M4 family)", family: .macBookProMSeries),
        .init(hwModel: "Mac15,11", friendlyName: "MacBook Pro (16-inch, M4 family)", family: .macBookProMSeries),
        .init(hwModel: "Macmini8,1", friendlyName: "Mac mini (2018 Intel)", family: .macMini),
        .init(hwModel: "Macmini9,1", friendlyName: "Mac mini (M1, 2020)", family: .macMini),
        .init(hwModel: "Mac14,3", friendlyName: "Mac mini (M2/M2 Pro, 2023)", family: .macMini),
        .init(hwModel: "iMac19,1", friendlyName: "iMac (Retina 5K, 27-inch, 2019)", family: .iMac),
        .init(hwModel: "iMac20,1", friendlyName: "iMac (Retina 5K, 27-inch, 2020)", family: .iMac),
        .init(hwModel: "iMac21,1", friendlyName: "iMac (24-inch, M1, 2021)", family: .iMac),
        .init(hwModel: "Mac13,1", friendlyName: "Mac Studio (M1 Max, 2022)", family: .macStudio),
        .init(hwModel: "Mac13,2", friendlyName: "Mac Studio (M1 Ultra, 2022)", family: .macStudio),
        .init(hwModel: "Mac14,13", friendlyName: "Mac Studio (M2 Max/Ultra, 2023)", family: .macStudio),
        .init(hwModel: "MacPro7,1", friendlyName: "Mac Pro (2019 Intel)", family: .macPro),
        .init(hwModel: "Mac14,8", friendlyName: "Mac Pro (M2 Ultra, 2023)", family: .macPro),
    ]

    static func entry(for hwModel: String) -> MacModelEntry? {
        entries.first { $0.hwModel == hwModel }
    }
}
