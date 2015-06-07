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
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.createMenuItems()
        })
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func createMenuItems() {
        var menu = NSApp.mainMenu
        var item = NSApp.mainMenu!!.itemWithTitle("Edit")
        if let i = item {
            var actionMenuItem = NSMenuItem(title:"Make an app icon", action:"doMenuAction", keyEquivalent:"")
            actionMenuItem.target = self
            i.submenu!.addItem(NSMenuItem.separatorItem())
            i.submenu!.addItem(actionMenuItem)
        }
    }

    func doMenuAction() {
        if let originalImagePath = getOriginalImagePath(),
            let originalImage = loadImageAtPath(originalImagePath),
            let workspacePath = getWorkspacePath(),
            let iconFolderPath = getIconFolderPath(workspacePath),
            let iconJSONPath = getIconJSONPath(iconFolderPath),
            let jsonDict = getJSONDict(iconJSONPath),
            let imagesArray = jsonDict["images"] as? NSArray
        {
            for singleImage in imagesArray {
                if let si = singleImage as? NSMutableDictionary,
                    let size = si["size"] as? String,
                    let scale = si["scale"] as? String,
                    let resultName = resizeImage(img: originalImage, stringSize: size, stringScale: scale, savePath: iconFolderPath) {
                        si["filename"] = resultName
                }
            }
            saveResultingIconJSON(jsonDict, savePath: iconJSONPath)
        } else {
            showError()
        }
    }
    
    func showError() {
        let error = NSError(domain: "Something went wrong :(", code:0, userInfo:nil)
        NSAlert(error: error).runModal()
    }
    
    func getOriginalImagePath() -> NSURL? {
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
    
    func loadImageAtPath(imagePathURL: NSURL) -> NSImage? {
        return NSImage(contentsOfURL: imagePathURL)
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
    
    func getIconJSONPath(iconFolderPath: NSString) -> NSString? {
        return iconFolderPath.stringByAppendingPathComponent("Contents.json")
    }
    
    func getIconFolderPath(workspacePath: NSString) -> NSString? {
        var homeFolderPath = workspacePath.stringByDeletingLastPathComponent
        var iconFolderPath: NSString? = nil
        if let list = NSFileManager.defaultManager().subpathsOfDirectoryAtPath(homeFolderPath as String, error: nil) as? [NSString] {
            for item in list {
                println("item: \(item)")
                if item.stringByDeletingPathExtension.lastPathComponent == "AppDelegate" {
                    iconFolderPath = homeFolderPath.stringByAppendingPathComponent(item.stringByDeletingLastPathComponent).stringByAppendingPathComponent("Images.xcassets").stringByAppendingPathComponent("AppIcon.appiconset")
                    break
                }
            }
        }
        return iconFolderPath
    }
    
    func getJSONDict(jsonDictPath: NSString) -> NSDictionary? {
        var jsonDict: NSDictionary? = nil
        if let data = NSData(contentsOfFile: jsonDictPath as String) {
            jsonDict = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: nil) as? NSDictionary
        }
        return jsonDict
    }
    
    func resizeImage(#img: NSImage, stringSize: NSString, stringScale: NSString, savePath: NSString) -> NSString? {
        var size: Double? = stringSize.componentsSeparatedByString("x").first?.doubleValue
        var scale: Double? = stringScale.componentsSeparatedByString("x").first?.doubleValue
        var imgName: String? = nil
        if let sz = size, let sc = scale {
            var resultSize = NSSize(width: sz * sc, height: sz * sc)
            img.size = resultSize
            var bitmapRep = NSBitmapImageRep(focusedViewRect: NSRect(x: 0.0, y: 0.0, width: img.size.width, height: img.size.height))
            var data = dataFromImage(img, size: Int(sz * sc))
            imgName = "Icon-\(sz)@\(stringScale).png"
            if let d = data, imn = imgName {
                var success = d.writeToFile(savePath.stringByAppendingPathComponent(imn) as String, atomically: true)
                if false == success {
                    imgName = nil
                }
            }
        }
        return imgName
    }
    
    func dataFromImage(image: NSImage, size: Int) -> NSData? {
        var imageData: NSData? = nil
        var representation = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSCalibratedRGBColorSpace,
            bytesPerRow: 0,
            bitsPerPixel: 0)
        if let r = representation {
            r.size = NSSize(width: size, height: size)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.setCurrentContext(NSGraphicsContext(bitmapImageRep: r))
            image.drawInRect(NSRect(x: 0, y: 0, width: size, height: size),
                fromRect: NSZeroRect,
                operation: NSCompositingOperation.CompositeCopy,
                fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
            imageData = r.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [NSObject: AnyObject]())
        }
        return imageData
    }
    
    func saveResultingIconJSON(jsonDict: NSDictionary, savePath: NSString) {
        NSJSONSerialization.dataWithJSONObject(jsonDict, options: NSJSONWritingOptions.PrettyPrinted, error: nil)?.writeToFile(savePath as String, options: NSDataWritingOptions.AtomicWrite, error: nil)
    }
}

