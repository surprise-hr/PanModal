//
//  PanModalPresentationDelegate.swift
//  PanModal
//
//  Copyright © 2019 Tiny Speck, Inc. All rights reserved.
//

#if os(iOS)
import UIKit

/**
 The PanModalPresentationDelegate conforms to the various transition delegates
 and vends the appropriate object for each transition controller requested.

 Usage:
 ```
 viewController.modalPresentationStyle = .custom
 viewController.transitioningDelegate = PanModalPresentationDelegate.default
 ```
 */
public class PanModalPresentationDelegate: NSObject {

    /**
     Returns an instance of the delegate, retained for the duration of presentation
     */
    public static var `default`: PanModalPresentationDelegate = PanModalPresentationDelegate()

    private let driver = PanModalDriver()
}

extension PanModalPresentationDelegate: UIViewControllerTransitioningDelegate {

    /**
     Returns a modal presentation animator configured for the presenting state
     */
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PanModalPresentationAnimator(transitionStyle: .presentation)
    }

    /**
     Returns a modal presentation animator configured for the dismissing state
     */
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PanModalPresentationAnimator(transitionStyle: .dismissal)
    }

    /**
     Returns a modal presentation controller to coordinate the transition from the presenting
     view controller to the presented view controller.

     Changes in size class during presentation are handled via the adaptive presentation delegate
     */
    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        driver.link(to: presented)
        
        let controller = PanModalPresentationController(presentedViewController: presented,
                                                        presenting: presenting)

        controller.driver = driver

        return controller
    }

    public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return driver
    }

    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return driver
    }
}
#endif
