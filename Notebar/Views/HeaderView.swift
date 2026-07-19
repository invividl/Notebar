//
//  HeaderView.swift
//  Notebar
//

import SwiftUI
import AppKit

struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notebar")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Spacer()
                // Native SwiftUI menu, replacing the old NSPopUpButton wrapper.
                Menu {
                    Button("Quit Notebar") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q")
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            Divider()
        }
        .background(Color(.windowBackgroundColor))
    }
}
