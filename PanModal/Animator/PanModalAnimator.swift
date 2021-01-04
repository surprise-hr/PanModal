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
        static let defaultSpringValue: CGFloat = 1.0
    }

    static func animate(_ animations: @escaping PanModalPresentable.AnimationBlockType,
                        animationDuration: Double,
                        isDamping: Bool,
                        config: PanModalPresentable?,
                        _ completion: ((UIViewAnimatingPosition) -> Void)? = nil) {

        var animation: UIViewPropertyAnimator?

        switch config?.animationMode {
        case .normal, .none:
            animation = PanModalAnimator.animateWithNormalMode(animationDuration: animationDuration,
                                                               isDamping: isDamping,
                                                               config: config)
        case let .cubicBezier(controlPoint1: controlPoint1, controlPoint2: controlPoint2):
            animation = PanModalAnimator.animateWithCubicBezierMode(animationDuration: animationDuration,
                                                        controlPoint1: controlPoint1,
                                                        controlPoint2: controlPoint2)
        }

        animation?.addAnimations(animations)
        if let completion = completion {
            animation?.addCompletion(completion)
        }

        animation?.startAnimation()
    }

    static func animateWithNormalMode(animationDuration: Double,
                                       isDamping: Bool,
                                       config: PanModalPresentable?) -> UIViewPropertyAnimator {
        let springValue = isDamping ? (config?.springDamping ?? Defaults.defaultSpringValue) : (config?.springDampingFullScreen ?? Defaults.defaultSpringValue)

        let springTimingParameters: UITimingCurveProvider = UISpringTimingParameters(dampingRatio: springValue, initialVelocity: CGVector(dx: 0.0, dy: 1.0))

        return UIViewPropertyAnimator(duration: animationDuration, timingParameters: springTimingParameters)
    }

    static func animateWithCubicBezierMode(animationDuration: Double, controlPoint1: CGPoint, controlPoint2: CGPoint) -> UIViewPropertyAnimator {
        let cubicTimingParameters = UICubicTimingParameters(controlPoint1: controlPoint1, controlPoint2: controlPoint2)

        return UIViewPropertyAnimator(duration: animationDuration, timingParameters: cubicTimingParameters)
    }
}
#endif
