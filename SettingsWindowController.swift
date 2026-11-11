import Cocoa
import WebKit

let kSavedPagesListKey = "NotionWidgetSavedPagesList"

struct NotionPageItem {
    var name: String
    var url: String
    
    var dictionary: [String: String] {
        return ["name": name, "url": url]
    }
    
    init(name: String, url: String) {
        self.name = name
        self.url = url
    }
    
    init?(dictionary: [String: String]) {
        guard let name = dictionary["name"], let url = dictionary["url"] else { return nil }
        self.name = name
        self.url = url
    }
}

class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = SettingsWindowController()
    
    weak var appDelegate: AppDelegate?
    
    var savedPages: [NotionPageItem] = []
    
    // UI Outlets
    private var segmentedControl: NSSegmentedControl!
    private var pagesContainerView: NSView!
    private var appearanceContainerView: NSView!
    private var securityContainerView: NSView!
    
    // Pages Tab UI
    private var tableView: NSTableView!
    private var newNameField: NSTextField!
    private var newURLField: NSTextField!
    private var activeURLField: NSTextField!
    
    // Appearance Tab UI
    private var cleanModeCheckbox: NSButton!
    private var modePopUp: NSPopUpButton!
    private var themePopUp: NSPopUpButton!
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Notion Widget Settings"
        window.appearance = NSAppearance(named: .aqua)
        window.center()
        self.init(window: window)
        
        loadSavedPages()
        setupUI()
    }
    
    func loadSavedPages() {
        if let rawList = UserDefaults.standard.array(forKey: kSavedPagesListKey) as? [[String: String]], !rawList.isEmpty {
            savedPages = rawList.compactMap { NotionPageItem(dictionary: $0) }
        } else {
            // Check if local git-ignored configuration exists
            if let configURL = Bundle.main.url(forResource: "config.local", withExtension: "json"),
               let data = try? Data(contentsOf: configURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let localList = json["savedPages"] as? [[String: String]], !localList.isEmpty {
                savedPages = localList.compactMap { NotionPageItem(dictionary: $0) }
            } else {
                savedPages = [
                    NotionPageItem(
                        name: "Notion Workspace",
                        url: "https://www.notion.so"
                    )
                ]
            }
            savePagesList()
        }
    }
    
    func savePagesList() {
        let rawList = savedPages.map { $0.dictionary }
        UserDefaults.standard.set(rawList, forKey: kSavedPagesListKey)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        guard let window = self.window, let contentView = window.contentView else { return }
        
        // Segmented Control (Tabs)
        segmentedControl = NSSegmentedControl(labels: ["📄 Pages & Databases", "🎨 Appearance", "🔒 Security"],
                                              trackingMode: .selectOne,
                                              target: self,
                                              action: #selector(tabChanged))
        segmentedControl.selectedSegment = 0
        segmentedControl.frame = NSRect(x: 20, y: 500, width: 520, height: 32)
        contentView.addSubview(segmentedControl)
        
        // Setup 3 tab containers
        let contentRect = NSRect(x: 20, y: 15, width: 520, height: 475)
        
        pagesContainerView = NSView(frame: contentRect)
        appearanceContainerView = NSView(frame: contentRect)
        securityContainerView = NSView(frame: contentRect)
        
        contentView.addSubview(pagesContainerView)
        contentView.addSubview(appearanceContainerView)
        contentView.addSubview(securityContainerView)
        
        setupPagesTab()
        setupAppearanceTab()
        setupSecurityTab()
        
        showTab(index: 0)
    }
    
    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        showTab(index: sender.selectedSegment)
    }
    
    private func showTab(index: Int) {
        pagesContainerView.isHidden = (index != 0)
        appearanceContainerView.isHidden = (index != 1)
        securityContainerView.isHidden = (index != 2)
        
        if index == 0 {
            updateActiveURLField()
            tableView.reloadData()
        }
    }
    
    // MARK: - Tab 1: Pages & Databases
    private func setupPagesTab() {
        // Label
        let tableTitle = NSTextField(labelWithString: "Saved Pages & Databases:")
        tableTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        tableTitle.frame = NSRect(x: 0, y: 400, width: 300, height: 18)
        pagesContainerView.addSubview(tableTitle)
        
        // TableView for Saved Pages
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 220, width: 520, height: 175))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        
        tableView = NSTableView(frame: scroll.bounds)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PageCol"))
        col.title = "Page / Database"
        col.width = 500
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(loadSelectedPage)
        
        scroll.documentView = tableView
        pagesContainerView.addSubview(scroll)
        
        // Buttons under table
        let selectBtn = NSButton(title: "🚀 Open Selected Page", target: self, action: #selector(loadSelectedPage))
        selectBtn.bezelStyle = .rounded
        selectBtn.frame = NSRect(x: 0, y: 182, width: 170, height: 30)
        pagesContainerView.addSubview(selectBtn)
        
        let removeBtn = NSButton(title: "🗑️ Remove", target: self, action: #selector(removeSelectedPage))
        removeBtn.bezelStyle = .rounded
        removeBtn.frame = NSRect(x: 180, y: 182, width: 110, height: 30)
        pagesContainerView.addSubview(removeBtn)
        
        // Separator
        let sep = NSBox(frame: NSRect(x: 0, y: 170, width: 520, height: 1))
        sep.boxType = .separator
        pagesContainerView.addSubview(sep)
        
        // Add New Page Section
        let addTitle = NSTextField(labelWithString: "Add a New Notion Page or Database:")
        addTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        addTitle.frame = NSRect(x: 0, y: 145, width: 350, height: 18)
        pagesContainerView.addSubview(addTitle)
        
        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.frame = NSRect(x: 0, y: 118, width: 50, height: 18)
        pagesContainerView.addSubview(nameLabel)
        
        newNameField = NSTextField(frame: NSRect(x: 55, y: 116, width: 465, height: 22))
        newNameField.placeholderString = "e.g. Daily Tasks, Sprint Board, Reading List"
        pagesContainerView.addSubview(newNameField)
        
        let urlLabel = NSTextField(labelWithString: "URL:")
        urlLabel.frame = NSRect(x: 0, y: 88, width: 50, height: 18)
        pagesContainerView.addSubview(urlLabel)
        
        newURLField = NSTextField(frame: NSRect(x: 55, y: 86, width: 365, height: 22))
        newURLField.placeholderString = "https://app.notion.com/... or https://notion.so/..."
        pagesContainerView.addSubview(newURLField)
        
        let pasteBtn = NSButton(title: "📋 Paste", target: self, action: #selector(pasteFromClipboard))
        pasteBtn.bezelStyle = .rounded
        pasteBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        pasteBtn.frame = NSRect(x: 425, y: 82, width: 95, height: 28)
        pagesContainerView.addSubview(pasteBtn)
        
        let addBtn = NSButton(title: "➕ Add to Saved & Switch", target: self, action: #selector(addNewPage))
        addBtn.bezelStyle = .rounded
        addBtn.keyEquivalent = "\r"
        addBtn.frame = NSRect(x: 52, y: 48, width: 195, height: 32)
        pagesContainerView.addSubview(addBtn)
        
        // Active URL bar at bottom
        let activeLabel = NSTextField(labelWithString: "Currently Active URL:")
        activeLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        activeLabel.textColor = .secondaryLabelColor
        activeLabel.frame = NSRect(x: 0, y: 22, width: 130, height: 16)
        pagesContainerView.addSubview(activeLabel)
        
        activeURLField = NSTextField(labelWithString: "")
        activeURLField.font = NSFont.systemFont(ofSize: 11)
        activeURLField.textColor = .systemBlue
        activeURLField.frame = NSRect(x: 132, y: 22, width: 388, height: 16)
        activeURLField.lineBreakMode = .byTruncatingTail
        pagesContainerView.addSubview(activeURLField)
    }
    
    // MARK: - Tab 2: Appearance & Layout
    private func setupAppearanceTab() {
        let title = NSTextField(labelWithString: "Widget Appearance & Window Placement")
        title.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        title.frame = NSRect(x: 0, y: 445, width: 450, height: 20)
        appearanceContainerView.addSubview(title)
        
        // Window Mode Section
        let modeLabel = NSTextField(labelWithString: "Window Layer / Placement Mode:")
        modeLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        modeLabel.frame = NSRect(x: 0, y: 416, width: 260, height: 18)
        appearanceContainerView.addSubview(modeLabel)
        
        modePopUp = NSPopUpButton(frame: NSRect(x: 0, y: 385, width: 340, height: 26))
        modePopUp.addItems(withTitles: [
            "📌 Normal (Behind Apps)",
            "🔝 Float (Always on Top)",
            "🖼️ Wall (Desktop Wallpaper Layer)"
        ])
        modePopUp.target = self
        modePopUp.action = #selector(modePopUpChanged)
        appearanceContainerView.addSubview(modePopUp)
        
        // Mode Explanations Box
        let box = NSBox(frame: NSRect(x: 0, y: 195, width: 520, height: 180))
        box.title = "Placement Mode Details"
        box.titlePosition = .atTop
        box.contentViewMargins = NSSize(width: 14, height: 10)
        
        let descStack = NSStackView(frame: box.contentView!.bounds.insetBy(dx: 12, dy: 8))
        descStack.orientation = .vertical
        descStack.alignment = .leading
        descStack.spacing = 8
        descStack.autoresizingMask = [.width, .height]
        box.contentView?.addSubview(descStack)
        
        // 1. Normal
        let normalText = NSMutableAttributedString(string: "📌 Normal (Behind Apps): ", attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .bold)])
        normalText.append(NSAttributedString(string: "The widget sits quietly behind your active apps (Chrome, Slack, etc.). It never blocks your work, and is accessible across all Desktops/Spaces. (Recommended)", attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]))
        let normalLabel = NSTextField(labelWithAttributedString: normalText)
        normalLabel.lineBreakMode = .byWordWrapping
        descStack.addArrangedSubview(normalLabel)
        
        // 2. Float
        let floatText = NSMutableAttributedString(string: "🔝 Float (Always on Top): ", attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .bold)])
        floatText.append(NSAttributedString(string: "The widget stays pinned above all other windows like a sticky note or picture-in-picture, so you never lose sight of it even when working in other apps.", attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]))
        let floatLabel = NSTextField(labelWithAttributedString: floatText)
        floatLabel.lineBreakMode = .byWordWrapping
        descStack.addArrangedSubview(floatLabel)
        
        // 3. Wall
        let wallText = NSMutableAttributedString(string: "🖼️ Wall (Wallpaper Layer): ", attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .bold)])
        wallText.append(NSAttributedString(string: "Anchored directly into your desktop wallpaper layer. Revealed when you move windows aside or use the macOS 'Show Desktop' gesture.", attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]))
        let wallLabel = NSTextField(labelWithAttributedString: wallText)
        wallLabel.lineBreakMode = .byWordWrapping
        descStack.addArrangedSubview(wallLabel)
        
        // Tip
        let tipText = NSAttributedString(string: "💡 Note: You can switch this here or directly via the button in the top-right corner of the widget.", attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.secondaryLabelColor])
        let tipLabel = NSTextField(labelWithAttributedString: tipText)
        descStack.addArrangedSubview(tipLabel)
        
        appearanceContainerView.addSubview(box)
        
        // Clean View Section
        let cleanTitle = NSTextField(labelWithString: "Database View Optimization:")
        cleanTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        cleanTitle.frame = NSRect(x: 0, y: 155, width: 250, height: 18)
        appearanceContainerView.addSubview(cleanTitle)
        
        cleanModeCheckbox = NSButton(checkboxWithTitle: "✨ Clean Database View (Hides Notion header, covers & side margins)", target: self, action: #selector(cleanModeCheckboxChanged))
        cleanModeCheckbox.frame = NSRect(x: 0, y: 128, width: 510, height: 20)
        appearanceContainerView.addSubview(cleanModeCheckbox)
        
        let cleanDesc = NSTextField(labelWithString: "Removes Notion's default 96px side margins and top navigation bar so your database table expands edge-to-edge across the widget.")
        cleanDesc.font = NSFont.systemFont(ofSize: 11)
        cleanDesc.textColor = .secondaryLabelColor
        cleanDesc.frame = NSRect(x: 20, y: 88, width: 490, height: 36)
        appearanceContainerView.addSubview(cleanDesc)
        
        // Theme section
        let themeTitle = NSTextField(labelWithString: "Color Theme:")
        themeTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        themeTitle.frame = NSRect(x: 0, y: 55, width: 200, height: 18)
        appearanceContainerView.addSubview(themeTitle)
        
        let themeDesc = NSTextField(labelWithString: "☀️ High-contrast Light Mode with a crisp white canvas and dark text.")
        themeDesc.font = NSFont.systemFont(ofSize: 11)
        themeDesc.textColor = .secondaryLabelColor
        themeDesc.frame = NSRect(x: 0, y: 32, width: 480, height: 18)
        appearanceContainerView.addSubview(themeDesc)
    }
    
    // MARK: - Tab 3: Security & Session
    private func setupSecurityTab() {
        let title = NSTextField(labelWithString: "Security & Sandbox Protections")
        title.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        title.frame = NSRect(x: 0, y: 395, width: 400, height: 20)
        securityContainerView.addSubview(title)
        
        let items = [
            ("🛡️ Hardened Runtime Active", "Compiled with Apple's hardened runtime (W^X memory integrity & anti-injection)."),
            ("🔒 Domain Navigation Jail", "Only verified Notion and OAuth domains can load inside the widget."),
            ("🌐 External Links Quarantined", "Any external links clicked in your notes open safely in your default browser."),
            ("🚫 Local File System Blocked", "JavaScript is strictly prohibited from accessing local files (file://)."),
            ("🔐 Strict HTTPS Enforced", "All traffic encrypted via modern TLS with Apple Transport Security.")
        ]
        
        var yPos = 350
        for (head, desc) in items {
            let hLabel = NSTextField(labelWithString: head)
            hLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            hLabel.frame = NSRect(x: 0, y: yPos, width: 350, height: 18)
            securityContainerView.addSubview(hLabel)
            
            let dLabel = NSTextField(labelWithString: desc)
            dLabel.font = NSFont.systemFont(ofSize: 11)
            dLabel.textColor = .secondaryLabelColor
            dLabel.frame = NSRect(x: 20, y: yPos - 20, width: 480, height: 16)
            securityContainerView.addSubview(dLabel)
            
            yPos -= 48
        }
        
        // Clear session button
        let clearBtn = NSButton(title: "🔒 Clear Session Data & Sign Out...", target: self, action: #selector(clearSessionClicked))
        clearBtn.bezelStyle = .rounded
        clearBtn.frame = NSRect(x: 0, y: 30, width: 240, height: 32)
        securityContainerView.addSubview(clearBtn)
    }
    
    // MARK: - Actions
    func showSettings() {
        guard let window = self.window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        updateActiveURLField()
        tableView.reloadData()
        
        if let mode = appDelegate?.currentMode {
            modePopUp.selectItem(at: mode.rawValue)
        }
        
        if let clean = appDelegate?.isCleanMode {
            cleanModeCheckbox.state = clean ? .on : .off
        }
    }
    
    func syncMode(_ mode: WindowDisplayMode) {
        if modePopUp != nil {
            modePopUp.selectItem(at: mode.rawValue)
        }
    }
    
    private func updateActiveURLField() {
        activeURLField.stringValue = appDelegate?.currentURLString ?? ""
    }
    
    @objc private func loadSelectedPage() {
        let row = tableView.selectedRow
        guard row >= 0 && row < savedPages.count else {
            let alert = NSAlert()
            alert.messageText = "Select a Page"
            alert.informativeText = "Please click on a page in the list first, then click Open."
            alert.runModal()
            return
        }
        
        let item = savedPages[row]
        switchPage(to: item.url)
    }
    
    @objc private func removeSelectedPage() {
        let row = tableView.selectedRow
        guard row >= 0 && row < savedPages.count else { return }
        
        if savedPages.count == 1 {
            let alert = NSAlert()
            alert.messageText = "Cannot Delete Last Page"
            alert.informativeText = "You must have at least one page in your saved list."
            alert.runModal()
            return
        }
        
        savedPages.remove(at: row)
        savePagesList()
        tableView.reloadData()
    }
    
    @objc private func pasteFromClipboard() {
        if let clipboardString = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            newURLField.stringValue = clipboardString
        }
    }
    
    @objc private func addNewPage() {
        let name = newNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var url = newURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if name.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Name Required"
            alert.informativeText = "Please enter a title for your Notion page or database."
            alert.runModal()
            return
        }
        
        // Auto-prepend https:// if omitted
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        
        guard let parsedURL = URL(string: url), (url.contains("notion.com") || url.contains("notion.so") || url.contains("notion.site")) else {
            let alert = NSAlert()
            alert.messageText = "Invalid Notion URL"
            alert.informativeText = "Please enter a valid Notion URL (e.g. https://app.notion.com/... or https://notion.so/...)."
            alert.runModal()
            return
        }
        
        let newItem = NotionPageItem(name: name, url: parsedURL.absoluteString)
        savedPages.append(newItem)
        savePagesList()
        tableView.reloadData()
        
        newNameField.stringValue = ""
        newURLField.stringValue = ""
        
        // Immediately switch widget to this newly added page
        switchPage(to: newItem.url)
    }
    
    private func switchPage(to url: String) {
        guard let appDelegate = self.appDelegate else { return }
        appDelegate.currentURLString = url
        UserDefaults.standard.set(url, forKey: kSavedURLKey)
        appDelegate.loadCurrentURL()
        updateActiveURLField()
        
        // Show brief visual confirmation
        let alert = NSAlert()
        alert.messageText = "Page Loaded"
        alert.informativeText = "NotionWidget has loaded your selected database!"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func modePopUpChanged(_ sender: NSPopUpButton) {
        if let mode = WindowDisplayMode(rawValue: sender.indexOfSelectedItem) {
            appDelegate?.applyWindowMode(mode)
        }
    }
    
    @objc private func cleanModeCheckboxChanged(_ sender: NSButton) {
        let isClean = (sender.state == .on)
        appDelegate?.isCleanMode = isClean
        UserDefaults.standard.set(isClean, forKey: kCleanModeKey)
        appDelegate?.applyCleanDatabaseCSS()
    }
    
    @objc private func clearSessionClicked() {
        appDelegate?.clearSessionData()
    }
    
    // MARK: - NSTableView DataSource & Delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        return savedPages.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = savedPages[row]
        let cell = NSTableCellView()
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        
        let titleLabel = NSTextField(labelWithString: "📊 " + item.name)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        
        let urlLabel = NSTextField(labelWithString: item.url)
        urlLabel.font = NSFont.systemFont(ofSize: 11)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingTail
        
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(urlLabel)
        
        stack.frame = NSRect(x: 8, y: 3, width: 490, height: 38)
        cell.addSubview(stack)
        return cell
    }
}
