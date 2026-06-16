//
//  JarvisApp.swift
//  Jarvis
//
//  Created by Junjun Yin on 6/14/26.
//

import SwiftUI

@main
struct JarvisApp: App {
    @StateObject private var controller = DictationController()

    var body: some Scene {
        WindowGroup {
            ContentView(controller: controller)
        }
        .windowResizability(.contentMinSize)
    }
}
