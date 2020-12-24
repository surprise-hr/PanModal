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
        static let defaultTransitionDuration: TimeInterval = 0.3
        static let defaultSpringValue: CGFloat = 1.0
    }

    static func animate(_ animations: @escaping PanModalPresentable.AnimationBlockType,
                        animationDuration: Double,
                        isDamping: Bool,
                        config: PanModalPresentable?,
                        _ completion: ((UIViewAnimatingPosition) -> Void)? = nil) {

        let springValue = isDamping ? (config?.springDamping ?? Defaults.defaultSpringValue) : (config?.springDampingFullScreen ?? Defaults.defaultSpringValue)

        let springTimingParameters: UITimingCurveProvider = UISpringTimingParameters(dampingRatio: springValue, initialVelocity: CGVector(dx: 0.0, dy: 1.0))
        let animation = UIViewPropertyAnimator(duration: animationDuration, timingParameters: springTimingParameters)


        animation.addAnimations(animations)
        if let completion = completion {
            animation.addCompletion(completion)
        }
        
        animation.startAnimation()
    }
}
#endif
