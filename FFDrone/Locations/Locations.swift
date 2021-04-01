//
//  Locations.swift
//  FFDrone
//
//  Created by Nathaniel Friedman on 3/23/21.
//  Copyright © 2021 Parrot. All rights reserved.
//
import Foundation
import CoreLocation
import UIKit

struct Detection {
    var location: CLLocation?
    var img: UIImage?
    var time: String
    var maxConf: Float
}

var detections: [Detection] = []
