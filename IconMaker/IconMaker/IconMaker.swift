//
//  IconMaker.swift
//
//  Created by Yurii Zadoianchuk on 26/04/15.
//  Copyright (c) 2015 Yurii Zadoianchuk. All rights reserved.
//

import AppKit

var sharedPlugin: IconMaker?

class IconMaker: NSObject {
    var bundle: NSBundle

    class func pluginDidLoad(bundle: NSBundle) {
        let appName = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? NSString
        if appName == "Xcode" {
            sharedPlugin = IconMaker(bundle: bundle)
        }
    }

    init(bundle: NSBundle) {
        self.bundle = bundle
        super.init()
        createMenuItems()
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func createMenuItems() {
        var item = NSApp.mainMenu!!.itemWithTitle("Edit")
        if item != nil {
            var actionMenuItem = NSMenuItem(title:"Make an app icon", action:"doMenuAction", keyEquivalent:"")
            actionMenuItem.target = self
            item!.submenu!.addItem(NSMenuItem.separatorItem())
            item!.submenu!.addItem(actionMenuItem)
        }
    }

    func doMenuAction() {
        if let oiu = getOriginalImageUrl() {
            
        }
    }
    
    func getOriginalImageUrl() -> NSURL? {
        var openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["png"]
        openPanel.canChooseFiles = true
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        
        var fileURL: NSURL? = nil
        var result = openPanel.runModal()
        if (NSFileHandlingPanelOKButton == result) {
            fileURL = openPanel.URL
        }
        return fileURL
    }
    func getWorkspacePath() -> NSString? {
        var workspacePath: NSString? = nil
        var workspaceWindowControllers: AnyObject = NSClassFromString("IDEWorkspaceWindowController")
        var controllers = workspaceWindowControllers.valueForKey("workspaceWindowControllers") as? NSArray
        var workspace: AnyObject? = nil
        if let c = controllers {
            for controller in c {
                var window: AnyObject? = controller.valueForKey("window")
                var keyWindow = NSApp.keyWindow
                if let w: AnyObject = window, let kw: AnyObject = keyWindow as? AnyObject {
                    if true == w.isEqual(kw) {
                        workspace = controller.valueForKey("_workspace")
                        break
                    }
                }
            }
            workspacePath = workspace?.valueForKey("representingFilePath")?.valueForKey("_pathString") as? NSString
        }
        return workspacePath
    }
}

