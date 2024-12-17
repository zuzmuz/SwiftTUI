import Foundation
#if os(macOS)
import AppKit
#endif

public class Application {
    private let node: Node
    private let window: Window
    private let control: Control
    private let renderer: Renderer
    private let terminal: Terminal

    private let runLoopType: RunLoopType

    private var invalidatedNodes: [Node] = []
    private var updateScheduled = false

    public init<I: View>(rootView: I,
                         runLoopType: RunLoopType = .dispatch,
                         onInput: ((KeyPress) -> InputHandled)? = nil) {
        self.runLoopType = runLoopType
        self.terminal = Terminal(onInput: onInput)

        node = Node(view: VStack(content: rootView).view)
        node.build()

        control = node.control!

        window = Window()
        window.addControl(control)

        window.firstResponder = control.firstSelectableElement
        window.firstResponder?.becomeFirstResponder()

        renderer = Renderer(layer: window.layer)
        window.layer.renderer = renderer

        node.application = self
        renderer.application = self
        terminal.application = self
    }

    public enum RunLoopType {
        /// The default option, using Dispatch for the main run loop.
        case dispatch

        #if os(macOS)
        /// This creates and runs an NSApplication with an associated run loop. This allows you
        /// e.g. to open NSWindows running simultaneously to the terminal app. This requires macOS
        /// and AppKit.
        case cocoa
        #endif
    }

    public enum InputHandled {
        case propagate(keyPress: KeyPress)
        case handled
    }

    public func start() {
        updateWindowSize()
        control.layout(size: window.layer.frame.size)
        renderer.draw()

        self.terminal.start()

        let sigWinChSource = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .main)
        sigWinChSource.setEventHandler(qos: .default, flags: [], handler: self.handleWindowSizeChange)
        sigWinChSource.resume()

        switch runLoopType {
        case .dispatch:
            dispatchMain()
        #if os(macOS)
        case .cocoa:
            NSApplication.shared.setActivationPolicy(.accessory)
            NSApplication.shared.run()
        #endif
        }
    }

    func handleInput(_ keyPress: KeyPress) {
        switch (keyPress.key, keyPress.modifiers) {
            case (.down, .none):
                if let next = window.firstResponder?.selectableElement(below: 0) {
                    window.firstResponder?.resignFirstResponder()
                    window.firstResponder = next
                    window.firstResponder?.becomeFirstResponder()
                }
            case (.up, .none):
                if let next = window.firstResponder?.selectableElement(above: 0) {
                    window.firstResponder?.resignFirstResponder()
                    window.firstResponder = next
                    window.firstResponder?.becomeFirstResponder()
                }
            case (.right, .none):
                if let next = window.firstResponder?.selectableElement(rightOf: 0) {
                    window.firstResponder?.resignFirstResponder()
                    window.firstResponder = next
                    window.firstResponder?.becomeFirstResponder()
                }
            case (.left, .none):
                if let next = window.firstResponder?.selectableElement(leftOf: 0) {
                    window.firstResponder?.resignFirstResponder()
                    window.firstResponder = next
                    window.firstResponder?.becomeFirstResponder()
                }
            case (.character("C"), .ctrl):
                stop()
            case (.character(let char), .none):
                window.firstResponder?.handleEvent(char)
            default:
                break
        }
    }

    func invalidateNode(_ node: Node) {
        invalidatedNodes.append(node)
        scheduleUpdate()
    }

    func scheduleUpdate() {
        if !updateScheduled {
            DispatchQueue.main.async { self.update() }
            updateScheduled = true
        }
    }

    private func update() {
        updateScheduled = false

        for node in invalidatedNodes {
            node.update(using: node.view)
        }
        invalidatedNodes = []

        control.layout(size: window.layer.frame.size)
        renderer.update()
    }

    private func handleWindowSizeChange() {
        updateWindowSize()
        control.layer.invalidate()
        update()
    }

    private func updateWindowSize() {
        var size = winsize()
        guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0,
              size.ws_col > 0, size.ws_row > 0 else {
            assertionFailure("Could not get window size")
            return
        }
        window.layer.frame.size = Size(width: Extended(Int(size.ws_col)), height: Extended(Int(size.ws_row)))
        renderer.setCache()
    }

    private func stop() {
        renderer.stop()
        exit(0)
    }
}
