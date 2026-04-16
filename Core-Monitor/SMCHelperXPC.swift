import Foundation

@objc protocol SMCHelperXPCProtocol {
    func setFanManual(_ fanID: Int, rpm: Int, withReply reply: @escaping (NSString?) -> Void)
    func setFanAuto(_ fanID: Int, withReply reply: @escaping (NSString?) -> Void)
    func readValue(_ key: String, withReply reply: @escaping (NSNumber?, NSString?) -> Void)
}
