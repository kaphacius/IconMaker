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
var iconSetURL: URL? = nil

enum IconMakerError: Error {
    case stringError(String)
    case cancelPressed
}

class IconMaker: NSObject {
    var bundle: Bundle
    
    class func pluginDidLoad(_ bundle: Bundle) {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? NSString
        if appName == "Xcode" {
            sharedPlugin = IconMaker(bundle: bundle)
        }
    }
    
    init(bundle: Bundle) {
        self.bundle = bundle
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidFinishLaunchingNotification),
                                               name: NSNotification.Name.NSApplicationDidFinishLaunching,
                                               object: nil)
    }
    
    func appDidFinishLaunchingNotification(n: NSNotification) {
        NSTableView.swizzleStuff()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func doMenuAction() {
        do {
            let originalImage = try self.loadImageAtPath(imagePathURL: try self.getOriginalImagePath())
            guard let isu = iconSetURL else {
                throw IconMakerError.stringError("Error obtaining result icon path")
            }
            let iconJSONPath = getIconJSONPath(iconFolderPath: isu)
            let jsonDict = try getJSONDict(jsonDictPath: iconJSONPath)
            guard let sizesArray = jsonDict["images"] as? NSArray else {
                throw IconMakerError.stringError("Error retrieving icon sizes from icon JSON")
            }
            for singleSize in sizesArray {
                guard let si = singleSize as? NSMutableDictionary,
                    let size = si["size"] as? String,
                    let scale = si["scale"] as? String else {
                        throw IconMakerError.stringError("")
                }
                let resultName = try resizeImage(img: originalImage, stringSize: size, stringScale: scale, savePath: isu)
                si["filename"] = resultName
            }
            try saveResultingIconJSON(jsonDict: jsonDict, savePath: iconJSONPath)
        } catch IconMakerError.stringError(let description) {
            showError(description: description)
        } catch _ {
            
        }
    }
    
    func showError(description: String) {
        let error = NSError(domain: description, code:0, userInfo:nil)
        NSAlert(error: error).runModal()
    }
    
    func getOriginalImagePath() throws -> URL {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["png"]
        openPanel.canChooseFiles = true
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        
        let result = openPanel.runModal()
        guard NSFileHandlingPanelOKButton == result else {
            throw IconMakerError.cancelPressed
        }
        guard let u = openPanel.url else {
            throw IconMakerError.stringError("Error obtaining original image path")
        }
        return u
    }
    
    func loadImageAtPath(imagePathURL: URL) throws -> NSImage {
        guard let i = NSImage(contentsOf: imagePathURL) else {
            throw IconMakerError.stringError("Loading original image failed")
        }
        return i
    }
    
    func getIconJSONPath(iconFolderPath: URL) -> URL {
        return iconFolderPath.appendingPathComponent("Contents.json")
    }
    
    func getJSONDict(jsonDictPath: URL) throws -> NSDictionary {
        guard let data = NSData(contentsOf: jsonDictPath) else {
            throw IconMakerError.stringError("Loading icon JSON failed")
        }
        guard let jsonDict = try? JSONSerialization.jsonObject(with: data as Data, options: [.mutableContainers]) as? NSDictionary else {
            throw IconMakerError.stringError("Parsing icon JSON failed")
        }
        return jsonDict!
    }
    
    func resizeImage(img: NSImage, stringSize: String, stringScale: String, savePath: URL) throws -> String {
        guard let size = Double(stringSize.components(separatedBy: "x").first!),
            let scale = Double(stringScale.components(separatedBy: "x").first!) else {
                throw IconMakerError.stringError("Error retrieving icon size or scale")
        }
        let resultSize = NSSize(width: size * scale, height: size * scale)
        img.size = resultSize
        _ = NSBitmapImageRep(focusedViewRect: NSRect(x: 0.0, y: 0.0, width: img.size.width, height: img.size.height))
        let data = try dataFromImage(image: img, size: Int(size * scale))
        let imgName = "Icon-\(size)@\(stringScale).png"
        try! data.write(to: savePath.appendingPathComponent(imgName), options: [Data.WritingOptions.atomic])
//        else {
//            throw IconMakerError.stringError("Error saving icon")
//        }
        return imgName
    }
    
    func dataFromImage(image: NSImage, size: Int) throws -> Data {
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
            NSGraphicsContext.setCurrent(NSGraphicsContext(bitmapImageRep: representation))
            image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                       from: NSZeroRect,
                       operation: NSCompositingOperation.copy,
                       fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
            guard let imageData = representation.representation(using: NSBitmapImageFileType.PNG, properties: [String : AnyObject]()) else {
                throw IconMakerError.stringError("Error obtaining data for icon image")
            }
            return imageData
        } else {
            throw IconMakerError.stringError("Error obtaining representation for icon image")
        }
    }
    
    func saveResultingIconJSON(jsonDict: NSDictionary, savePath: URL) throws {
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonDict, options: JSONSerialization.WritingOptions.prettyPrinted)
            guard let _ = try? data.write(to: savePath) else {
                throw IconMakerError.stringError("Error saving icon JSON to disk")
            }
        } catch IconMakerError.stringError(description) {
            throw IconMakerError.stringError(description)
        } catch _ {
            throw IconMakerError.stringError("Error creating icon JSON")
        }
    }
}

extension NSTableView {
    
    static func swizzleStuff() {
        let originalSelector = #selector(NSView.menu(for:))
        let swizzledSelector = #selector(im_menuForEvent)
        let originalMethod = class_getInstanceMethod(NSTableView.self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(NSTableView.self, swizzledSelector)
        
        let didAddMethod = class_addMethod(NSTableView.self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(NSTableView.self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
        
        separatorMenuItem = NSMenuItem.separator()
        iconMenuItem = createIconMenuItem()
    }
    
    func im_menuForEvent(event: NSEvent) -> NSMenu {
        let menu = im_menuForEvent(event: event)
        if let si = separatorMenuItem, let ii = iconMenuItem , menu.items.contains(si) && menu.items.contains(ii) {
            menu.removeItem(si)
            menu.removeItem(ii)
        }
        if "IBICSourceListOutlineView" == self.className {
            if let selectedItems = self.perform(Selector(("selectedItems")))?.takeUnretainedValue() as? NSArray,
                let outlineViewItem = selectedItems.firstObject as? NSObject , "IBICOutlineViewItem" == outlineViewItem.className {
                if let catalogItem = outlineViewItem.perform(Selector(("catalogItem"))).takeUnretainedValue() as? NSObject , catalogItem.className == "IBICAppIconSet" {
                    if let url = catalogItem.perform(Selector(("absoluteFileURL"))).takeUnretainedValue() as? URL,
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
        let iconMenuIcon = NSMenuItem(title:"Make An App Icon", action:#selector(IconMaker.doMenuAction), keyEquivalent:"")
        iconMenuIcon.target = sharedPlugin
        return iconMenuIcon
    }
}
