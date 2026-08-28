use ui
use compiler
class HustStudioApp
    fn start()
        window = Window("Hust Studio", 1440, 900)
        window.add(ProjectExplorer())
        window.add(CodeEditor(language = "hust"))
        window.add(DiagnosticsPanel())
        window.add(TerminalPanel())
        window.run()
    end
end
fn main()
    HustStudioApp().start()
end
