//
//  FullScreenNavController.swift
//  PanModalDemo
//
//  Created by Stephen Sowole on 5/2/19.
//  Copyright © 2019 Detail. All rights reserved.
//

import UIKit

class FullScreenNavController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        pushViewController(FullScreenViewController(), animated: false)
    }
}

extension FullScreenNavController: PanModalPresentable {

    var panScrollable: UIScrollView? {
        nil
    }

    var topOffset: CGFloat {
        0.0
    }

    var animationMode: AnimationMode {
        .cubicBezier(controlPoint1: CGPoint(x: 0.41, y: 0.18), controlPoint2: CGPoint(x: 0.14, y: 1))
    }

    var springDamping: CGFloat {
        0.8
    }

    var springDampingFullScreen: CGFloat {
        1.0
    }
    
    var transitionAnimationOptions: UIView.AnimationOptions {
        [.allowUserInteraction, .beginFromCurrentState]
    }

    var shouldRoundTopCorners: Bool {
        false
    }

    var showDragIndicator: Bool {
        false
    }
}

private class FullScreenViewController: UIViewController {

    let textLabel: UILabel = {
        let label = UILabel()
        label.text = "Drag downwards to dismiss"
        label.font = UIFont(name: "Lato-Bold", size: 17)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Full Screen"
        view.backgroundColor = .white
        setupConstraints()
    }

    private func setupConstraints() {
        view.addSubview(textLabel)
        textLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        textLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }

}
