import Combine
import SpeculidKit
import SwiftUI
extension URL {
  func relativePath(from base: URL) -> String? {
    // Ensure that both URLs represent files:
    guard isFileURL, base.isFileURL else {
      return nil
    }

    // Remove/replace "." and "..", make paths absolute:
    let destComponents = standardized.pathComponents
    let baseComponents = base.standardized.pathComponents

    // Find number of common path components:
    var index = 0
    while index < destComponents.count,
      index < baseComponents.count,
      destComponents[index] == baseComponents[index]
    {
      index += 1
    }

    // Build relative path:
    var relComponents = Array(repeating: "..", count: baseComponents.count - index)
    relComponents.append(contentsOf: destComponents[index...])
    return relComponents.joined(separator: "/")
  }
}

struct ClassicView: View {
  @StateObject var object: ClassicObject
  @EnvironmentObject var bookmarkCollection: BookmarkURLCollectionObject
  @State private var isACImporting: Bool = false
  @State private var isSourceImporting: Bool = false
  @State private var isExporting: Bool = false

  init(url: URL?, document: ClassicDocument, documentBinding _: Binding<ClassicDocument>) {
    _object = StateObject(wrappedValue: ClassicObject(url: url, document: document))
  }

  var canBuild: Bool {
    return object.url != nil &&

      bookmarkCollection.isAvailable(basedOn: object.url, relativePath: object.document.assetDirectoryRelativePath) &&

      bookmarkCollection.isAvailable(basedOn: object.url, relativePath: object.document.sourceImageRelativePath)
  }

  var body: some View {
    Form {
      Section(header: Text("Source Graphic")) {
        HStack {
          Spacer()
          Text("File Path:").frame(width: 75, alignment: .trailing)
          TextField("SVG of PNG File", text: self.$object.sourceImageRelativePath)
            .overlay(Image(systemName: "folder.fill").foregroundColor(.primary).padding(.trailing, 4.0), alignment: .trailing)
            .disabled(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/).frame(width: 250)
            .fileImporter(isPresented: self.$isSourceImporting, allowedContentTypes: [.svg, .png]) { result in

              guard case let .success(url) = result, let baseURL = self.object.url?.deletingLastPathComponent() else {
                return
              }
              guard let relativePath = url.relativePath(from: baseURL) else {
                return
              }
              bookmarkCollection.saveBookmark(url)
              self.object.sourceImageRelativePath = relativePath
            }.onTapGesture {
              self.isSourceImporting = true
            }
          Image(
            systemName: "lock.fill")
            .foregroundColor(.yellow)
            .opacity(self.bookmarkCollection
              .isAvailable(
                basedOn: self.object.url,
                relativePath: self.object.sourceImageRelativePath
              ) ? 0.0 : 1.0)
          Spacer()
        }
      }
      Divider()
      Section(header: Text("Asset Catalog")) {
        HStack {
          Spacer()
          Text("Folder:").frame(width: 75, alignment: .trailing)
          TextField(".appiconset or .imageset", text: self.$object.assetDirectoryRelativePath)
            .overlay(Image(systemName: "folder.fill").foregroundColor(.primary).padding(.trailing, 4.0), alignment: .trailing)
            .disabled(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/).frame(width: 250)
            .fileImporter(isPresented: self.$isACImporting, allowedContentTypes: [.directory]) { result in
              guard case let .success(url) = result, let baseURL = self.object.url?.deletingLastPathComponent() else {
                return
              }
              guard let relativePath = url.relativePath(from: baseURL) else {
                return
              }
              bookmarkCollection.saveBookmark(url)
              // self.object.document.document.assetDirectoryRelativePath = url.path
              self.object.assetDirectoryRelativePath = relativePath

            }.onTapGesture {
              self.isACImporting = true
            }
          Image(
            systemName: "lock.fill")
            .foregroundColor(.yellow)
            .opacity(self.bookmarkCollection
              .isAvailable(
                basedOn: self.object.url,
                relativePath: self.object.assetDirectoryRelativePath
              ) ? 0.0 : 1.0)
          Spacer()
        }
      }
      Divider()
      Section(header: Text("App Icon Modifications")) {
        HStack {
          VStack(alignment: .leading) {
            Toggle("Remove Alpha Channel", isOn: self.$object.removeAlpha)
            // swiftlint:disable:next line_length
            Text("If this is intended for an iOS, watchOS, or tvOS App, then you should remove the alpha channel from the source graphic.").multilineTextAlignment(.leading).font(.subheadline).lineLimit(nil)
          }
          Spacer()
        }
        VStack(alignment: .leading) {
          HStack {
            Toggle("Add a Background Color", isOn: self.$object.addBackground)
            ColorPicker("", selection: self.$object.backgroundColor, supportsOpacity: false)
              .labelsHidden()
              .frame(width: 40, height: 25, alignment: .trailing)
              .disabled(!self.object.addBackground)
              .opacity(self.object.addBackground ? 1.0 : 0.5)
          }

          Text("If this is intended for an iOS, watchOS, or tvOS App, then you should set a background color.")
            .multilineTextAlignment(.leading)
            .font(.subheadline)
            .lineLimit(nil)
        }
      }.disabled(!self.object.isAppIcon).opacity(self.object.isAppIcon ? 1.0 : 0.5)
      Divider()
      Section(header: Text("Resizing Geometry")) {
        HStack {
          Picker("Resize", selection: self.$object.resizeOption) {
            ForEach(ResizeOption.all) {
              Text($0.label).tag($0.rawValue)
            }
          }.pickerStyle(SegmentedPickerStyle())
            .frame(width: 150, alignment: .leading).labelsHidden()
          TextField("Value", value: self.$object.geometryValue, formatter: NumberFormatter())
            .frame(width: 50, alignment: .leading)
            .disabled(self.object.resizeOption == 0)
            .opacity(self.object.resizeOption == 0 ? 0.5 : 1.0)
          Text("px").opacity(self.object.resizeOption == 0 ? 0.5 : 1.0)
        }

        // swiftlint:disable:next line_length
        Text("If you wish to render scaled PNG files for an image set, then specify either width or height and the image will be resized to that dimention while retaining its aspect ratio.\nOtherwise if you select \"None\", then only a PDF will be rendered.   ")
          .multilineTextAlignment(.leading)
          .font(.subheadline)
          .lineLimit(nil)
      }.disabled(!self.object.isImageSet).opacity(self.object.isImageSet ? 1.0 : 0.5)
      Divider()
      Section {
        HStack {
          Button {
            if let url = self.object.url {
              self.object.document.build(fromURL: url, inSandbox: self.bookmarkCollection)
            }
          } label: {
            HStack {
              Image(systemName: "play.fill")
              Text("Build")
            }
          }.disabled(!canBuild)
        }
      }
    }
    .padding(.all, 40.0)
    .frame(minWidth: 500, idealWidth: 500, maxWidth: 600, minHeight: 500, idealHeight: 500, maxHeight: .infinity, alignment: .center)

    .fileExporter(
      isPresented: $isExporting,
      document: self.object.document,
      contentType: .speculidImageDocument,
      defaultFilename: self.object.url?.lastPathComponent ?? ""
    ) { result in
      guard case let .success(url) = result else {
        return
      }
      self.object.url = url
    }.onAppear {
      self.isExporting = self.object.url == nil
    }
  }
}

struct ClassicView_Previews: PreviewProvider {
  static var previews: some View {
    ClassicView(url: nil, document: ClassicDocument(), documentBinding: .constant(ClassicDocument())).environmentObject(BookmarkURLCollectionObject())
  }
}
