//
//  MapViewController.swift
//  FFDrone
//
//  Created by Nathaniel Friedman on 3/23/21.
//  Copyright © 2021 Parrot. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class CardView: UIView {
    
    
    
}
class CustomPoint: MKPointAnnotation {
    var conf: Float?
    var time: String?
    var img: UIImage?
    
}
class MapViewController: UIViewController, MKMapViewDelegate {

    var locationManager = CLLocationManager()
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var cardView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set card properties
        cardView.layer.cornerRadius = 10
        cardView.layer.borderWidth = 1.0
        cardView.layer.borderColor = UIColor.black.cgColor
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 1, height: 1)
        cardView.layer.shadowOpacity = 0.7
        cardView.layer.shadowRadius = 4.0
        let btns = cardView.subviews.compactMap { $0 as? UIButton }
        for btn in btns {
            // Add action for enlarging image
        }
        

        // Get location and center
        locationManager.requestWhenInUseAuthorization()
        var currentLoc: CLLocation!
        if(CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways) {
            currentLoc = locationManager.location
            mapView.setCenter(currentLoc.coordinate, animated: false)
        }
        print("DETECTIONS \(detections.count)")
        // Add points
        for detection in detections {
            if let loc = detection.location?.coordinate {
                let annotation = CustomPoint()
                annotation.conf = detection.maxConf
                annotation.img = detection.img
                annotation.time = detection.time
                annotation.coordinate = loc
                mapView.addAnnotation(annotation)
            }
        }
        mapView.delegate = self
        // Do any additional setup after loading the view.
    }
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        let annotation: CustomPoint? = view.annotation as? CustomPoint
        guard let annot = annotation else {
            return
        }
        
        // Set Image
        let btns = cardView.subviews.compactMap { $0 as? UIButton }
        for btn in btns {
            btn.imageView?.contentMode = .scaleAspectFit
            btn.setImage(annot.img, for: .normal)
        }
        
        // Set Text
        let labels = cardView.subviews.compactMap { $0 as? UILabel }
        let txts = ["Max Confidence: \(annot.conf ?? 0)", String(format: "%.5f, %.5f", annot.coordinate.latitude, annot.coordinate.longitude), annot.time ?? "Unknown"]
        for (i, label) in labels.enumerated() {
            label.text = txts[i]
        }

        cardView.isHidden = false
    }

    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        cardView.isHidden = true
    }
}

