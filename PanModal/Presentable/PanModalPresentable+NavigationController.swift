//
//  PanModalPresentable+NavigationController.swift
//  LiteMobile
//
//  Created by Viktoriia Rohozhyna on 26.11.2020.
//  Copyright © 2020 Surprise HR, Inc. All rights reserved.
//

import UIKit

open class PanNavigationController: UINavigationController, PanModalPresentable {

    open override func popViewController(animated: Bool) -> UIViewController? {
        let viewController = super.popViewController(animated: animated)
        panModalSetNeedsLayoutUpdate()
        return viewController
    }

    open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        panModalSetNeedsLayoutUpdate()
    }

    // MARK: - Pan Modal Presentable
    public var panScrollable: UIScrollView? {
        return (topViewController as? PanModalPresentable)?.panScrollable
    }

    public var longFormHeight: PanModalHeight {
        return .maxHeight
    }

    public var shortFormHeight: PanModalHeight {
        return longFormHeight
    }
}
