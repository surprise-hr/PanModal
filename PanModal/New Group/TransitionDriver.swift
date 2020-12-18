//
//  TransitionDriver.swift
//  PanModalDemo
//
//  Created by Viktoriia Rohozhyna on 18.12.2020.
//  Copyright © 2020 Detail. All rights reserved.
//

import UIKit

enum TransitionDirection {
    case present, dismiss
}
protocol PanelAnimationControllerDelegate: AnyObject {
    func shouldHandlePanelInteractionGesture() -> Bool
    func shouldStartDismissGesture(for: UIPanGestureRecognizer) -> Bool
    func panelInteractionGestureEnded()
    func panelInteractionGestureStarted()
}

extension PanelAnimationControllerDelegate {
    func shouldStartDismissGesture(for: UIPanGestureRecognizer) -> Bool {
        return true
    }

    func panelInteractionGestureEnded() {}
    func panelInteractionGestureStarted() {}
}


protocol TransitionDriverProtocol {
    var direction: TransitionDirection { get set }
    func handleClose()
    func updateLayout(controller: PanModalPresentationController)
    func performUpdates(_ updates: () -> Void)
    func transition(to state: PanModalPresentationController.PresentationState)
}

final class TransitionDriver: UIPercentDrivenInteractiveTransition, TransitionDriverProtocol {

    /**
     Constants
     */
    enum Constants {
        static let indicatorYOffset: CGFloat = 10.0
        static let snapMovementSensitivity: CGFloat = 0.7
        static let dragIndicatorSize: CGSize = .init(width: 64.0, height: 4.0)
    }

    // MARK: - Properties
    private weak var presentedController: UIViewController?
    weak var panelDelegate: PanelAnimationControllerDelegate?

    let panRecognizer = UIPanGestureRecognizer()
    var direction: TransitionDirection = .present

    /**
     A flag to track if the presented view is animating
     */
    private var isPresentedViewAnimating = false

    /**
     A flag to determine if scrolling should seamlessly transition
     from the pan modal container view to the scroll view
     once the scroll limit has been reached.
     */
    private var extendsPanScrolling = true

    /**
     The y content offset value of the embedded scroll view
     */
    private var scrollViewYOffset: CGFloat = 0.0

    /**
     An observer for the scroll view content offset
     */
    private var scrollObserver: NSKeyValueObservation?

    /**
     A flag to determine if scrolling should be limited to the longFormHeight.
     Return false to cap scrolling at .max height.
     */
    private var anchorModalToLongForm = true

    /**
     The y value for the short form presentation state
     */
    private var shortFormYPosition: CGFloat = 0

    /**
     The y value for the long form presentation state
     */
    private var longFormYPosition: CGFloat = 0

    /**
     Configuration object for PanModalPresentationController
     */
    private var presentable: PanModalPresentable? {
        return presentedController as? PanModalPresentable
    }

    var presentedView: UIView = .init()
    var containerViewFrame: CGRect = .zero
    /**
     Determine anchored Y postion based on the `anchorModalToLongForm` flag
     */
    private var anchoredYPosition: CGFloat {
        let defaultTopOffset = presentable?.topOffset ?? 0
        return anchorModalToLongForm ? longFormYPosition : defaultTopOffset
    }
    
    /**
     Boolean flag to determine if the presented view is anchored
     */
    var isPresentedViewAnchored: Bool {
        if !isPresentedViewAnimating
            && extendsPanScrolling
            && presentedView.frame.minY.rounded() <= anchoredYPosition.rounded() {
            return true
        }

        return false
    }

    override var wantsInteractiveStart: Bool {
        get {
            switch direction {
            case .present:
                return false
            case .dismiss:
                let gestureIsActive = panRecognizer.state == .began
                return gestureIsActive
            }
        }
        set {
            _ = newValue
        }
    }

    // MARK: - Deinitializers

    deinit {
        scrollObserver?.invalidate()
    }
}

// MARK: - Internal methods
extension TransitionDriver {

    func handleClose() {
        presentedController?.dismiss(animated: true) // Start the new one
    }

    func link(to controller: UIPresentationController) {
        completionSpeed = 0.1

        panRecognizer.cancelsTouchesInView = false
        panRecognizer.addTarget(self, action: #selector(handlePan))
        panRecognizer.delegate = self

        presentedController = controller.presentedViewController
        presentedController?.view.addGestureRecognizer(panRecognizer)
        presentedView = controller.presentedView ?? UIView()
    }

    func updateLayout(controller: PanModalPresentationController) {
        shortFormYPosition = controller.shortFormYPosition
        longFormYPosition = controller.longFormYPosition
        anchorModalToLongForm = controller.anchorModalToLongForm
        extendsPanScrolling = controller.extendsPanScrolling

        observe(scrollView: presentable?.panScrollable)

        containerViewFrame = controller.containerView?.bounds ?? .zero

        configureScrollViewInsets()
    }


    /**
     Transition the PanModalPresentationController
     to the given presentation state
     */
    func transition(to state: PanModalPresentationController.PresentationState) {

        guard presentable?.shouldTransition(to: state) == true
        else { return }

        presentable?.willTransition(to: state)

        switch state {
        case .shortForm:
            snap(toYPosition: shortFormYPosition)
        case .longForm:
            snap(toYPosition: longFormYPosition)
        }
    }

    /**
     Configures the scroll view insets
     */
    func configureScrollViewInsets() {

        guard
            let scrollView = presentable?.panScrollable,
            !scrollView.isScrolling
        else { return }

        /**
         Disable vertical scroll indicator until we start to scroll
         to avoid visual bugs
         */
        scrollView.showsVerticalScrollIndicator = false
        scrollView.scrollIndicatorInsets = presentable?.scrollIndicatorInsets ?? .zero

        /**
         Set the appropriate contentInset as the configuration within this class
         offsets it
         */
        scrollView.contentInset.bottom = presentedController?.bottomLayoutGuide.length ?? .zero
    }

    func performUpdates(_ updates: () -> Void) {

        guard let scrollView = presentable?.panScrollable
        else { return }

        // Pause scroll observer
        scrollObserver?.invalidate()
        scrollObserver = nil

        // Perform updates
        updates()

        // Resume scroll observer
        trackScrolling(scrollView)
        observe(scrollView: scrollView)
    }
}

// MARK: - Private methods
private extension TransitionDriver {

    var maxTranslation: CGFloat {
        return presentedController?.view.frame.height ?? 0
    }

    /// `pause()` before call `isRunning`
    var isRunning: Bool {
        return percentComplete != 0
    }

    @objc
    func handlePan(recognizer: UIPanGestureRecognizer) {
        guard
            shouldRespond(to: recognizer)
        else {
            recognizer.setTranslation(.zero, in: recognizer.view)
            return
        }

        presentable?.willRespond(to: recognizer)

        switch recognizer.state {
        case .began:
            pause() // Pause allows to detect isRunning
            if !isRunning && (panelDelegate?.shouldStartDismissGesture(for: recognizer) == true || panelDelegate == nil) {
                presentedController?.dismiss(animated: true) // Start the new one
            }
            panelDelegate?.panelInteractionGestureStarted()
        case .changed:
            //respond(to: recognizer)
            let increment = recognizer.incrementToBottom(maxTranslation: maxTranslation)
            update(percentComplete + increment)

            if presentedView.frame.origin.y == anchoredYPosition && extendsPanScrolling {
                presentable?.willTransition(to: .longForm)
            }
        case .ended, .cancelled:
            /**
             Use velocity sensitivity value to restrict snapping
             */
            let velocity = recognizer.velocity(in: presentedView)

            if isVelocityWithinSensitivityRange(velocity.y) {

                /**
                 If velocity is within the sensitivity range,
                 transition to a presentation state or dismiss entirely.

                 This allows the user to dismiss directly from long form
                 instead of going to the short form state first.
                 */
                if velocity.y < 0 {
                    transition(to: .longForm)
                    recognizer.setTranslation(.zero, in: nil)
                    presentable?.panModalStopDragging()
                } else if (nearest(to: percentComplete * maxTranslation, inValues: [longFormYPosition, containerViewFrame.height]) == longFormYPosition
                            && percentComplete * maxTranslation < shortFormYPosition) || presentable?.allowsDragToDismiss == false {
                    transition(to: .shortForm)
                } else {
                    //finish()
                    //timingCurve = UICubicTimingParameters(animationCurve: .linear)
                    //completionSpeed = max(2, (presentedView.frame.height * (1 / 5.5) / velocity.y))
                    finish()
                    //presentedController?.presentedViewController.dismiss(animated: true)
                }

            } else {

                /**
                 The `containerView.bounds.height` is used to determine
                 how close the presented view is to the bottom of the screen
                 */
                let position = nearest(to: percentComplete * maxTranslation, inValues: [presentedView.bounds.height, shortFormYPosition, longFormYPosition])

                if position == longFormYPosition {
                    transition(to: .longForm)
                    presentable?.panModalStopDragging()
                } else if position == shortFormYPosition || presentable?.allowsDragToDismiss == false {
                    transition(to: .shortForm)
                } else {
                    // finish()
                    //timingCurve = UICubicTimingParameters(animationCurve: .linear)
                    //completionSpeed = max(2, (presentedView.frame.height * (1 / 5.5) / velocity.y))
                    finish()
                    //presentedController?.presentedViewController.dismiss(animated: true)
                }
            }
        //            if recognizer.isProjectedToDownHalf(maxTranslation: maxTranslation) && recognizer.direction == .topToBottom {
        //                finish()
        //                panelDelegate?.panelInteractionGestureEnded()
        //            } else {
        //                cancel()
        //                panelDelegate?.panelInteractionGestureEnded()
        //            }
        case .failed:
            cancel()
            panelDelegate?.panelInteractionGestureEnded()
        default:
            break
        }
    }

    /**
     Determine if the pan modal should respond to the gesture recognizer.

     If the pan modal is already being dragged & the delegate returns false, ignore until
     the recognizer is back to it's original state (.began)

     ⚠️ This is the only time we should be cancelling the pan modal gesture recognizer
     */
    func shouldRespond(to panGestureRecognizer: UIPanGestureRecognizer) -> Bool {
        guard
            presentable?.shouldRespond(to: panGestureRecognizer) == true ||
                !(panGestureRecognizer.state == .began || panGestureRecognizer.state == .cancelled)
        else {
            panGestureRecognizer.isEnabled = false
            panGestureRecognizer.isEnabled = true
            presentable?.panModalStopDragging()
            return false
        }
        let shouldFailVar = shouldFail(panGestureRecognizer: panGestureRecognizer)
        shouldFailVar ? presentable?.panModalStopDragging() :  presentable?.panModalStartDragging()
        return !shouldFailVar
    }

    /**
     Communicate intentions to presentable and adjust subviews in containerView
     */
    func respond(to panGestureRecognizer: UIPanGestureRecognizer) {

        // update(percentComplete + panGestureRecognizer.incrementToBottom(maxTranslation: maxTranslation))
        var yDisplacement = panGestureRecognizer.translation(in: presentedView).y

        /**
         If the presentedView is not anchored to long form, reduce the rate of movement
         above the threshold
         */
        if presentedView.frame.origin.y < longFormYPosition {
            yDisplacement /= 2.0
        }
        adjust(toYPosition: presentedView.frame.origin.y + yDisplacement)

        panGestureRecognizer.setTranslation(.zero, in: presentedView)
    }

    /**
     Determines if we should fail the gesture recognizer based on certain conditions

     We fail the presented view's pan gesture recognizer if we are actively scrolling on the scroll view.
     This allows the user to drag whole view controller from outside scrollView touch area.

     Unfortunately, cancelling a gestureRecognizer means that we lose the effect of transition scrolling
     from one view to another in the same pan gesture so don't cancel
     */
    func shouldFail(panGestureRecognizer: UIPanGestureRecognizer) -> Bool {

        /**
         Allow api consumers to override the internal conditions &
         decide if the pan gesture recognizer should be prioritized.

         ⚠️ This is the only time we should be cancelling the panScrollable recognizer,
         for the purpose of ensuring we're no longer tracking the scrollView
         */
        guard !shouldPrioritize(panGestureRecognizer: panGestureRecognizer) else {
            presentable?.panScrollable?.panGestureRecognizer.isEnabled = false
            presentable?.panScrollable?.panGestureRecognizer.isEnabled = true
            return false
        }

        guard
            isPresentedViewAnchored,
            let scrollView = presentable?.panScrollable,
            scrollView.contentOffset.y > 0
        else {
            return false
        }

        let loc = panGestureRecognizer.location(in: presentedView)
        return (scrollView.frame.contains(loc) || scrollView.isScrolling)
    }
    
    
    func snap(toYPosition yPos: CGFloat) {
        PanModalAnimator.animate({ [weak self] in
            print(yPos)
            self?.adjust(toYPosition: yPos)
            self?.isPresentedViewAnimating = true
        }, config: presentable) { [weak self] position in
            self?.isPresentedViewAnimating = position != .end
        }
    }

    /**
     Finds the nearest value to a given number out of a given array of float values

     - Parameters:
     - number: reference float we are trying to find the closest value to
     - values: array of floats we would like to compare against
     */
    func nearest(to number: CGFloat, inValues values: [CGFloat]) -> CGFloat {
        guard let nearestVal = values.min(by: { abs(number - $0) < abs(number - $1) })
        else { return number }
        return nearestVal
    }

    /**
     Determine if the presented view's panGestureRecognizer should be prioritized over
     embedded scrollView's panGestureRecognizer.
     */
    func shouldPrioritize(panGestureRecognizer: UIPanGestureRecognizer) -> Bool {
        return panGestureRecognizer.state == .began &&
            presentable?.shouldPrioritize(panModalGestureRecognizer: panGestureRecognizer) == true
    }

    /**
     Check if the given velocity is within the sensitivity range
     */
    func isVelocityWithinSensitivityRange(_ velocity: CGFloat) -> Bool {
        return (abs(velocity) - (1000 * (1 - Constants.snapMovementSensitivity))) > 0
    }

    /**
     Sets the y position of the presentedView & adjusts the backgroundView.
     */
    func adjust(toYPosition yPos: CGFloat) {
        print(max(yPos, anchoredYPosition))
        print(yPos/maxTranslation)
        //presentedView.frame.origin.y = 255
            //max(yPos, anchoredYPosition)
        //update(0)
        for element in percentComplete..<yPos/maxTranslation {
            update(element)
        }


        guard presentedView.frame.origin.y > shortFormYPosition else {
            // backgroundView.dimState = .max
            return
        }

        let yDisplacementFromShortForm = presentedView.frame.origin.y - shortFormYPosition

        /**
         Once presentedView is translated below shortForm, calculate yPos relative to bottom of screen
         and apply percentage to backgroundView alpha
         */
        //backgroundView.dimState = .percent(1.0 - (yDisplacementFromShortForm / presentedView.frame.height))
    }

}


// MARK: - UIScrollView Observer

private extension TransitionDriver {

    /**
     Creates & stores an observer on the given scroll view's content offset.
     This allows us to track scrolling without overriding the scrollView delegate
     */
    func observe(scrollView: UIScrollView?) {
        scrollObserver?.invalidate()
        scrollObserver = scrollView?.observe(\.contentOffset, options: .old) { [weak self] scrollView, change in

            guard let self = self else { return }
            /**
             Incase we have a situation where we have two containerViews in the same presentation
             */

            self.didPanOnScrollView(scrollView, change: change)
        }
    }

    /**
     Scroll view content offset change event handler

     Also when scrollView is scrolled to the top, we disable the scroll indicator
     otherwise glitchy behaviour occurs

     This is also shown in Apple Maps (reverse engineering)
     which allows us to seamlessly transition scrolling from the panContainerView to the scrollView
     */
    func didPanOnScrollView(_ scrollView: UIScrollView, change: NSKeyValueObservedChange<CGPoint>) {

        if !isPresentedViewAnchored && scrollView.contentOffset.y > 0 {

            /**
             Hold the scrollView in place if we're actively scrolling and not handling top bounce
             */
            haltScrolling(scrollView)

        } else if scrollView.isScrolling || isPresentedViewAnimating {

            if isPresentedViewAnchored {
                /**
                 While we're scrolling upwards on the scrollView,
                 store the last content offset position
                 */
                trackScrolling(scrollView)
            } else {
                /**
                 Keep scroll view in place while we're panning on main view
                 */
                haltScrolling(scrollView)
            }

        } else if presentedController?.view.isKind(of: UIScrollView.self) ?? false
                    && !isPresentedViewAnimating && scrollView.contentOffset.y <= 0 {

            /**
             In the case where we drag down quickly on the scroll view and let go,
             `handleScrollViewTopBounce` adds a nice elegant touch.
             */
            handleScrollViewTopBounce(scrollView: scrollView, change: change)
        } else {
            trackScrolling(scrollView)
        }
    }

    /**
     Halts the scroll of a given scroll view & anchors it at the `scrollViewYOffset`
     */
    func haltScrolling(_ scrollView: UIScrollView) {
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollViewYOffset), animated: false)
        scrollView.showsVerticalScrollIndicator = false
    }

    /**
     As the user scrolls, track & save the scroll view y offset.
     This helps halt scrolling when we want to hold the scroll view in place.
     */
    func trackScrolling(_ scrollView: UIScrollView) {
        scrollViewYOffset = max(scrollView.contentOffset.y, 0)
        scrollView.showsVerticalScrollIndicator = true
    }

    /**
     To ensure that the scroll transition between the scrollView & the modal
     is completely seamless, we need to handle the case where content offset is negative.

     In this case, we follow the curve of the decelerating scroll view.
     This gives the effect that the modal view and the scroll view are one view entirely.

     - Note: This works best where the view behind view controller is a UIScrollView.
     So, for example, a UITableViewController.
     */
    func handleScrollViewTopBounce(scrollView: UIScrollView, change: NSKeyValueObservedChange<CGPoint>) {

        guard let oldYValue = change.oldValue?.y, scrollView.isDecelerating
        else { return }

        let yOffset = scrollView.contentOffset.y
        let presentedSize = presentedView.frame.size ?? .zero

        /**
         Decrease the view bounds by the y offset so the scroll view stays in place
         and we can still get updates on its content offset
         */
        //presentedView.bounds.size = CGSize(width: presentedSize.width, height: presentedSize.height + yOffset)

        if oldYValue > yOffset {
            /**
             Move the view in the opposite direction to the decreasing bounds
             until half way through the deceleration so that it appears
             as if we're transferring the scrollView drag momentum to the entire view
             */

            snap(toYPosition: longFormYPosition - yOffset)
            //presentedView.frame.origin.y = longFormYPosition - yOffset
        } else {
            scrollViewYOffset = 0
            snap(toYPosition: longFormYPosition)

            guard presentedView.frame.origin.y > shortFormYPosition else {
                //backgroundView.dimState = .max
                return
            }

            let yDisplacementFromShortForm = presentedView.frame.origin.y - shortFormYPosition
            //backgroundView.dimState = .percent(1.0 - (yDisplacementFromShortForm / presentedView.frame.height))
        }

        scrollView.showsVerticalScrollIndicator = false
    }
}

// MARK: - UIGestureRecognizerDelegate
extension TransitionDriver: UIGestureRecognizerDelegate {
    /**
     Do not require any other gesture recognizers to fail
     */
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    /**
     Allow simultaneous gesture recognizers only when the other gesture recognizer's view
     is the pan scrollable view
     */
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer.view == presentable?.panScrollable
    }
}

enum UIPanGestureRecognizerDirection {
    case undefined
    case bottomToTop
    case topToBottom
    case rightToLeft
    case leftToRight
}

extension UIPanGestureRecognizer {

    var velocity: CGPoint {
        self.velocity(in: view)
    }

    var isVertical: Bool {
        return abs(velocity.y) > abs(velocity.x)
    }

    var direction: UIPanGestureRecognizerDirection {

        var direction: UIPanGestureRecognizerDirection

        if isVertical {
            direction = velocity.y > 0 ? .topToBottom : .bottomToTop
        } else {
            direction = velocity.x > 0 ? .leftToRight : .rightToLeft
        }

        return direction
    }
}

extension UIScrollView {

    /**
     A flag to determine if a scroll view is scrolling
     */
    var isScrolling: Bool {
        return isDragging && !isDecelerating || isTracking
    }
}

// MARK: - UIPanGestureRecognizer + Extension
extension UIPanGestureRecognizer {

    func isProjectedToDownHalf(maxTranslation: CGFloat) -> Bool {
        let endLocation = projectedLocation(decelerationRate: .fast)
        let isPresentationCompleted = endLocation.y > maxTranslation / 2

        return isPresentationCompleted
    }

    func incrementToBottom(maxTranslation: CGFloat) -> CGFloat {
        let translation = self.translation(in: view).y
        setTranslation(.zero, in: nil)

        let percentIncrement = translation / maxTranslation
        return percentIncrement
    }
}

extension UIPanGestureRecognizer {
    func projectedLocation(decelerationRate: UIScrollView.DecelerationRate) -> CGPoint {
        let velocityOffset = velocity(in: nil).projectedOffset(decelerationRate: decelerationRate)
        let inViewPoint = location(in: nil)
        let projectedLocation = CGPoint(x: inViewPoint.x + velocityOffset.x, y: inViewPoint.y + velocityOffset.y)
        return projectedLocation
    }
}

extension CGPoint {
    func projectedOffset(decelerationRate: UIScrollView.DecelerationRate) -> CGPoint {
        return CGPoint(x: x.projectedOffset(decelerationRate: decelerationRate),
                       y: y.projectedOffset(decelerationRate: decelerationRate))
    }
}

extension CGFloat { // Velocity value
    func projectedOffset(decelerationRate: UIScrollView.DecelerationRate) -> CGFloat {
        // Formula from WWDC
        let multiplier = 1 / (1 - decelerationRate.rawValue) / 1000
        return self * multiplier
    }
}
