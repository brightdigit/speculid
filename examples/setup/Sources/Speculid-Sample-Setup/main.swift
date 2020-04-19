//
//  main.swift
//  TestSetup
//
//  Created by Leo Dion on 4/18/20.
//  Copyright © 2020 Bright Digit, LLC. All rights reserved.
//

import Foundation
import ZIPFoundation
import PromiseKit

var shouldKeepRunning = true
let folderContentsJson = """
{
"info" : {
"version" : 1,
"author" : "xcode"
}
}
"""

func createAssetFolder(at url: URL) throws {
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  let fileUrl = url.appendingPathComponent("Contents.json")
  try folderContentsJson.write(to: fileUrl, atomically: true, encoding: .utf8)
}

let appIconJsonData = try! Data(contentsOf: URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("AppIcon.json"))
let imageSetJsonData = try! Data(contentsOf: URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("ImageSet.json"))
let exampleUrl = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let sampleUrl = exampleUrl.appendingPathComponent("sample")

if FileManager.default.fileExists(atPath: sampleUrl.path) {
  try FileManager.default.removeItem(at: sampleUrl)
}

let graphicsUrl = sampleUrl.appendingPathComponent("graphics")
let assetsUrl = sampleUrl.appendingPathComponent("Assets.xcassets")
let speculidUrl = sampleUrl.appendingPathComponent("speculid")

let imageSetsUrl = assetsUrl.appendingPathComponent("Image Sets")
let appIconsUrl = assetsUrl.appendingPathComponent("App Icons")

try! FileManager.default.createDirectory(at: graphicsUrl, withIntermediateDirectories: true)

try! createAssetFolder(at: imageSetsUrl)
try! createAssetFolder(at: appIconsUrl)

try! FileManager.default.createDirectory(at: speculidUrl, withIntermediateDirectories: true)

let url = URL(string: "https://use.fontawesome.com/releases/v5.13.0/fontawesome-free-5.13.0-desktop.zip")!
let relativeSVGPath = "fontawesome-free-5.13.0-desktop/svgs"
let name = "fontawesome"

let enumerator = FileManager.default.enumerator(at: graphicsUrl, includingPropertiesForKeys: nil)?.compactMap{ $0 as? URL}.filter{
  $0.pathExtension == "svg"
}

let promise = firstly {
  Promise<URL>{ (resolver) in
    URLSession.shared.downloadTask(with: url) {
      resolver.resolve($0, $2)
    }.resume()
  }
}.then { (url) in
  return Promise<URL>{ (resolver) in
    let unzipDirUrl = graphicsUrl.appendingPathComponent(name)
    do {
      try FileManager.default.createDirectory(at: unzipDirUrl, withIntermediateDirectories: true)
      try FileManager.default.unzipItem(at: url, to: unzipDirUrl)
    } catch {
      resolver.reject(error)
    }
    resolver.fulfill(unzipDirUrl)
  }
}.map { (dirUrl) throws -> (URL, [URL]) in
  let svgDirectoryUrl = dirUrl.appendingPathComponent(relativeSVGPath)
  guard let enumerator = FileManager.default.enumerator(at: svgDirectoryUrl, includingPropertiesForKeys: nil) else {
    throw NSError()
  }
  return (svgDirectoryUrl, enumerator.compactMap{ $0 as? URL }.filter{
    $0.pathExtension == "svg"
  })
}.then { (svgDirectoryUrl, urls) -> Promise<Void> in
  
  let promises : [Promise<Void>] = urls.map {
    (svgUrl) in
    return Promise<Void>{ (resolver) in
      guard let parentPath = svgUrl.deletingLastPathComponent().relativePath(from: svgDirectoryUrl) else {
        resolver.reject(NSError())
        return
      }
      
      let imageSetSpeculidUrl : URL
      let appIconSpeculidUrl : URL
      let imageSetAssetDirUrl : URL
      let appIconAssetDirUrl : URL
      
      let svgName = svgUrl.deletingPathExtension().lastPathComponent
      
      let speculidDirUrl = speculidUrl.appendingPathComponent(name, isDirectory: true).appendingPathComponent(parentPath, isDirectory: true)
      
      try? FileManager.default.createDirectory(at: speculidDirUrl, withIntermediateDirectories: true)
      
      let imageSetNameAssetDirUrl = imageSetsUrl.appendingPathComponent(name, isDirectory: true)
      
      let appIconNameAssetDirUrl = appIconsUrl.appendingPathComponent(name, isDirectory: true)
      
      try? createAssetFolder(at: imageSetNameAssetDirUrl)
      try? createAssetFolder(at: appIconNameAssetDirUrl)
      let imageSetAssetParentDirUrl = imageSetNameAssetDirUrl.appendingPathComponent(parentPath, isDirectory: true)
      
      try? createAssetFolder(at: imageSetAssetParentDirUrl)
      
      
      let appIconAssetParentDirUrl = appIconNameAssetDirUrl.appendingPathComponent(parentPath, isDirectory: true)
      try? createAssetFolder(at: appIconAssetParentDirUrl)
      
      imageSetSpeculidUrl = speculidDirUrl.appendingPathComponent(svgName).appendingPathExtension("image-set").appendingPathExtension("speculid")
      
      appIconSpeculidUrl = speculidDirUrl.appendingPathComponent(svgName).appendingPathExtension("app-icon").appendingPathExtension("speculid")
      
      imageSetAssetDirUrl = imageSetAssetParentDirUrl.appendingPathComponent(svgName, isDirectory: true)
      appIconAssetDirUrl = appIconAssetParentDirUrl.appendingPathComponent(svgName, isDirectory: true)
      
      let appIconSpecText = """
      {
      "set" : "\(appIconAssetDirUrl.relativePath(from: appIconSpeculidUrl.deletingLastPathComponent())!)",
      "source" : "\(svgUrl.relativePath(from: appIconSpeculidUrl.deletingLastPathComponent())!)",
      "background" : "#FFFFFF",
      "remove-alpha" : true
      }
      """
      
      let imageSetSpecText = """
      {
      "set" : "\(imageSetAssetDirUrl.relativePath(from: imageSetSpeculidUrl.deletingLastPathComponent())!)",
      "source" : "\(svgUrl.relativePath(from: imageSetSpeculidUrl.deletingLastPathComponent())!)"
      }
      """
      
      try appIconSpecText.write(to: appIconSpeculidUrl, atomically: true, encoding: .utf8)
      try imageSetSpecText.write(to: imageSetSpeculidUrl, atomically: true, encoding: .utf8)
      
      try FileManager.default.createDirectory(at: imageSetAssetDirUrl, withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: appIconAssetDirUrl, withIntermediateDirectories: true)
      
      try imageSetJsonData.write(to: imageSetAssetDirUrl.appendingPathComponent("Contents.json"))
      try appIconJsonData.write(to: appIconAssetDirUrl.appendingPathComponent("Contents.json"))
      resolver.fulfill(())
    }
  }
  return when(fulfilled: promises)
}.done({
  shouldKeepRunning = false
}).catch { (error) in
  print(error)
  exit(1)
}


while RunLoop.current.run(mode: .default, before: .distantFuture) && shouldKeepRunning {}
