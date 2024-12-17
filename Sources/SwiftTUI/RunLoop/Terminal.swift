import Foundation

class Terminal {
    private var originalTerminal: termios
    private var stdinSource: DispatchSourceRead?
    private var onInput: ((KeyPress) -> Application.InputHandled)?
    var application: Application?

    init(onInput: ((KeyPress) -> Application.InputHandled)?) {
        log("Setting up terminal")
        self.originalTerminal = termios()
        tcgetattr(STDIN_FILENO, &self.originalTerminal)

        var newTerminal = self.originalTerminal
        newTerminal.c_iflag &= ~tcflag_t(IXON | ICRNL)
        newTerminal.c_lflag &= ~tcflag_t(ECHO | ICANON | IEXTEN | ISIG)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &newTerminal)

        self.onInput = onInput
    }

    func start() {
        let stdinSource = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: .main)
        stdinSource.setEventHandler(qos: .default, flags: [], handler: self.handleInput)
        stdinSource.resume()
        self.stdinSource = stdinSource // needed to keep reference to source
    }

    private func handleInput() {
        let data = FileHandle.standardInput.availableData
        let keyPress = KeyPress(from: data)
        let input = self.onInput?(keyPress) ?? .propagate(keyPress: keyPress)
        if case let .propagate(keyPress) = input {
            self.application?.handleInput(keyPress)
        }
    }

    deinit {
        log("Freeing up terminal")
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &self.originalTerminal)
    }
}
