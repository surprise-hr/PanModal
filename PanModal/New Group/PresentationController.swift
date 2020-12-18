//
//  PresentationController.swift
//  PanModalDemo
//
//  Created by Viktoriia Rohozhyna on 18.12.2020.
//  Copyright © 2020 Detail. All rights reserved.
//

import UIKit

public class PanModalPresentationController: UIPresentationController {

    /**
     Constants
     */
    enum Constants {
        static let indicatorYOffset: CGFloat = 10.0
        static let snapMovementSensitivity: CGFloat = 0.7
        static let dragIndicatorSize: CGSize = .init(width: 64.0, height: 4.0)
    }

    /**
     Enum representing the possible presentation states
     */
    public enum PresentationState {
        case shortForm
        case longForm
    }
    /**
     A flag to determine if scrolling should seamlessly transition
     from the pan modal container view to the scroll view
     once the scroll limit has been reached.
     */
    var extendsPanScrolling = true

    /**
     A flag to determine if scrolling should be limited to the longFormHeight.
     Return false to cap scrolling at .max height.
     */
    var anchorModalToLongForm = true

    /**
     The y value for the short form presentation state
     */
    var shortFormYPosition: CGFloat = 0

    /**
     The y value for the long form presentation state
     */
    var longFormYPosition: CGFloat = 0

    /**
     A wrapper around the presented view so that we can modify
     the presented view apperance without changing
     the presented view's properties
     */
    private lazy var panContainerView: PanContainerView = {
        let frame = containerView?.frame ?? .zero
        return PanContainerView(presentedView: presentedViewController.view, frame: frame)
    }()

    /**
     Determine anchored Y postion based on the `anchorModalToLongForm` flag
     */
    var anchoredYPosition: CGFloat {
        let defaultTopOffset = presentable?.topOffset ?? 0
        return anchorModalToLongForm ? longFormYPosition : defaultTopOffset
    }

    /**
     Configuration object for PanModalPresentationController
     */
    var presentable: PanModalPresentable? {
        return presentedViewController as? PanModalPresentable
    }

    public override var frameOfPresentedViewInContainerView: CGRect {

        guard let bounds = containerView?.bounds,
              let layoutPresentable = presentedViewController as? PanModalPresentable.LayoutType
        else {  assertionFailure("containerView should be not nil")
            return .zero }

        print("frame")

        shortFormYPosition = layoutPresentable.shortFormYPos
        longFormYPosition = layoutPresentable.longFormYPos
        anchorModalToLongForm = layoutPresentable.anchorModalToLongForm
        extendsPanScrolling = layoutPresentable.allowsExtendedPanScrolling

        driver?.updateLayout(controller: self)

        return CGRect(x: 0, y: anchoredYPosition,
                      width: bounds.width, height: bounds.height)
    }

    func setNeedsLayoutUpdate() {
        driver?.updateLayout(controller: self)
        driver?.transition(to: .shortForm)
    }

    public override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        guard let presentedView = presentedView else {
            assertionFailure("presentedView should be not nil")
            return
        }
        containerView?.addSubview(presentedView)
    }

    public override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
        driver?.transition(to: .shortForm)
        
        if presentable?.shouldRoundTopCorners ?? false {
            self.addRoundedCorners(to: self.presentedView ?? UIView())
        }
        //adjustPanContainerBackgroundColor()
    }

    public override func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)


        if completed {
            assert(driver != nil)
            driver?.direction = .dismiss
            driver?.transition(to: .shortForm)
            
        }
    }

    func adjustPanContainerBackgroundColor() {
        panContainerView.backgroundColor = presentedViewController.view.backgroundColor
            ?? presentable?.panScrollable?.backgroundColor
    }

    var driver: TransitionDriverProtocol?
}

extension PanModalPresentationController {
    /**
     Operations on the scroll view, such as content height changes,
     or when inserting/deleting rows can cause the pan modal to jump,
     caused by the pan modal responding to content offset changes.

     To avoid this, you can call this method to perform scroll view updates,
     with scroll observation temporarily disabled.
     */
    func performUpdates(_ updates: () -> Void) {

        driver?.performUpdates(updates)
    }
}



// MARK: - UIBezierPath

private extension PanModalPresentationController {

    /**
     Draws top rounded corners on a given view
     We have to set a custom path for corner rounding
     because we render the dragIndicator outside of view bounds
     */
    func addRoundedCorners(to view: UIView) {
        let radius = presentable?.cornerRadius ?? 0
        let path = UIBezierPath(roundedRect: view.bounds,
                                byRoundingCorners: [.topLeft, .topRight],
                                cornerRadii: CGSize(width: radius, height: radius))

        // Draw around the drag indicator view, if displayed
        if presentable?.showDragIndicator == true {
            let indicatorLeftEdgeXPos = view.bounds.width/2.0 - Constants.dragIndicatorSize.width/2.0
            drawAroundDragIndicator(currentPath: path, indicatorLeftEdgeXPos: indicatorLeftEdgeXPos)
        }

        // Set path as a mask to display optional drag indicator view & rounded corners
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        view.layer.mask = mask

        // Improve performance by rasterizing the layer
        view.layer.shouldRasterize = true
        view.layer.rasterizationScale = UIScreen.main.scale
    }

    /**
     Draws a path around the drag indicator view
     */
    func drawAroundDragIndicator(currentPath path: UIBezierPath, indicatorLeftEdgeXPos: CGFloat) {

        let totalIndicatorOffset = Constants.indicatorYOffset + Constants.dragIndicatorSize.height

        // Draw around drag indicator starting from the left
        path.addLine(to: CGPoint(x: indicatorLeftEdgeXPos, y: path.currentPoint.y))
        path.addLine(to: CGPoint(x: path.currentPoint.x, y: path.currentPoint.y - totalIndicatorOffset))
        path.addLine(to: CGPoint(x: path.currentPoint.x + Constants.dragIndicatorSize.width, y: path.currentPoint.y))
        path.addLine(to: CGPoint(x: path.currentPoint.x, y: path.currentPoint.y + totalIndicatorOffset))
    }
}
