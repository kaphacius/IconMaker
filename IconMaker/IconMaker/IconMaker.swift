//
//  IconMaker.swift
//
//  Created by Yurii Zadoianchuk on 26/04/15.
//  Copyright (c) 2015 Yurii Zadoianchuk. All rights reserved.
//

import AppKit

var sharedPlugin: IconMaker? = nil
var separatorMenuItem: NSMenuItem? = nil
var iconMenuItem: NSMenuItem? = nil
var iconSetURL: NSURL? = nil

enum Error: ErrorType {
    case StringError(String)
    case CancelPressed
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
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "appDidFinishLaunchingNotification:",
            name: NSApplicationDidFinishLaunchingNotification,
            object: nil)
    }
    
    func appDidFinishLaunchingNotification(n: NSNotification) {
        NSTableView.swizzleStuff()
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func doMenuAction() {
        do {
            let originalImage = try self.loadImageAtPath(try self.getOriginalImagePath())
            guard let isu = iconSetURL else {
                throw Error.StringError("Error obtaining result icon path")
            }
            let iconJSONPath = getIconJSONPath(isu)
            let jsonDict = try getJSONDict(iconJSONPath)
            guard let sizesArray = jsonDict["images"] as? NSArray else {
                throw Error.StringError("Error retrieving icon sizes from icon JSON")
            }
            for singleSize in sizesArray {
                guard let si = singleSize as? NSMutableDictionary,
                    let size = si["size"] as? String,
                    let scale = si["scale"] as? String else {
                        throw Error.StringError("")
                }
                let resultName = try resizeImage(originalImage, stringSize: size, stringScale: scale, savePath: isu)
                si["filename"] = resultName
            }
            try saveResultingIconJSON(jsonDict, savePath: iconJSONPath)
        } catch Error.StringError(let description) {
            showError(description)
        } catch _ {
            
        }
    }
    
    func showError(description: String) {
        let error = NSError(domain: description, code:0, userInfo:nil)
        NSAlert(error: error).runModal()
    }
    
    func getOriginalImagePath() throws -> NSURL {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["png"]
        openPanel.canChooseFiles = true
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        
        let result = openPanel.runModal()
        guard NSFileHandlingPanelOKButton == result else {
            throw Error.CancelPressed
        }
        guard let u = openPanel.URL else {
            throw Error.StringError("Error obtaining original image path")
        }
        return u
    }
    
    func loadImageAtPath(imagePathURL: NSURL) throws -> NSImage {
        guard let i = NSImage(contentsOfURL: imagePathURL) else {
            throw Error.StringError("Loading original image failed")
        }
        return i
    }
    
    func getIconJSONPath(iconFolderPath: NSURL) -> NSURL {
        return iconFolderPath.URLByAppendingPathComponent("Contents.json")
    }
    
    func getJSONDict(jsonDictPath: NSURL) throws -> NSDictionary {
        guard let data = NSData(contentsOfURL: jsonDictPath) else {
            throw Error.StringError("Loading icon JSON failed")
        }
        guard let jsonDict = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? NSDictionary else {
            throw Error.StringError("Parsing icon JSON failed")
        }
        return jsonDict!
    }
    
    func resizeImage(img: NSImage, stringSize: String, stringScale: String, savePath: NSURL) throws -> String {
        guard let size = Double(stringSize.componentsSeparatedByString("x").first!),
            let scale = Double(stringScale.componentsSeparatedByString("x").first!) else {
                throw Error.StringError("Error retrieving icon size or scale")
        }
        let resultSize = NSSize(width: size * scale, height: size * scale)
        img.size = resultSize
        _ = NSBitmapImageRep(focusedViewRect: NSRect(x: 0.0, y: 0.0, width: img.size.width, height: img.size.height))
        let data = try dataFromImage(img, size: Int(size * scale))
        let imgName = "Icon-\(size)@\(stringScale).png"
        guard data.writeToURL(savePath.URLByAppendingPathComponent(imgName), atomically: true) else {
            throw Error.StringError("Error saving icon")
        }
        return imgName
    }
    
    func dataFromImage(image: NSImage, size: Int) throws -> NSData {
        if let representation = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSCalibratedRGBColorSpace,
            bytesPerRow: 0,
            bitsPerPixel: 0) {
                representation.size = NSSize(width: size, height: size)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.setCurrentContext(NSGraphicsContext(bitmapImageRep: representation))
                image.drawInRect(NSRect(x: 0, y: 0, width: size, height: size),
                    fromRect: NSZeroRect,
                    operation: NSCompositingOperation.CompositeCopy,
                    fraction: 1.0)
                NSGraphicsContext.restoreGraphicsState()
                guard let imageData = representation.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [String : AnyObject]()) else {
                    throw Error.StringError("Error obtaining data for icon image")
                }
                return imageData
        } else {
            throw Error.StringError("Error obtaining representation for icon image")
        }
    }
    
    func saveResultingIconJSON(jsonDict: NSDictionary, savePath: NSURL) throws {
        do {
            let data = try NSJSONSerialization.dataWithJSONObject(jsonDict, options: NSJSONWritingOptions.PrettyPrinted)
            guard data.writeToURL(savePath, atomically: true) else {
                throw Error.StringError("Error saving icon JSON to disk")
            }
        } catch Error.StringError(description) {
            throw Error.StringError(description)
        } catch _ {
            throw Error.StringError("Error creating icon JSON")
        }
    }
}

extension NSTableView {
    
    static func swizzleStuff() {
        let originalSelector = Selector("menuForEvent:")
        let swizzledSelector = Selector("im_menuForEvent:")
        
        let originalMethod = class_getInstanceMethod(NSTableView.self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(NSTableView.self, swizzledSelector)
        
        let didAddMethod = class_addMethod(NSTableView.self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(NSTableView.self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
        
        separatorMenuItem = NSMenuItem.separatorItem()
        iconMenuItem = createIconMenuItem()
    }
    
    func im_menuForEvent(event: NSEvent) -> NSMenu {
        let menu = im_menuForEvent(event)
        if let si = separatorMenuItem, ii = iconMenuItem where menu.itemArray.contains(si) && menu.itemArray.contains(ii) {
            menu.removeItem(si)
            menu.removeItem(ii)
        }
        if "IBICSourceListOutlineView" == self.className {
            if let selectedItems = self.performSelector("selectedItems")?.takeUnretainedValue() as? NSArray,
                let outlineViewItem = selectedItems.firstObject as? NSObject where "IBICOutlineViewItem" == outlineViewItem.className {
                    if let catalogItem = outlineViewItem.performSelector("catalogItem").takeUnretainedValue() as? NSObject where catalogItem.className == "IBICAppIconSet" {
                        if let url = catalogItem.performSelector("absoluteFileURL").takeUnretainedValue() as? NSURL,
                            let smi = separatorMenuItem,
                            let imi = iconMenuItem {
                                iconSetURL = url
                                menu.addItem(smi)
                                menu.addItem(imi)
                        }
                    }
            }
        }
        return menu
    }
    
    static func createIconMenuItem() -> NSMenuItem {
        let iconMenuIcon = NSMenuItem(title:"Make An App Icon", action:"doMenuAction", keyEquivalent:"")
        iconMenuIcon.target = sharedPlugin
        return iconMenuIcon
    }
}