//
//  UIViewController+PanModalPresentable.swift
//  PanModalDemo
//
//  Created by Viktoriia Rohozhyna on 04.01.2021.
//  Copyright © 2021 Detail. All rights reserved.
//

import UIKit

extension PanModalPresentable where Self: UIViewController {

    var panScrollable: UIScrollView? {
        nil
    }

    var topOffset: CGFloat {
        topLayoutOffset + 11.0
    }

    var shortFormHeight: PanModalHeight {
        longFormHeight
    }

    var longFormHeight: PanModalHeight {

        guard let scrollView = panScrollable
        else { return .maxHeight }

        scrollView.layoutIfNeeded()
        return .contentHeight(scrollView.contentSize.height)
    }

    var cornerRadius: CGFloat {
        20.0
    }

    var animationMode: AnimationMode {
        .normal
    }

    var springDamping: CGFloat {
        0.8
    }

    var springDampingFullScreen: CGFloat {
        1.0
    }

    var transitionDuration: Double {
        PanModalAnimator.Defaults.defaultTransitionDuration
    }

    var transitionAnimationOptions: UIView.AnimationOptions {
        [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
    }

    var panModalBackgroundColor: UIColor {
        UIColor.black.withAlphaComponent(0.4)
    }

    var dragIndicatorBackgroundColor: UIColor {
        UIColor.lightGray
    }

    var scrollIndicatorInsets: UIEdgeInsets {
        let top = shouldRoundTopCorners ? cornerRadius : 0
        return UIEdgeInsets(top: CGFloat(top), left: 0, bottom: bottomLayoutOffset, right: 0)
    }

    var anchorModalToLongForm: Bool {
        true
    }

    var allowsExtendedPanScrolling: Bool {

        guard panScrollable != nil
        else { return false }

        return true
    }

    var allowsDragToDismiss: Bool {
        true
    }

    var allowsTapToDismiss: Bool {
        true
    }

    var isUserInteractionEnabled: Bool {
        true
    }

    var isHapticFeedbackEnabled: Bool {
        false
    }

    var shouldRoundTopCorners: Bool {
        isPanModalPresented
    }

    var showDragIndicator: Bool {
        shouldRoundTopCorners
    }

    func shouldRespond(to panModalGestureRecognizer: UIPanGestureRecognizer) -> Bool {
        return true
    }

    func willRespond(to panModalGestureRecognizer: UIPanGestureRecognizer) { }

    func shouldTransition(to state: PanModalPresentationController.PresentationState) -> Bool {
        true
    }

    func shouldPrioritize(panModalGestureRecognizer: UIPanGestureRecognizer) -> Bool {
        false
    }

    func willTransition(to state: PanModalPresentationController.PresentationState) {}

    func panModalWillDismiss() { }

    func panModalDidDismiss() { }

    func panModalStartDragging() { }

    func panModalStopDragging() { }
}
