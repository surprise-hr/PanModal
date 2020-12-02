//
//  PanModalAnimator.swift
//  PanModal
//
//  Copyright © 2019 Tiny Speck, Inc. All rights reserved.
//
#if os(iOS)
import UIKit

struct PanModalAnimator {

    enum Defaults {
        static let defaultTransitionDuration: TimeInterval = 0.5
    }

    static func animate(_ animations: @escaping PanModalPresentable.AnimationBlockType,
                        config: PanModalPresentable?,
                        _ completion: ((UIViewAnimatingPosition) -> Void)? = nil) {

        let transitionDuration = config?.transitionDuration ?? Defaults.defaultTransitionDuration
        let animationOptions = config?.transitionAnimationOptions ?? []

        let animation = UIViewPropertyAnimator.runningPropertyAnimator(withDuration: transitionDuration / 2,
                                                                       delay: 0,
                                                                       options: animationOptions,
                                                                       animations: animations,
                                                                       completion: completion)
        animation.startAnimation()
    }
}
#endif
