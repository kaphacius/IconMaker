//
//  IconMaker.swift
//
//  Created by Yurii Zadoianchuk on 26/04/15.
//  Copyright (c) 2015 Yurii Zadoianchuk. All rights reserved.
//

import AppKit

var sharedPlugin: IconMaker?

enum Error : ErrorType {
    case IconMakerError(String)
}

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
        dispatch_async(dispatch_get_main_queue(), {
            () -> Void in
            self.createMenuItems()
        })
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func createMenuItems() {
        let item = NSApp.mainMenu!.itemWithTitle("Edit")
        if let i = item {
            let actionMenuItem = NSMenuItem(title: "Make an app icon", action: "doMenuActionSecure", keyEquivalent: "")
            actionMenuItem.target = self
            i.submenu!.addItem(NSMenuItem.separatorItem())
            i.submenu!.addItem(actionMenuItem)
        }
    }

    func doMenuActionSecure() {
        do {
            try doMenuAction()
        } catch let Error.IconMakerError(x) {
                self.showError(x);
        } catch {
            showError()
        }
    }

    func doMenuAction() throws {
        let originalImagePath = try getOriginalImagePath();
        let originalImage = try loadImageAtPath(originalImagePath);
        
        let workspacePath = try getWorkspacePath()
        let iconFolderPath = try getIconFolderPath(workspacePath)
        let iconJSONPath = getIconJSONPath(iconFolderPath);
        let jsonDict = try getJSONDict(iconJSONPath)
        
        if let imagesArray = jsonDict["images"] as? NSArray {
            for singleImage in imagesArray {
                if let si = singleImage as? NSMutableDictionary,
                let size = si["size"] as? String,
                let scale = si["scale"] as? String,
                let resultName = self.resizeImage(img: originalImage, stringSize: size, stringScale: scale, savePath: iconFolderPath) {
                    si["filename"] = resultName
                }
            }
            self.saveResultingIconJSON(jsonDict, savePath: iconJSONPath)
        } else {
            throw Error.IconMakerError("Cannot ge images array from jsonDict : \(jsonDict)")
        }
     }

    func showError(message: String? = nil) {
        var error = NSError(domain: "Something went wrong :(", code: 0, userInfo: nil);
        if let message = message {
            error = NSError(domain: "Something went wrong :(", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: message
            ])
        }
        NSAlert(error: error).runModal()
    }

    func getOriginalImagePath()  throws -> NSURL {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["png"]
        openPanel.canChooseFiles = true
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false

        var fileURL: NSURL? = nil
        let result = openPanel.runModal()
        if (NSFileHandlingPanelOKButton == result) {
            fileURL = openPanel.URL
        }
        
        guard let afileURL = fileURL else {
            throw Error.IconMakerError("Original image cannot be found");
        }
        return afileURL
    }

    func loadImageAtPath(imagePathURL: NSURL) throws -> NSImage {
        let image = NSImage(contentsOfURL: imagePathURL)
        guard let aimage = image else {
            throw Error.IconMakerError("Image cannot be loaded at Path \(imagePathURL)")
        }
        return aimage
    }

    func getWorkspacePath() throws -> String {
        var workspacePath: NSString? = nil
        let workspaceWindowControllers: AnyObject = NSClassFromString("IDEWorkspaceWindowController")!
        let controllers = workspaceWindowControllers.valueForKey("workspaceWindowControllers") as? NSArray
        var workspace: AnyObject? = nil
        if let c = controllers {
            for controller in c {
                let window: AnyObject? = controller.valueForKey("window")
                let keyWindow = NSApp.keyWindow
                if let w: AnyObject = window, let kw: AnyObject = keyWindow as? AnyObject {
                    if true == w.isEqual(kw) {
                        workspace = controller.valueForKey("_workspace")
                        break
                    }
                }
            }
            workspacePath = workspace?.valueForKey("representingFilePath")?.valueForKey("_pathString") as? NSString
        }
        guard let aworkspacePath = workspacePath else {
            throw Error.IconMakerError("Workspace URL cannot be found");
        }
        return aworkspacePath as String
    }

    func getIconJSONPath(iconFolderPath: String) -> String {
        return iconFolderPath.stringByAppendingPathComponent("Contents.json");
    }

    func getIconFolderPath(workspacePath: NSString) throws -> String {
        let homeFolderPath = workspacePath.stringByDeletingLastPathComponent
        var iconFolderPath: NSString? = nil
        let list = try NSFileManager.defaultManager().subpathsOfDirectoryAtPath(homeFolderPath)
        for item in list {
            if item.lastPathComponent == "Images.xcassets" {
                iconFolderPath = homeFolderPath.stringByAppendingPathComponent(item).stringByAppendingPathComponent("AppIcon.appiconset");
//                    iconFolderPath = homeFolderPath.stringByAppendingPathComponent(item.stringByDeletingLastPathComponent).stringByAppendingPathComponent("Images.xcassets").
                break
            }
        }


        guard let aiconFolderPath = iconFolderPath else {
            throw Error.IconMakerError("Cannot get icon folder path for specified workspace path \(workspacePath)")
        }
        return aiconFolderPath as String
    }

    func getJSONDict(jsonDictPath: NSString) throws -> NSDictionary {
        var jsonDict: NSDictionary? = nil
        if let data = NSData(contentsOfFile: jsonDictPath as String) {
            try jsonDict = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? NSDictionary
        }
        
        guard let ajsonDict = jsonDict else {
            throw Error.IconMakerError("Cannot get valid JSON at path \(jsonDictPath)")
        }
        return ajsonDict
    }

    func resizeImage(img img: NSImage, stringSize: String, stringScale: String, savePath: String) -> String? {
        let size: Int32? = NSString(string: stringSize.componentsSeparatedByString("x").first!).intValue
        let scale: Int32? = NSString(string: stringScale.componentsSeparatedByString("x").first!).intValue
        var imgName: String? = nil
        if let sz = size, let sc = scale {
            let resultSize = NSSize(width: Double(sz * sc), height: Double(sz * sc))
            img.size = resultSize
            let data = dataFromImage(img, size: Int(sz * sc))
            imgName = "Icon-\(sz)@\(stringScale).png"
            if let d = data, imn = imgName {
                let success = d.writeToFile(savePath.stringByAppendingPathComponent(imn) as String, atomically: true)
                if false == success {
                    imgName = nil
                }
            }
        }
        return imgName
    }

    func dataFromImage(image: NSImage, size: Int) -> NSData? {
        var imageData: NSData? = nil
        let representation = NSBitmapImageRep(bitmapDataPlanes: nil,
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
            imageData = r.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [:])
        }
        return imageData
    }

    func saveResultingIconJSON(jsonDict: NSDictionary, savePath: NSString) {
        do {
            try NSJSONSerialization.dataWithJSONObject(jsonDict, options: NSJSONWritingOptions.PrettyPrinted).writeToFile(savePath as String, options: NSDataWritingOptions.AtomicWrite)
        } catch _ {
        }
    }
}

