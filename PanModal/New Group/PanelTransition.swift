//
//  PanelTransition.swift
//  PanModalDemo
//
//  Created by Viktoriia Rohozhyna on 18.12.2020.
//  Copyright © 2020 Detail. All rights reserved.
//

import UIKit

final class PanModalPresentationDelegate: NSObject, UIViewControllerTransitioningDelegate {

    /**
     Returns an instance of the delegate, retained for the duration of presentation
     */
    public static var `default`: PanModalPresentationDelegate = PanModalPresentationDelegate()


    var driver = TransitionDriver()

    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {

        driver = TransitionDriver()

        let presentationController = PanModalPresentationController(presentedViewController: presented,
                                                                    presenting: presenting ?? source)
        driver.link(to: presentationController)
        presentationController.driver = driver
        return presentationController
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PresentAnimation()
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissAnimation()
    }

    func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return driver
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return driver
    }
}
