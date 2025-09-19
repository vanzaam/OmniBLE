import Foundation

// Compatibility shim for older OmniBLE code paths using Data.bytes
public extension Data {
    var bytes: [UInt8] { [UInt8](self) }
}


