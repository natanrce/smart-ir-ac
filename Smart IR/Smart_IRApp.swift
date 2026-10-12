//
//  Smart_IRApp.swift
//  Smart IR
//
//  Created by Natan Rodrigues on 12/10/26.
//

import SwiftUI

@main
struct Smart_IRApp: App {
    @State private var controller = ACController()

    var body: some Scene {
        MenuBarExtra {
            ACPanelView(controller: controller)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "air.conditioner.horizontal")
                if controller.state.power {
                    Text("\(controller.state.temp)°")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
