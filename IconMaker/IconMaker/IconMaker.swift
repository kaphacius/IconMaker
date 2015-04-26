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
        //do stuff
    }
}

