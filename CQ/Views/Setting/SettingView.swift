//
//  SettingView.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import SwiftUI

struct SettingView: View {
    @ObservedObject private var model: MenuPanelModel

    init(model: MenuPanelModel = MenuPanelModel()) {
        self.model = model
    }

    var body: some View {
        MenuPanelScreen(
            model: model,
            size: .expanded
        )
    }
}

#Preview {
    SettingView()
}
