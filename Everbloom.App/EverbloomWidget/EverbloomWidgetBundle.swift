//
//  EverbloomWidgetBundle.swift
//  EverbloomWidget
//
//  Created by Burak Cakmakoglu  on 2026-03-19.
//

import WidgetKit
import SwiftUI

@main
struct EverbloomWidgetBundle: WidgetBundle {
    var body: some Widget {
        EverbloomWidget()
        EverbloomQuickActionsWidget()
        EverbloomWidgetControl()
        EverbloomWidgetLiveActivity()
    }
}
