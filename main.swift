import Cocoa
import WebKit

// MARK: - Security Helpers
func isAllowedSecureHost(_ host: String) -> Bool {
    let lower = host.lowercased()
    let allowedDomains = [
        "notion.so",
        "notion.com",
        "notion.site",
        "accounts.google.com",
        "appleid.apple.com"
    ]
    return allowedDomains.contains { domain in
        lower == domain || lower.hasSuffix("." + domain)
    }
}

// MARK: - Constants & Defaults
func getInitialDefaultURL() -> String {
    if let url = Bundle.main.url(forResource: "config.local", withExtension: "json"),
       let data = try? Data(contentsOf: url),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let defaultURL = json["defaultURL"] as? String, !defaultURL.isEmpty {
        return defaultURL
    }
    return "https://www.notion.so"
}

let defaultNotionURL = getInitialDefaultURL()
let kSavedURLKey = "NotionWidgetSavedURL"
let kWindowModeKey = "NotionWidgetWindowMode"
let kCleanModeKey = "NotionWidgetCleanMode"
let kWindowFrameKey = "NotionWidgetWindowFrame"

// User Agent matching standard macOS Safari 18
let kStandardUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15"

enum WindowDisplayMode: Int {
    case behindApps = 0   // Sits behind active apps, joins all spaces
    case floating = 1     // Always on top
    case wallpaper = 2    // Pinned directly to desktop wallpaper layer
}

// MARK: - Custom Widget Window
class WidgetWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

// MARK: - Top Drag Strip
class TopDragStripView: NSView {
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        
        let initialLocation = event.locationInWindow
        while let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if nextEvent.type == .leftMouseUp { break }
            let currentLocation = nextEvent.locationInWindow
            let dx = currentLocation.x - initialLocation.x
            let dy = currentLocation.y - initialLocation.y
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x + dx, y: window.frame.origin.y + dy))
        }
    }
}

// MARK: - Sleek Hover Control Pill
class ControlPillView: NSView {
    var trackingArea: NSTrackingArea?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.94).cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 0.82, alpha: 0.7).cgColor
        alphaValue = 0.2 // subtle hint; reveals on hover
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            self.animator().alphaValue = 0.2
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        
        let initialLocation = event.locationInWindow
        while let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if nextEvent.type == .leftMouseUp { break }
            let currentLocation = nextEvent.locationInWindow
            let dx = currentLocation.x - initialLocation.x
            let dy = currentLocation.y - initialLocation.y
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x + dx, y: window.frame.origin.y + dy))
        }
    }
}

// MARK: - Main Application Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    var window: WidgetWindow!
    var webView: WKWebView!
    var statusItem: NSStatusItem!
    var controlPill: ControlPillView!
    var modeButton: NSButton!
    
    var popupWindow: NSWindow?
    var popupWebView: WKWebView?
    
    var currentMode: WindowDisplayMode = .behindApps
    var isCleanMode: Bool = true
    var currentURLString: String = defaultNotionURL
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load preferences
        if let savedURL = UserDefaults.standard.string(forKey: kSavedURLKey), !savedURL.isEmpty {
            currentURLString = savedURL
        } else {
            currentURLString = defaultNotionURL
            UserDefaults.standard.set(currentURLString, forKey: kSavedURLKey)
        }
        
        if let savedMode = UserDefaults.standard.object(forKey: kWindowModeKey) as? Int {
            currentMode = WindowDisplayMode(rawValue: savedMode) ?? .behindApps
        } else {
            currentMode = .behindApps
            UserDefaults.standard.set(WindowDisplayMode.behindApps.rawValue, forKey: kWindowModeKey)
        }
        
        if UserDefaults.standard.object(forKey: kCleanModeKey) != nil {
            isCleanMode = UserDefaults.standard.bool(forKey: kCleanModeKey)
        }
        
        setupMainMenu()
        setupWindow()
        setupMenuStatusItem()
        loadCurrentURL()
    }
    
    // MARK: - Standard macOS Main Menu (Enables Cmd+C, Cmd+V, Cmd+A, Cmd+Z)
    func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Notion Widget", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Notion Widget", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Edit Menu (Enables system-wide Cmd+V paste, Cmd+C copy, Cmd+A select all)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false
    }
    
    // MARK: - Window Setup
    func setupWindow() {
        let initialWidth: CGFloat = 720
        let initialHeight: CGFloat = 520
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1400, height: 900)
        let initialX = screenFrame.maxX - initialWidth - 30
        let initialY = screenFrame.maxY - initialHeight - 40
        var windowRect = NSRect(x: initialX, y: initialY, width: initialWidth, height: initialHeight)
        
        if let savedFrameString = UserDefaults.standard.string(forKey: kWindowFrameKey) {
            let savedRect = NSRectFromString(savedFrameString)
            if savedRect.width >= 350 && savedRect.width <= 1400 && savedRect.height >= 250 && savedRect.height <= 1100 {
                // Ensure frame is visible on the current screen
                if screenFrame.intersects(savedRect) {
                    windowRect = savedRect
                }
            }
        }
        
        window = WidgetWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.appearance = NSAppearance(named: .aqua)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 360, height: 260)
        window.isMovableByWindowBackground = false
        
        // Background View
        let visualEffectView = NSVisualEffectView(frame: window.contentView!.bounds)
        visualEffectView.appearance = NSAppearance(named: .aqua)
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1.0
        visualEffectView.layer?.borderColor = NSColor(white: 0.82, alpha: 0.7).cgColor
        visualEffectView.layer?.backgroundColor = NSColor.white.cgColor
        visualEffectView.autoresizingMask = [.width, .height]
        window.contentView = visualEffectView
        
        // WKWebView with Strict Security Configuration
        let webConfig = WKWebViewConfiguration()
        webConfig.websiteDataStore = WKWebsiteDataStore.default()
        webConfig.preferences.javaScriptCanOpenWindowsAutomatically = true
        webConfig.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Security: Block any local filesystem access from JavaScript
        webConfig.preferences.setValue(false, forKey: "allowFileAccessFromFileURLs")
        webConfig.setValue(false, forKey: "allowUniversalAccessFromFileURLs")
        
        let lightModeScript = "try { localStorage.setItem('theme', JSON.stringify({ mode: 'light' })); } catch(e) {}"
        let userScript = WKUserScript(source: lightModeScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webConfig.userContentController.addUserScript(userScript)
        
        webView = WKWebView(frame: visualEffectView.bounds, configuration: webConfig)
        webView.appearance = NSAppearance(named: .aqua)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = kStandardUserAgent
        webView.setValue(true, forKey: "drawsBackground")
        visualEffectView.addSubview(webView)
        
        // Top 14px Drag Strip
        let topDrag = TopDragStripView(frame: NSRect(x: 0, y: windowRect.height - 14, width: windowRect.width, height: 14))
        topDrag.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(topDrag)
        
        // Floating Hover Pill at top right
        let pillWidth: CGFloat = 175
        let pillHeight: CGFloat = 26
        controlPill = ControlPillView(frame: NSRect(x: windowRect.width - pillWidth - 12, y: windowRect.height - pillHeight - 8, width: pillWidth, height: pillHeight))
        controlPill.autoresizingMask = [.minXMargin, .minYMargin]
        visualEffectView.addSubview(controlPill)
        
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 6
        buttonStack.alignment = .centerY
        buttonStack.frame = controlPill.bounds.insetBy(dx: 6, dy: 2)
        buttonStack.autoresizingMask = [.width, .height]
        controlPill.addSubview(buttonStack)
        
        let settingsButton = createSmallButton(title: "⚙️", tooltip: "Settings & Select Database (Cmd+,)")
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        buttonStack.addArrangedSubview(settingsButton)
        
        modeButton = createSmallButton(title: modeButtonTitle(for: currentMode), tooltip: "Change display mode: Normal (Behind Apps) / Float / Wallpaper")
        modeButton.target = self
        modeButton.action = #selector(cycleWindowMode)
        buttonStack.addArrangedSubview(modeButton)
        
        let reloadButton = createSmallButton(title: "🔄", tooltip: "Reload Database")
        reloadButton.target = self
        reloadButton.action = #selector(reloadPage)
        buttonStack.addArrangedSubview(reloadButton)
        
        let hideButton = createSmallButton(title: "✕", tooltip: "Hide (Click Dock/Menu Bar to restore)")
        hideButton.target = self
        hideButton.action = #selector(hideWidget)
        buttonStack.addArrangedSubview(hideButton)
        
        applyWindowMode(currentMode)
        
        // ALWAYS bring visibly to front on launch so user immediately sees it!
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidMoveOrResize), name: NSWindow.didMoveNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidMoveOrResize), name: NSWindow.didResizeNotification, object: window)
    }
    
    func createSmallButton(title: String, tooltip: String) -> NSButton {
        let btn = NSButton(title: title, target: nil, action: nil)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        btn.toolTip = tooltip
        btn.controlSize = .small
        btn.contentTintColor = NSColor(white: 0.25, alpha: 1.0)
        return btn
    }
    
    func modeButtonTitle(for mode: WindowDisplayMode) -> String {
        switch mode {
        case .behindApps: return "📌 Normal"
        case .floating: return "🔝 Float"
        case .wallpaper: return "🖼️ Wall"
        }
    }
    
    // MARK: - Display Modes
    func applyWindowMode(_ mode: WindowDisplayMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: kWindowModeKey)
        modeButton.title = modeButtonTitle(for: mode)
        SettingsWindowController.shared.syncMode(mode)
        
        switch mode {
        case .behindApps:
            // Sits normally behind other apps, available across all spaces!
            window.level = .normal
            window.collectionBehavior = [.canJoinAllSpaces]
        case .floating:
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        case .wallpaper:
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        }
    }
    
    @objc func cycleWindowMode() {
        let nextMode: WindowDisplayMode
        switch currentMode {
        case .behindApps: nextMode = .floating
        case .floating: nextMode = .wallpaper
        case .wallpaper: nextMode = .behindApps
        }
        applyWindowMode(nextMode)
    }
    
    @objc func windowDidMoveOrResize() {
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: kWindowFrameKey)
    }
    
    // MARK: - Menu Bar Status Item
    func setupMenuStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let menuIconURL = Bundle.main.url(forResource: "MenuIcon", withExtension: "png"),
               let customIcon = NSImage(contentsOf: menuIconURL) {
                customIcon.isTemplate = true
                button.image = customIcon
            } else {
                let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
                if let img = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Notion Widget")?.withSymbolConfiguration(config) {
                    button.image = img
                } else {
                    button.title = "📊"
                }
            }
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Notion Widget", action: #selector(showAndActivateWidget), keyEquivalent: "w"))
        menu.addItem(NSMenuItem(title: "⚙️ Settings & Database Selector...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        
        let modeMenuItem = NSMenuItem(title: "Window Mode", action: nil, keyEquivalent: "")
        let modeSubmenu = NSMenu()
        modeSubmenu.addItem(NSMenuItem(title: "📌 Behind Apps (Standard Widget)", action: #selector(setBehindAppsMode), keyEquivalent: ""))
        modeSubmenu.addItem(NSMenuItem(title: "🔝 Always on Top (Floating)", action: #selector(setFloatingMode), keyEquivalent: ""))
        modeSubmenu.addItem(NSMenuItem(title: "🖼️ Pinned to Wallpaper", action: #selector(setWallpaperMode), keyEquivalent: ""))
        modeMenuItem.submenu = modeSubmenu
        menu.addItem(modeMenuItem)
        
        menu.addItem(NSMenuItem(title: "✨ Toggle Clean Database View", action: #selector(toggleCleanMode), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "🔄 Reload Database", action: #selector(reloadPage), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "🌐 Open in Default Browser", action: #selector(openInBrowser), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "🔗 Change Notion URL...", action: #selector(promptChangeURL), keyEquivalent: "u"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "🔒 Clear Session & Sign Out...", action: #selector(clearSessionData), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Notion Widget", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    // MARK: - Actions
    @objc func openSettings() {
        let ctrl = SettingsWindowController.shared
        ctrl.appDelegate = self
        ctrl.showSettings()
    }
    
    @objc func showAndActivateWidget() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func hideWidget() {
        window.orderOut(nil)
    }
    
    @objc func setBehindAppsMode() { applyWindowMode(.behindApps) }
    @objc func setFloatingMode() { applyWindowMode(.floating) }
    @objc func setWallpaperMode() { applyWindowMode(.wallpaper) }
    
    @objc func reloadPage() {
        webView.reload()
    }
    
    @objc func openInBrowser() {
        if let url = URL(string: currentURLString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func toggleCleanMode() {
        isCleanMode = !isCleanMode
        UserDefaults.standard.set(isCleanMode, forKey: kCleanModeKey)
        applyCleanDatabaseCSS()
    }
    
    @objc func promptChangeURL() {
        let alert = NSAlert()
        alert.messageText = "Change Notion Database URL"
        alert.informativeText = "Paste the link to your Notion database view:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save & Load")
        alert.addButton(withTitle: "Cancel")
        
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        inputTextField.stringValue = currentURLString
        alert.accessoryView = inputTextField
        
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newURL = inputTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newURL.isEmpty && URL(string: newURL) != nil {
                currentURLString = newURL
                UserDefaults.standard.set(currentURLString, forKey: kSavedURLKey)
                loadCurrentURL()
            }
        }
    }
    
    @objc func clearSessionData() {
        let alert = NSAlert()
        alert.messageText = "Clear Session & Sign Out?"
        alert.informativeText = "This will securely remove all cached cookies, database tokens, and local storage from this widget."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear & Sign Out")
        alert.addButton(withTitle: "Cancel")
        
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) { [weak self] in
                DispatchQueue.main.async {
                    self?.loadCurrentURL()
                }
            }
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func loadCurrentURL() {
        if let url = URL(string: currentURLString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    // MARK: - Clean Database View Alignment & Padding Optimization
    func applyCleanDatabaseCSS() {
        guard isCleanMode else {
            let removeCSS = "var existing = document.getElementById('notion-widget-custom-style'); if (existing) { existing.remove(); }"
            webView.evaluateJavaScript(removeCSS, completionHandler: nil)
            return
        }
        
        // Never hide UI if the user is currently on the login or authentication page!
        if let urlStr = webView.url?.absoluteString.lowercased(),
           urlStr.contains("/login") || urlStr.contains("google.com") || urlStr.contains("apple.com") || urlStr.contains("auth") {
            let removeCSS = "var existing = document.getElementById('notion-widget-custom-style'); if (existing) { existing.remove(); }"
            webView.evaluateJavaScript(removeCSS, completionHandler: nil)
            return
        }
        
        let css = """
        var existing = document.getElementById('notion-widget-custom-style');
        if (!existing) {
            var style = document.createElement('style');
            style.id = 'notion-widget-custom-style';
            style.innerHTML = `
                :root { color-scheme: light !important; }
                
                /* Hide all distracting Notion navigation bars, breadcrumbs, covers & icons */
                .notion-topbar,
                .notion-topbar-mobile,
                .notion-sidebar-container,
                .notion-help-button,
                header,
                .notion-page-icon-hero,
                .notion-page-icon-cover,
                .notion-page-controls,
                .notion-page-cover {
                    display: none !important;
                }
                
                /* Reset layout offset caused by hidden topbar */
                .notion-cursor-listener > div:first-child > div:first-child {
                    top: 0 !important;
                }
                
                /* Remove massive side & bottom margins so database fills widget width */
                .notion-frame {
                    padding-left: 12px !important;
                    padding-right: 12px !important;
                    padding-top: 8px !important;
                    padding-bottom: 24px !important;
                    width: 100% !important;
                    max-width: 100% !important;
                }
                
                .notion-scroller {
                    padding: 0 !important;
                    margin: 0 !important;
                    width: 100% !important;
                }
                
                .notion-page-content {
                    width: 100% !important;
                    max-width: 100% !important;
                    padding: 0 !important;
                    margin: 0 !important;
                }
                
                /* Expand collection table/board container */
                .notion-collection_view-block,
                .notion-collection-view-body,
                .notion-table-view,
                .notion-board-view {
                    width: 100% !important;
                    max-width: 100% !important;
                }
                
                /* Minimal slim scrollbars */
                ::-webkit-scrollbar {
                    width: 6px;
                    height: 6px;
                }
                ::-webkit-scrollbar-thumb {
                    background: rgba(0, 0, 0, 0.18);
                    border-radius: 3px;
                }
                ::-webkit-scrollbar-track {
                    background: transparent;
                }
            `;
            document.head.appendChild(style);
        }
        
        try {
            document.documentElement.classList.remove('dark');
            document.documentElement.classList.add('light');
            document.body.classList.remove('dark');
            document.body.classList.add('light');
        } catch(e) {}
        """
        webView.evaluateJavaScript(css, completionHandler: nil)
    }
    
    // MARK: - WKNavigationDelegate (Domain Allowlisting & Navigation Jail)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        // Allow internal initial loads
        if url.absoluteString == "about:blank" {
            decisionHandler(.allow)
            return
        }
        
        // Enforce secure HTTPS
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "notion" else {
            decisionHandler(.cancel)
            return
        }
        
        guard let host = url.host?.lowercased() else {
            decisionHandler(.cancel)
            return
        }
        
        // Strictly allow only verified Notion and OAuth domains
        if isAllowedSecureHost(host) {
            decisionHandler(.allow)
        } else {
            // Untrusted external link clicked in notes/database!
            // Quarantine: Do NOT load inside the widget session. Open safely in default browser.
            decisionHandler(.cancel)
            NSWorkspace.shared.open(url)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView == self.webView {
            applyCleanDatabaseCSS()
            
            let lightModeJS = """
            try {
                localStorage.setItem('theme', JSON.stringify({ mode: 'light' }));
                document.documentElement.classList.remove('dark');
                document.documentElement.classList.add('light');
                document.body.classList.remove('dark');
                document.body.classList.add('light');
            } catch(e) {}
            """
            webView.evaluateJavaScript(lightModeJS, completionHandler: nil)
        }
    }
    
    // MARK: - WKUIDelegate (Google / SSO / Popup Login Handler)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let targetURL = navigationAction.request.url {
            if let host = targetURL.host?.lowercased(), !isAllowedSecureHost(host) {
                // External popup link: redirect to default browser
                NSWorkspace.shared.open(targetURL)
                return nil
            }
        }
        
        popupWindow?.close()
        
        let popup = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 560, height: 680),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        popup.title = "Notion Sign In"
        popup.appearance = NSAppearance(named: .aqua)
        popup.center()
        
        let popWeb = WKWebView(frame: popup.contentView!.bounds, configuration: configuration)
        popWeb.appearance = NSAppearance(named: .aqua)
        popWeb.autoresizingMask = [.width, .height]
        popWeb.uiDelegate = self
        popWeb.navigationDelegate = self
        popWeb.customUserAgent = kStandardUserAgent
        
        popup.contentView?.addSubview(popWeb)
        popup.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.popupWindow = popup
        self.popupWebView = popWeb
        return popWeb
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        if webView == self.popupWebView {
            self.popupWindow?.close()
            self.popupWindow = nil
            self.popupWebView = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.loadCurrentURL()
            }
        }
    }
}

// MARK: - App Main Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular) // Shows in Dock and switches like a normal Mac app!
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
