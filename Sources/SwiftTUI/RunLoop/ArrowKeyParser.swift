import Foundation

public struct KeyPress {
    public let key: Key
    public let modifiers: Modifiers

    public enum Key {
        case character(Character)
        case up
        case down
        case right
        case left
        case unknown
    }

    public struct Modifiers: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
       
        public static var none = Modifiers(rawValue: 0)
        public static var ctrl = Modifiers(rawValue: 1 << 0)
        public static var alt = Modifiers(rawValue: 1 << 1)
        public static var shift = Modifiers(rawValue: 1 << 2)
    }

    init(from data: Data) {

        if data.count == 1, let char = data.first {
            switch char {
                case 0:
                    self.modifiers = [.ctrl]
                    self.key = .character(" ")
                case 1...26:
                    self.modifiers = [.ctrl]
                    self.key = .character(Character(UnicodeScalar(UInt8(64 + char))))
                case 27:
                    self.modifiers = [.ctrl]
                    self.key = .character("[")
                case 28:
                    self.modifiers = [.ctrl]
                    self.key = .character("\\")
                case 29:
                    self.modifiers = [.ctrl]
                    self.key = .character("]")
                case 30:
                    self.modifiers = [.ctrl]
                    self.key = .character("^")
                case 31:
                    self.modifiers = [.ctrl]
                    self.key = .character("_")
                case 127:
                    self.modifiers = [.ctrl]
                    self.key = .character("?")
                default:
                    self.modifiers = []
                    self.key = .character(Character(UnicodeScalar(char)))
            }
            return
        } else if data.count > 1 && data[0] == 27 {
            if data.count == 2 {
                self.modifiers = [.alt]
                self.key = .character(Character(UnicodeScalar(data[1])))
                return
            }
            if data.count >= 3 && data[1] == 91 {
                let arrowKeyIndex = data.count - 1
                switch data[arrowKeyIndex] {
                    case 65: self.key = .up
                    case 66: self.key = .down
                    case 67: self.key = .right
                    case 68: self.key = .left
                    // case 72: self.key = .home
                    // case 70: self.key = .end
                    default: self.key = .unknown
                }
                if data.count == 6 {
                    switch data[4] {
                        case 50: self.modifiers = [.shift]
                        case 51: self.modifiers = [.alt]
                        case 52: self.modifiers = [.alt, .shift]
                        case 53: self.modifiers = [.ctrl]
                        case 54: self.modifiers = [.ctrl, .shift]
                        case 55: self.modifiers = [.ctrl, .alt]
                        case 56: self.modifiers = [.ctrl, .alt, .shift]
                        default: self.modifiers = []
                    }
                    return
                }
                self.modifiers = []
                return
            }
        }
        
        self.modifiers = []
        self.key = .unknown
    }
}
