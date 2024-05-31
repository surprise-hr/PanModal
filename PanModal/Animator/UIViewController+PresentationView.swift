//
//  File.swift
//  
//
//  Created by Volodymyr Hanas on 31.05.2024.
//

import UIKit

private var presentationViewAssociatedValue = malloc(1)!

extension UIViewController {
    weak var presentationView: UIView? {
        get {
            objc_getAssociatedObject(self, &presentationViewAssociatedValue) as? UIView
        }
        set {
            objc_setAssociatedObject(self, &presentationViewAssociatedValue, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
}
