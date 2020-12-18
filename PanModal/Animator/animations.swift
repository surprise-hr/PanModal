//
//  animations.swift
//  PanModalDemo
//
//  Created by Viktoriia Rohozhyna on 17.12.2020.
//  Copyright © 2020 Detail. All rights reserved.
//

import Foundation
import UIKit

final class PresentAnimation: NSObject {
    let duration: TimeInterval = 0.25

    private func animator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        let toVC = transitionContext.viewController(forKey: .to)
        let fromVC = transitionContext.viewController(forKey: .from)


        let presentable = transitionContext.viewController(forKey: .to) as? PanModalPresentable.LayoutType

        // Calls viewWillAppear and viewWillDisappear
        fromVC?.beginAppearanceTransition(false, animated: true)

        // Presents the view in shortForm position, initially
        let yPos: CGFloat = presentable?.shortFormYPos ?? 0.0

        // Use panView as presentingView if it already exists within the containerView
        let panView: UIView = transitionContext.containerView.panContainerView ?? toVC!.view

        // Move presented view offscreen (from the bottom)
        panView.frame = transitionContext.finalFrame(for: toVC!)
        panView.frame.origin.y = transitionContext.containerView.frame.height

        // Haptic feedback
        if presentable?.isHapticFeedbackEnabled == true {
            //feedbackGenerator?.selectionChanged()
        }


        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut) {
            panView.frame.origin.y = yPos
        }

        animator.addCompletion { _ in
            fromVC?.endAppearanceTransition()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        animator.startAnimation()
        return animator
    }
}

extension PresentAnimation: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let animator = self.animator(using: transitionContext)
        animator.startAnimation()
    }

    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        return self.animator(using: transitionContext)
    }
}


final class DismissAnimation: NSObject {

    // MARK: - Properties
    private let duration: TimeInterval = 0.3
    private var animatorForCurrentSession: UIViewImplicitlyAnimating?

    // MARK: - Private methods
    private func animator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        let toVC = transitionContext.viewController(forKey: .to)
        let fromVC = transitionContext.viewController(forKey: .from)

        // Calls viewWillAppear and viewWillDisappear
        toVC?.beginAppearanceTransition(true, animated: true)

        let panView: UIView = fromVC!.view

        let duration = transitionDuration(using: transitionContext)

        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeIn) {
            panView.frame.origin.y = transitionContext.containerView.frame.height
        }

        animator.addCompletion { [weak self] _ in
            self?.animatorForCurrentSession = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        return animator
    }
}

// MARK: - UIViewControllerAnimatedTransitioning
extension DismissAnimation: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let animator = interruptibleAnimator(using: transitionContext)
        animator.startAnimation()
    }

    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        if let animator = animatorForCurrentSession {
            return animator
        } else {
            let animator = self.animator(using: transitionContext)
            self.animatorForCurrentSession = animator
            return animator
        }
    }
}
