//
//  PanModalPresentationController.swift
//  PanModal
//
//  Copyright © 2019 Tiny Speck, Inc. All rights reserved.
//

#if os(iOS)
import UIKit

/**
 The PanModalPresentationController is the middle layer between the presentingViewController
 and the presentedViewController.

 It controls the coordination between the individual transition classes as well as
 provides an abstraction over how the presented view is presented & displayed.

 For example, we add a drag indicator view above the presented view and
 a background overlay between the presenting & presented view.

 The presented view's layout configuration & presentation is defined using the PanModalPresentable.

 By conforming to the PanModalPresentable protocol & overriding values
 the presented view can define its layout configuration & presentation.
 */
open class PanModalPresentationController: UIPresentationController {

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
        return presentedViewController as? PanModalPresentable
    }

    var driver: PanModalDriver?

    // MARK: - Views

    /**
     Background view used as an overlay over the presenting view
     */
    private lazy var backgroundView: DimmedView = {
        let view: DimmedView
        if let color = presentable?.panModalBackgroundColor {
            view = DimmedView(dimColor: color)
        } else {
            view = DimmedView()
        }
        view.didTap = { [weak self] _ in
            if self?.presentable?.allowsTapToDismiss == true {
                self?.driver?.handleTap()
            }
        }
        return view
    }()

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
     Drag Indicator View
     */
    private lazy var dragIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = presentable?.dragIndicatorBackgroundColor
        view.layer.cornerRadius = Constants.dragIndicatorSize.height / 2.0
        return view
    }()

    /**
     Override presented view to return the pan container wrapper
     */
    public override var presentedView: UIView {
        return panContainerView
    }

    // MARK: - Deinitializers

    deinit {
        scrollObserver?.invalidate()
    }

    // MARK: - Lifecycle

    override public func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        configureViewLayout()
    }

    override public func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()

        guard let containerView = containerView
        else { return }

        layoutBackgroundView(in: containerView)
        layoutPresentedView(in: containerView)
        configureScrollViewInsets()

        guard let coordinator = presentedViewController.transitionCoordinator else {
            backgroundView.dimState = .max
            return
        }

        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.backgroundView.dimState = .max
                // self?.presentedViewController.setNeedsStatusBarAppearanceUpdate()
        })
    }

    override public func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        if completed {
            driver?.direction = .dismiss
            return
        }

        backgroundView.removeFromSuperview()
    }

    override public func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        presentable?.panModalWillDismiss()

        guard let coordinator = presentedViewController.transitionCoordinator else {
            backgroundView.dimState = .off
            return
        }

        /**
         Drag indicator is drawn outside of view bounds
         so hiding it on view dismiss means avoiding visual bugs
         */
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.dragIndicatorView.alpha = 0.0
            self?.backgroundView.dimState = .off
            //self?.presentingViewController.setNeedsStatusBarAppearanceUpdate()
        })
    }

    override public func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        if !completed { return }

        presentable?.panModalDidDismiss()
    }

    /**
     Update presented view size in response to size class changes
     */
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard
                let self = self,
                let presentable = self.presentable
            else { return }

            self.adjustPresentedViewFrame()
            if presentable.shouldRoundTopCorners {
                //self.addRoundedCorners(to: self.presentedView)
            }
        })
    }

}

// MARK: - Public Methods

public extension PanModalPresentationController {

    /**
     Operations on the scroll view, such as content height changes,
     or when inserting/deleting rows can cause the pan modal to jump,
     caused by the pan modal responding to content offset changes.

     To avoid this, you can call this method to perform scroll view updates,
     with scroll observation temporarily disabled.
     */
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

    /**
     Updates the PanModalPresentationController layout
     based on values in the PanModalPresentable

     - Note: This should be called whenever any
     pan modal presentable value changes after the initial presentation
     */
    func setNeedsLayoutUpdate() {
        configureViewLayout()
        adjustPresentedViewFrame()
        observe(scrollView: presentable?.panScrollable)
        configureScrollViewInsets()
    }

}

// MARK: - Presented View Layout Configuration

private extension PanModalPresentationController {

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

    /**
     Adds the presented view to the given container view
     & configures the view elements such as drag indicator, rounded corners
     based on the pan modal presentable.
     */
    func layoutPresentedView(in containerView: UIView) {

        /**
         If the presented view controller does not conform to pan modal presentable
         don't configure
         */
        guard let presentable = presentable
        else { return }

        /**
         ⚠️ If this class is NOT used in conjunction with the PanModalPresentationAnimator
         & PanModalPresentable, the presented view should be added to the container view
         in the presentation animator instead of here
         */
        containerView.addSubview(presentedView)


        setNeedsLayoutUpdate()
        adjustPanContainerBackgroundColor()

        if presentable.showDragIndicator {
            addDragIndicatorView(to: presentedView)
        }

        if presentable.shouldRoundTopCorners {
            addRoundedCorners(to: presentedView)
        }

        driver?.add(backgroundView: backgroundView, presentedView: presentedView, containerView: containerView)
    }

    /**
     Reduce height of presentedView so that it sits at the bottom of the screen
     */
    func adjustPresentedViewFrame() {

        guard let frame = containerView?.frame
        else { return }

        let adjustedSize = CGSize(width: frame.size.width, height: frame.size.height - anchoredYPosition)
        let panFrame = panContainerView.frame
        panContainerView.frame.size = frame.size

        if ![shortFormYPosition, longFormYPosition].contains(panFrame.origin.y) {
            // if the container is already in the correct position, no need to adjust positioning
            // (rotations & size changes cause positioning to be out of sync)
            let yPosition = panFrame.origin.y - panFrame.height + frame.height
            presentedView.frame.origin.y = max(yPosition, anchoredYPosition)
        }
        panContainerView.frame.origin.x = frame.origin.x
        presentedViewController.view.frame = CGRect(origin: .zero, size: adjustedSize)
    }

    /**
     Adds a background color to the pan container view
     in order to avoid a gap at the bottom
     during initial view presentation in longForm (when view bounces)
     */
    func adjustPanContainerBackgroundColor() {
        panContainerView.backgroundColor = presentedViewController.view.backgroundColor
            ?? presentable?.panScrollable?.backgroundColor
    }

    /**
     Adds the background view to the view hierarchy
     & configures its layout constraints.
     */
    func layoutBackgroundView(in containerView: UIView) {
        containerView.addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        backgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        backgroundView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        backgroundView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
    }

    /**
     Adds the drag indicator view to the view hierarchy
     & configures its layout constraints.
     */
    func addDragIndicatorView(to view: UIView) {
        view.addSubview(dragIndicatorView)
        dragIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        dragIndicatorView.bottomAnchor.constraint(equalTo: view.topAnchor, constant: Constants.indicatorYOffset).isActive = true
        dragIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        dragIndicatorView.widthAnchor.constraint(equalToConstant: Constants.dragIndicatorSize.width).isActive = true
        dragIndicatorView.heightAnchor.constraint(equalToConstant: Constants.dragIndicatorSize.height).isActive = true
    }

    /**
     Calculates & stores the layout anchor points & options
     */
    func configureViewLayout() {

        guard let layoutPresentable = presentedViewController as? PanModalPresentable.LayoutType
        else { return }

        shortFormYPosition = layoutPresentable.shortFormYPos
        longFormYPosition = layoutPresentable.longFormYPos
        anchorModalToLongForm = layoutPresentable.anchorModalToLongForm
        extendsPanScrolling = layoutPresentable.allowsExtendedPanScrolling

       // containerView?.isUserInteractionEnabled = layoutPresentable.isUserInteractionEnabled
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
        scrollView.contentInset.bottom = presentingViewController.bottomLayoutGuide.length
    }

}

// MARK: - UIScrollView Observer

private extension PanModalPresentationController {

    /**
     Creates & stores an observer on the given scroll view's content offset.
     This allows us to track scrolling without overriding the scrollView delegate
     */
    func observe(scrollView: UIScrollView?) {
        scrollObserver?.invalidate()
        scrollObserver = scrollView?.observe(\.contentOffset, options: .old) { [weak self] scrollView, change in

            /**
             Incase we have a situation where we have two containerViews in the same presentation
             */
            guard self?.containerView != nil
            else { return }

            self?.didPanOnScrollView(scrollView, change: change)
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

        guard
            !presentedViewController.isBeingDismissed,
            !presentedViewController.isBeingPresented
        else { return }

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

        } else if presentedViewController.view.isKind(of: UIScrollView.self)
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
        let presentedSize = containerView?.frame.size ?? .zero

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

            driver?.snap(toYPosition: longFormYPosition - yOffset)
            //presentedView.frame.origin.y = longFormYPosition - yOffset
        } else {
            scrollViewYOffset = 0
            driver?.snap(toYPosition: longFormYPosition)
            
            guard presentedView.frame.origin.y > shortFormYPosition else {
                backgroundView.dimState = .max
                return
            }

            let yDisplacementFromShortForm = presentedView.frame.origin.y - shortFormYPosition
            backgroundView.dimState = .percent(1.0 - (yDisplacementFromShortForm / presentedView.frame.height))
        }

        scrollView.showsVerticalScrollIndicator = false
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

// MARK: - Helper Extensions

extension UIScrollView {

    /**
     A flag to determine if a scroll view is scrolling
     */
    var isScrolling: Bool {
        return isDragging && !isDecelerating || isTracking
    }
}
#endif
