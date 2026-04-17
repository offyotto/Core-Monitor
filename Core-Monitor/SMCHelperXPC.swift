import Foundation

@objc protocol SMCHelperXPCProtocol {
    nonisolated func setFanManual(_ fanID: Int, rpm: Int, withReply reply: @escaping (NSString?) -> Void)
    nonisolated func setFanAuto(_ fanID: Int, withReply reply: @escaping (NSString?) -> Void)
    nonisolated func readValue(_ key: String, withReply reply: @escaping (NSNumber?, NSString?) -> Void)
}
