//
//  NotebarApp.swift
//  Notebar
//
//  The app's entry point. Uses SwiftUI's MenuBarExtra scene (macOS 13+) to
//  create a menu bar app. The `.window` style shows the content in a
//  popover-like window, and the system handles keyboard focus for us — which
//  is why we no longer need the old AppDelegate + NSPopover + first-responder
//  library setup.
//

import SwiftUI

@main
struct NotebarApp: App {
    var body: some Scene {
        MenuBarExtra("Notebar", image: "MenubarIcon") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
