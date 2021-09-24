//
//  Loader.swift
//  iVariant
//
//  Created by Lakr Aream on 2021/9/24.
//

import Foundation
import SQLite

private func unknownKey() -> String {
    "unknown"
}

struct DeviceRecord {
    let Target: String
    let TargetType: String
    let TargetVariant: String
    let Platform: String
    let ProductType: String
    let ProductDescription: String
    let CompatibleDeviceFallback: String
    let CompatibleAppVariant: String
    let DeviceTraitSet: Int

    var humanReadableReport: String {
        """
        Platform: \(Platform)
        Target: \(Target) TargetType: \(TargetType) TargetVariant: \(TargetVariant)
        ProductType: \(ProductType) ProductDescription: \(ProductDescription)
        CompatibleDeviceFallback: \(CompatibleDeviceFallback) CompatibleAppVariant: \(CompatibleAppVariant)
        DeviceTraitSet: \(DeviceTraitSet)
        """
    }
    
    var exportEditFriendly: String {
        // TODO
        humanReadableReport
    }

    fileprivate init(
        Target: String?,
        TargetType: String?,
        TargetVariant: String?,
        Platform: String?,
        ProductType: String?,
        ProductDescription: String?,
        CompatibleDeviceFallback: String?,
        CompatibleAppVariant: String?,
        DeviceTraitSet: Int64?
    ) {
        self.Target = Target ?? unknownKey()
        self.TargetType = TargetType ?? unknownKey()
        self.TargetVariant = TargetVariant ?? unknownKey()
        self.Platform = Platform ?? unknownKey()
        self.ProductType = ProductType ?? unknownKey()
        self.ProductDescription = ProductDescription ?? unknownKey()
        self.CompatibleDeviceFallback = CompatibleDeviceFallback ?? unknownKey()
        self.CompatibleAppVariant = CompatibleAppVariant ?? unknownKey()
        self.DeviceTraitSet = Int(exactly: DeviceTraitSet ?? 0) ?? 0
    }
}

typealias HumanReadableName = String
typealias DeviceVariant = String
struct PlatformReport: Identifiable, Equatable {
    var id: UUID = UUID()
    let platform: String
    let variants: [HumanReadableName: DeviceRecord]
    init?(platformLocation: URL) {
        platform = platformLocation
            .deletingPathExtension()
            .lastPathComponent
        debugPrint("\(#function) \(platform)")
        let database = platformLocation
            .appendingPathComponent("usr")
            .appendingPathComponent("standalone")
            .appendingPathComponent("device_traits.db")
        guard FileManager.default.fileExists(atPath: database.path) else {
            return nil
        }
        debugPrint("loading \(database.path)")
        do {
            let db = try Connection(database.path)

            let devicesTable = Table("Devices")
            let elementTarget = Expression<String?>("Target")
            let elementTargetType = Expression<String?>("TargetType")
            let elementTargetVariant = Expression<String?>("TargetVariant")
            let elementPlatform = Expression<String?>("Platform")
            let elementProductType = Expression<String?>("ProductType")
            let elementProductDescription = Expression<String?>("ProductDescription")
            let elementCompatibleDeviceFallback = Expression<String?>("CompatibleDeviceFallback")
            let elementCompatibleAppVariant = Expression<String?>("CompatibleAppVariant")
            let elementDeviceTraitSet = Expression<Int64?>("DeviceTraitSet")

            var buildVariants = [HumanReadableName: DeviceRecord]()
            for recordElement in try db.prepare(devicesTable) {
                let record = DeviceRecord(Target: recordElement[elementTarget],
                                          TargetType: recordElement[elementTargetType],
                                          TargetVariant: recordElement[elementTargetVariant],
                                          Platform: recordElement[elementPlatform],
                                          ProductType: recordElement[elementProductType],
                                          ProductDescription: recordElement[elementProductDescription],
                                          CompatibleDeviceFallback: recordElement[elementCompatibleDeviceFallback],
                                          CompatibleAppVariant: recordElement[elementCompatibleAppVariant],
                                          DeviceTraitSet: recordElement[elementDeviceTraitSet])
                let humanName = record.ProductDescription
                buildVariants[humanName] = record
            }
            variants = buildVariants
            // Connection deinit { sqlite3_close(handle) } nice!
        } catch {
            debugPrint(error.localizedDescription)
            return nil
        }
        debugPrint("[i] \(platform) load complete with \(variants.count) records")
    }

    private init(id: UUID = UUID(), platform: String, variants: [HumanReadableName: DeviceRecord]) {
        self.id = id
        self.platform = platform
        self.variants = variants
    }

    static func == (lhs: PlatformReport, rhs: PlatformReport) -> Bool {
        lhs.id == rhs.id
    }

    func filtering(with key: String) -> PlatformReport? {
        if platform.lowercased().contains(key.lowercased()) {
            return self
        }
        let newVariantValues = variants
            .values
            .filter { $0.humanReadableReport.lowercased().contains(key.lowercased()) }
            .compactMap { $0 }
        if newVariantValues.count > 0 {
            var payload = [HumanReadableName: DeviceRecord]()
            for item in newVariantValues {
                payload[item.ProductDescription] = item
            }
            return Self(platform: platform, variants: payload)
        } else {
            return nil
        }
    }
}

typealias BundleReport = [PlatformReport]
func createReport(with bundle: Bundle) -> BundleReport {
    var result = [PlatformReport]()
    let searchPlatforms = bundle
        .bundleURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("Developer")
        .appendingPathComponent("Platforms")
    let platformLocations = try? FileManager
        .default
        .contentsOfDirectory(atPath: searchPlatforms.path)
    for platformDirName in (platformLocations ?? []).sorted() {
        let location = searchPlatforms
            .appendingPathComponent(platformDirName)
        if let platformReport = PlatformReport(platformLocation: location) {
            result.append(platformReport)
        }
    }
    return result
}

/*
 CREATE TABLE Devices (
     Target              TEXT
         COLLATE NOCASE
         PRIMARY KEY
         UNIQUE
         NOT NULL,
     TargetType          TEXT
         NOT NULL,
     TargetVariant       TEXT
         NOT NULL,
     Platform            TEXT
         COLLATE NOCASE
         NOT NULL,
     ProductType         TEXT
         COLLATE NOCASE
         NOT NULL,
     ProductDescription  TEXT
         COLLATE NOCASE,
     CompatibleDeviceFallback TEXT
         COLLATE NOCASE,
     CompatibleAppVariant   TEXT
         COLLATE NOCASE,
     DeviceTraitSet            INTEGER
         NOT NULL,
     FOREIGN KEY(DeviceTraitSet) REFERENCES DeviceTraits(DeviceTraitSetID)
 )
 */

extension String {
    func padded(required width: Int) -> String {
        let length = self.count
        guard length < width else {
            return self
        }
        let spaces = Array<Character>.init(repeating: " ", count: width - length)
        return self + spaces
    }
}
