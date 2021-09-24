//
//  iVariantApp.swift
//  iVariant
//
//  Created by Lakr Aream on 2021/9/24.
//

import SwiftUI

@main
struct iVariantApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, maxWidth: 5000, minHeight: 400, maxHeight: 5000)
                .toolbar {
                    ToolbarItem {
                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "https://github.com/Co2333/iVariant")!)
                        }, label: {
                            Image(systemName: "questionmark.circle.fill")
                        })
                    }
                }
        }
    }
}
