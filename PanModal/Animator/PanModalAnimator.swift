//
//  PanModalAnimator.swift
//  PanModal
//
//  Copyright © 2019 Tiny Speck, Inc. All rights reserved.
//
#if os(iOS)
import UIKit

public struct PanModalAnimator {

    public enum Defaults {
        static let defaultTransitionDuration: TimeInterval = 0.25
    }

    static func animate(_ animations: @escaping PanModalPresentable.AnimationBlockType,
                        animationDuration: Double,
                        config: PanModalPresentable?,
                        _ completion: ((UIViewAnimatingPosition) -> Void)? = nil) {

        let animationOptions = config?.transitionAnimationOptions ?? []

        let animation = UIViewPropertyAnimator.runningPropertyAnimator(withDuration: animationDuration,
                                                                       delay: 0,
                                                                       options: animationOptions,
                                                                       animations: animations,
                                                                       completion: completion)
        animation.startAnimation()
    }
}
#endif
