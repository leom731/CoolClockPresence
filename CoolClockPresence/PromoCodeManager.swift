// (c) 2025 Leo Manderico
// COOL CLOCK PRESENCE
// All rights reserved
//
//  PromoCodeManager.swift
//
//  Handles promotional code validation and redemption
//

#if os(macOS)
import Foundation
import CryptoKit

@MainActor
class PromoCodeManager {
    static let shared = PromoCodeManager()

    private let defaults = UserDefaults.standard
    private let usedCodesKey = "usedPromoCodes"
    private let deviceIDKey = "deviceIdentifier"

    // MARK: - Valid Promo Codes
    // Add your promotional codes here
    // Format: [code: description]
    private let validPromoCodes: [String: String] = [
        "FAMILY860116": "Family & Friends Premium Access",
        "FRIEND860116": "Friend Premium Access",
        "BETA860116": "Beta Tester Premium Access"
        // Add more codes as needed
    ]

    private init() {
        // Generate or retrieve device identifier
        if defaults.string(forKey: deviceIDKey) == nil {
            defaults.set(generateDeviceID(), forKey: deviceIDKey)
        }
    }

    // MARK: - Device Identifier

    private func generateDeviceID() -> String {
        // Create a unique identifier for this device/user
        // Using a combination of hardware info to create a stable ID
        let hardwareUUID = ProcessInfo.processInfo.hostName
        let data = Data(hardwareUUID.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private var deviceID: String {
        return defaults.string(forKey: deviceIDKey) ?? generateDeviceID()
    }

    // MARK: - Used Codes Storage

    private func getUsedCodes() -> [String: [String]] {
        // Returns dictionary of [code: [deviceIDs]]
        // This allows the same code to be used by multiple users, but only once per user
        return defaults.dictionary(forKey: usedCodesKey) as? [String: [String]] ?? [:]
    }

    private func markCodeAsUsed(_ code: String) {
        var usedCodes = getUsedCodes()
        var devicesForCode = usedCodes[code] ?? []
        devicesForCode.append(deviceID)
        usedCodes[code] = devicesForCode
        defaults.set(usedCodes, forKey: usedCodesKey)
    }

    // MARK: - Validation

    enum PromoCodeError: LocalizedError {
        case invalidCode
        case alreadyUsedByThisDevice

        var errorDescription: String? {
            switch self {
            case .invalidCode:
                return "Invalid promotional code"
            case .alreadyUsedByThisDevice:
                return "You have already used this code"
            }
        }
    }

    func validateAndRedeemCode(_ code: String) throws {
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if code exists in valid codes
        guard validPromoCodes[normalizedCode] != nil else {
            throw PromoCodeError.invalidCode
        }

        // Check if THIS device has already used this code
        let usedCodes = getUsedCodes()
        if let devicesForCode = usedCodes[normalizedCode] {
            if devicesForCode.contains(deviceID) {
                throw PromoCodeError.alreadyUsedByThisDevice
            }
        }

        // Code is valid and hasn't been used by this device - redeem it
        markCodeAsUsed(normalizedCode)
        unlockPremium()
    }

    // MARK: - Premium Unlock

    private func unlockPremium() {
        defaults.set(true, forKey: "isPremiumUnlocked")
        defaults.set(true, forKey: "unlockedViaPromoCode")

        // Post notification to update UI
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    }

    // MARK: - Check Premium Status

    func isPremiumUnlockedViaPromoCode() -> Bool {
        return defaults.bool(forKey: "unlockedViaPromoCode")
    }

    // MARK: - Admin Functions (for debugging/testing)

    func resetAllPromoCodes() {
        defaults.removeObject(forKey: usedCodesKey)
        defaults.set(false, forKey: "unlockedViaPromoCode")
    }

    func listUsedCodes() -> [String: [String]] {
        return getUsedCodes()
    }

    func getUsageCountForCode(_ code: String) -> Int {
        let usedCodes = getUsedCodes()
        return usedCodes[code.uppercased()]?.count ?? 0
    }

    // MARK: - Add New Codes Programmatically (Optional)

    // Note: In production, you might want to fetch codes from a server
    // or have a more secure way of adding codes. For now, they're hardcoded above.
}
#endif
