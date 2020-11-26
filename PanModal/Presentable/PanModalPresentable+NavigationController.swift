//
//  PanModalPresentable+NavigationController.swift
//  LiteMobile
//
//  Created by Viktoriia Rohozhyna on 26.11.2020.
//  Copyright © 2020 Surprise HR, Inc. All rights reserved.
//

import UIKit

final class PanNavigationController: UINavigationController, PanModalPresentable {

    override func popViewController(animated: Bool) -> UIViewController? {
        let viewController = super.popViewController(animated: animated)
        panModalSetNeedsLayoutUpdate()
        return viewController
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        panModalSetNeedsLayoutUpdate()
    }

    // MARK: - Pan Modal Presentable
    var panScrollable: UIScrollView? {
        return (topViewController as? PanModalPresentable)?.panScrollable
    }

    var longFormHeight: PanModalHeight {
        return .maxHeight
    }

    var shortFormHeight: PanModalHeight {
        return longFormHeight
    }
}
