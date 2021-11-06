//
//  ContentView.swift
//  iVariant
//
//  Created by Lakr Aream on 2021/9/24.
//

import SwiftUI

struct ContentView: View {
    @State var loading = true
    @State var xcodes = [Bundle]()
    @State var highlight: Int?
    @State var reportOverlay: BundleReport?
    @State var dragOver = false
    
    var body: some View {
        GeometryReader { reader in
            Group {
                if loading {
                    ZStack { ProgressView() }
                    .frame(width: reader.size.width, height: reader.size.height)
                } else {
                    ScrollView {
                        VStack {
                            Text("Drag and drop your Xcode if not found.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Divider()
                            ForEach(0 ..< xcodes.count, id: \.self) { idx in
                                HStack {
                                    obtainXcodeAvatar(for: xcodes[idx])
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(xcodes[idx].bundleURL.lastPathComponent)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        Text(xcodes[idx].bundlePath)
                                            .font(.system(size: 10, weight: .light, design: .monospaced))
                                    }
                                    Spacer()
                                    Button {
                                        let report = createReport(with: xcodes[idx])
                                        reportOverlay = report
                                    } label: {
                                        Image(systemName: "arrow.right.circle.fill")
                                    }
                                }
                                .padding(4)
                                .onHover { hovering in
                                    if hovering {
                                        highlight = idx
                                    } else {
                                        highlight = nil
                                    }
                                }
                                .background(
                                    Color
                                        .yellow
                                        .opacity(highlight == idx ? 0.2 : 0)
                                        .cornerRadius(8)
                                        .onTapGesture(count: 2) {
                                            let report = createReport(with: xcodes[idx])
                                            reportOverlay = report
                                        }
                                )
                                .animation(.interactiveSpring(), value: highlight)
                            }
                            if xcodes.count == 0 {
                                Image(systemName: "questionmark.folder.fill")
                                    .font(.system(size: 50, weight: .semibold, design: .rounded))
                                    .padding()
                                    .opacity(0.1)
                            }
                        }
                        .padding()
                    }
                }
            }
            .overlay(
                ReportViewer(bundleReport: $reportOverlay)
                    .frame(width: reader.size.width, height: reader.size.height)
                    .offset(x: 0, y: reportOverlay == nil ? reader.size.height + 50 : 0)
                    .animation(.interactiveSpring(), value: reportOverlay)
            )
        }
        .onAppear {
            searchXcodes()
        }
        .onDrop(of: ["public.file-url"], isTargeted: $dragOver) { providers in
            providers
                .first?
                .loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { data, _ in
                    if let data = data,
                       let path = NSString(data: data, encoding: 4),
                       let url = URL(string: path as String),
                       let bundle = Bundle(url: url) {
                        debugPrint("accepting url from \(url.path)")
                        reportOverlay = createReport(with: bundle)
                    }
                })
            return true
        }
    }
    
    func searchXcodes() {
        let applications = URL(fileURLWithPath: "/Applications")
        xcodes = (
            try? FileManager
                .default
                .contentsOfDirectory(atPath: applications.path)
        )?
            .map { applications.appendingPathComponent($0) }
            .compactMap { $0 }
            .map { value -> Bundle? in
                guard let bundle = Bundle(url: value),
                      let identifier = bundle.bundleIdentifier,
                      identifier == "com.apple.dt.Xcode"
                else {
                    return nil
                }
                return bundle
            }
            .compactMap { $0 }
        ?? []
        loading = false
    }
    
    func obtainXcodeAvatar(for bundle: Bundle) -> Image {
        let icon = NSWorkspace
            .shared
            .icon(forFile: bundle.bundlePath)
        return Image(nsImage: icon)
    }
}

struct ReportViewer: View {
    @Binding var bundleReport: BundleReport?
    @State var filter: String = ""
    @State var displayingReport: BundleReport?
    @State var hightlightWhenCopy: Bool = false
    @State var deviceCount = 0
    
    func createFilletedReport() {
        debugPrint("creating display report with search input [\(filter)]")
        guard filter.count > 0 else {
            displayingReport = bundleReport
            return
        }
        var resultReport = BundleReport()
        for platform in bundleReport ?? [] {
            if let report = platform.filtering(with: filter) {
                resultReport.append(report)
            }
        }
        if resultReport.count > 0 {
            displayingReport = resultReport
        } else {
            displayingReport = nil
        }
    }
    
    func copyReportToPasteboard(_ report: String) {
        hightlightWhenCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                hightlightWhenCopy = false
            }
        }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(report, forType: .string)
    }
    
    var body: some View {
        GeometryReader { _ in
            if displayingReport == nil || displayingReport?.count == 0 {
                ZStack {
                    Text("Failed to create report or no value for search result.")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding()
                }
            } else {
                ScrollView {
                    VStack {
                        Divider().opacity(0)
                        ForEach(0 ..< displayingReport!.count, id: \.self) { platformIndex in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayingReport![platformIndex].platform)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .textSelection(.enabled)
                                Divider()
                                ForEach([String](displayingReport![platformIndex].variants.keys.sorted()), id: \.self) { variantKey in
                                    Text(variantKey)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .textSelection(.enabled)
                                    
                                    Text(displayingReport![platformIndex].variants[variantKey]!.humanReadableReport)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    
                    .background(
                        Color.orange
                            .opacity(hightlightWhenCopy ? 0.2 : 0)
                    )
                    .padding(.bottom, 20)
                    .padding()
                    .onAppear {
                        for item in displayingReport ?? [] {
                            for _ in item.variants.keys.sorted() {
                                deviceCount += 1
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: bundleReport) { _ in
            createFilletedReport()
        }
        .onChange(of: filter) { _ in
            createFilletedReport()
        }
        .overlay(
            VStack(alignment: .trailing, spacing: 0) { Spacer()
                HStack { Spacer()
                    TextField("Search Devices", text: $filter)
                        .frame(width: 200)
                    Button {
                        var text = ""
                        for item in displayingReport ?? [] {
                            for key in item.variants.keys.sorted() {
                                guard let record = item.variants[key] else {
                                    continue
                                }
                                text += "[\(record.ProductDescription)]\n"
                                text += record.exportEditFriendly
                                text += "\n\n"
                            }
                        }
                        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if text.count > 0 {
                            copyReportToPasteboard(text)
                        }
                    } label: {
                        Image(systemName: "doc.on.doc.fill")
                    }
                    Button {
                        do {
                            let jsonEncoder = JSONEncoder()
                            jsonEncoder.outputFormatting = .prettyPrinted
                            let jsonData = try jsonEncoder.encode(displayingReport)
                            if let jsonSting = String(data: jsonData, encoding: .utf8) {
                                copyReportToPasteboard(jsonSting)
                            }
                        } catch {
                            debugPrint(error.localizedDescription)
                        }
                    } label: {
                        Image(systemName: "curlybraces")
                    }
                    Button {
                        bundleReport = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
                Text("\(deviceCount) Devices")
                    .foregroundColor(.secondary).opacity(0.5)
            }
                .padding(.trailing, 20)
                .padding(.bottom, 2)
        )
        .background(Color(NSColor.textBackgroundColor))
        .animation(.interactiveSpring(), value: displayingReport)
    }
}
