//
//  PanModalDriver.swift
//  PanModalDemo
//
//  Created by Viktoriia Rohozhyna on 16.12.2020.
//  Copyright © 2020 Detail. All rights reserved.
//


import UIKit

enum TransitionDirection {
    case present, dismiss
}

final class PanModalDriver: UIPercentDrivenInteractiveTransition {
    /**
     Enum representing the possible presentation states
     */
    public enum PresentationState {
        case shortForm
        case longForm
    }

    /**
     Constants
     */
    enum Constants {
        static let indicatorYOffset: CGFloat = 10.0
        static let snapMovementSensitivity: CGFloat = 0.7
        static let dragIndicatorSize: CGSize = .init(width: 64.0, height: 4.0)
    }
    
    // MARK: - Properties

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
     A flag to determine if scrolling should be limited to the longFormHeight.
     Return false to cap scrolling at .max height.
     */
    private var anchorModalToLongForm = true

    /**
     The y content offset value of the embedded scroll view
     */
    private var scrollViewYOffset: CGFloat = 0.0

    /**
     An observer for the scroll view content offset
     */
    private var scrollObserver: NSKeyValueObservation?

    // store the y positions so we don't have to keep re-calculating

    /**
     The y value for the short form presentation state
     */
    private var shortFormYPosition: CGFloat = 0

    /**
     The y value for the long form presentation state
     */
    private var longFormYPosition: CGFloat = 0


    var backgroundView = DimmedView()
    /**
     Determine anchored Y postion based on the `anchorModalToLongForm` flag
     */
    private var anchoredYPosition: CGFloat {
        let defaultTopOffset = presentable?.topOffset ?? 0
        return anchorModalToLongForm ? longFormYPosition : defaultTopOffset
    }

    /**
     Configuration object for PanModalPresentationController
     */
    private var presentable: PanModalPresentable? {
        return presentedController as? PanModalPresentable
    }

    private weak var presentedController: UIViewController?

    // MARK: - Gesture Recognizers

    /**
     Gesture recognizer to detect & track pan gestures
     */
    let panGestureRecognizer = UIPanGestureRecognizer()

    var presentedView: UIView = UIView()
    var containerView: UIView = UIView()

    var direction: TransitionDirection = .present

    override var wantsInteractiveStart: Bool {
        get {
            switch direction {
            case .present:
                return false
            case .dismiss:
                let gestureIsActive = panGestureRecognizer.state == .began
                return gestureIsActive
            }
        }

        set { }
    }

    var maxTranslation: CGFloat {
        return longFormYPosition
    }

    /// `pause()` before call `isRunning`
    var isRunning: Bool {
        return percentComplete != 0
    }
}

// MARK: - Internal methods
extension PanModalDriver {

    func link(to controller: UIViewController) {

        completionSpeed = 0.1

        panGestureRecognizer.cancelsTouchesInView = false
        panGestureRecognizer.addTarget(self, action: #selector(handlePan))
        panGestureRecognizer.delegate = self

        presentedController = controller
        //presentedController?.view.addGestureRecognizer(panGestureRecognizer)


    }

    func add(backgroundView: DimmedView, presentedView: UIView, containerView: UIView) {
        self.backgroundView = backgroundView
        self.presentedView = presentedView
        self.containerView = containerView

        configureViewLayout()
        self.containerView.addGestureRecognizer(panGestureRecognizer)
    }

    func handleTap() {
        finish()
    }

    func snap(toYPosition yPos: CGFloat) {
        let animator = PanModalAnimator.animate({ [weak self] in
            self?.adjust(toYPosition: yPos)
            self?.isPresentedViewAnimating = true
        }, config: presentable) { [weak self] position in
            self?.isPresentedViewAnimating = position != .end
        }

        animator.startAnimation()
    }

    /**
     Calculates & stores the layout anchor points & options
     */
    func configureViewLayout() {

        guard let layoutPresentable = presentedController as? PanModalPresentable.LayoutType
        else { return }

        shortFormYPosition = layoutPresentable.shortFormYPos
        longFormYPosition = layoutPresentable.longFormYPos
        anchorModalToLongForm = layoutPresentable.anchorModalToLongForm
        extendsPanScrolling = layoutPresentable.allowsExtendedPanScrolling
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

}

// MARK: - Private methods
private extension PanModalDriver {

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

    func handlePresentation(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pause()
        case .changed:
            let increment = -recognizer.incrementToBottom(maxTranslation: maxTranslation)
            update(percentComplete + increment)
        case .ended, .cancelled:
            if recognizer.isProjectedToDownHalf(maxTranslation: maxTranslation) {
                cancel()
            } else {
                finish()
            }
        case .failed:
            cancel()
        default:
            break
        }
    }

    func handleDismiss(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pause() // Pause allows to detect isRunning
            if !isRunning {
                //presentedController?.dismiss(animated: true) // Start the new one
            }
        case .changed:

            let increment = recognizer.incrementToBottom(maxTranslation: maxTranslation)
            print(increment)
            update(percentComplete + increment)
        case .ended, .cancelled:
                finish()

        case .failed:
            cancel()
        default:
            break
        }
    }

    @objc
    func handlePan(recognizer: UIPanGestureRecognizer) {

        switch direction {
        case .present:
            handlePresentation(recognizer: recognizer)
        case .dismiss:
            handleDismiss(recognizer: recognizer)
        }
    }

//    @objc
//    func handlePan(recognizer: UIPanGestureRecognizer) {
//
//        guard
//            shouldRespond(to: recognizer),
//            let containerView = presentedController?.containerView
//        else {
//            recognizer.setTranslation(.zero, in: recognizer.view)
//            return
//        }
//
//        presentable?.willRespond(to: panGestureRecognizer)
//
//        switch recognizer.state {
//
//        case .began:
//            pause() // Pause allows to detect isRunning
////            if !isRunning {
////                presentedController?.presentedViewController.dismiss(animated: true) // Start the new one
////            }
//        case .changed:
//            /**
//             Respond accordingly to pan gesture translation
//             */
//            respond(to: recognizer)
//
//            /**
//             If presentedView is translated above the longForm threshold, treat as transition
//             */
//            if presentedView.frame.origin.y == anchoredYPosition && extendsPanScrolling {
//                presentable?.willTransition(to: .longForm)
//            }
//        default:
//            /**
//             Use velocity sensitivity value to restrict snapping
//             */
//            let velocity = recognizer.velocity(in: presentedView)
//
//            if isVelocityWithinSensitivityRange(velocity.y) {
//
//                /**
//                 If velocity is within the sensitivity range,
//                 transition to a presentation state or dismiss entirely.
//
//                 This allows the user to dismiss directly from long form
//                 instead of going to the short form state first.
//                 */
//                if velocity.y < 0 {
//                    transition(to: .longForm)
//                    presentable?.panModalStopDragging()
//                } else if (nearest(to: presentedView.frame.minY, inValues: [longFormYPosition, containerView.bounds.height]) == longFormYPosition
//                            && presentedView.frame.minY < shortFormYPosition) || presentable?.allowsDragToDismiss == false {
//                    transition(to: .shortForm)
//                } else {
//                    //finish()
//                    //timingCurve = UICubicTimingParameters(animationCurve: .linear)
//                    //completionSpeed = max(1, (presentedView.frame.height * (1 / 5.5) / velocity.y))
//                    //finish()
//                    presentedController?.presentedViewController.dismiss(animated: true)
//                }
//
//            } else {
//
//                /**
//                 The `containerView.bounds.height` is used to determine
//                 how close the presented view is to the bottom of the screen
//                 */
//                let position = nearest(to: presentedView.frame.minY, inValues: [containerView.bounds.height, shortFormYPosition, longFormYPosition])
//
//                if position == longFormYPosition {
//                    transition(to: .longForm)
//                    presentable?.panModalStopDragging()
//                } else if position == shortFormYPosition || presentable?.allowsDragToDismiss == false {
//                    transition(to: .shortForm)
//                } else {
//                   // finish()
//                    timingCurve = UICubicTimingParameters(animationCurve: .linear)
//                    completionSpeed = max(1, (presentedView.frame.height * (1 / 5.5) / velocity.y))
//                        //finish()
//                    presentedController?.presentedViewController.dismiss(animated: true)
//                }
//            }
//        }
//    }


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

        //panGestureRecognizer.setTranslation(.zero, in: presentedView)
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
        update(percentComplete + max(yPos/maxTranslation, anchoredYPosition/maxTranslation))

        //presentedView.frame.origin.y = max(yPos, anchoredYPosition)

        guard presentedView.frame.origin.y > shortFormYPosition else {
            backgroundView.dimState = .max
            return
        }

        let yDisplacementFromShortForm = presentedView.frame.origin.y - shortFormYPosition

        /**
         Once presentedView is translated below shortForm, calculate yPos relative to bottom of screen
         and apply percentage to backgroundView alpha
         */
        backgroundView.dimState = .percent(1.0 - (yDisplacementFromShortForm / presentedView.frame.height))
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

}

// MARK: - UIGestureRecognizerDelegate
extension PanModalDriver: UIGestureRecognizerDelegate {
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
