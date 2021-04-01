//
//  HudViewController.swift
//  ParrotDemo
//
//  Created by ian timmis on 7/18/19.
//  Copyright © 2019 RIIS. All rights reserved.
//

import UIKit
import GroundSdk
import TensorFlowLite
import CoreLocation

class HudViewController: UIViewController {
    
    private let groundSdk = GroundSdk()
    
    @IBOutlet weak var takeoffLandButton: UIButton!
    @IBOutlet weak var streamView: StreamView!
    @IBOutlet weak var overlayView: OverlayView!
    @IBOutlet weak var count: UILabel!
    
    private var drone: Drone?
    private var streamServerRef: Ref<StreamServer>?
    private var liveStreamRef: Ref<CameraLive>?
    private var gpsRef: Ref<Gps>?
    private var altRef: Ref<Altimeter>?
    private var gimRef: Ref<Gimbal>?
    
    private var modelDataHandler: ModelDataHandler =
    ModelDataHandler(modelFileInfo: MobileNetSSD.modelInfo, labelsFileInfo: MobileNetSSD.labelsInfo)!
    
    private let displayFont = UIFont.systemFont(ofSize: 6.0, weight: .medium)
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    
    private var alive: Bool = true
    
    let handButtonImage = UIImage(named: "ic_flight_hand_48pt")
    
    private var pilotingItf: Ref<ManualCopterPilotingItf>?

    /**
     Responds to the view loading. We setup landscape orientation here.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        let value = UIInterfaceOrientation.landscapeRight.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        takeoffLandButton.isHidden = false
        takeoffLandButton.setImage(handButtonImage, for: .normal)
    }

    override func viewDidDisappear(_ animated: Bool) {
        alive = false
        super.viewDidDisappear(true)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    /**
     View will appear. We get the drone and setup the interfaces to it. If
     the drone disconnects, we push back to the home viewcontroller.
     */
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        navigationController?.setNavigationBarHidden(true, animated: true)
        alive = true
        if let drone = drone {
            initDroneRefs(drone)
            monitorGps()
        } else {
            dismiss(self)
        }
    }
    
    func setDrone(_ drone: Drone) {
        self.drone = drone
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.landscapeRight, .landscapeRight]
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    /**
     Sends us back to the home viewcontroller.
     
     - Parameter sender: the caller fo this function.
     */
    @IBAction func dismiss(_ sender: Any) {
        alive = false
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    /**
     Initializes the interfaces to our drone. In this case, we only setup the manual
     piloting interface, but in the future we could add additional interfaces here.
     (Such as follow me, automated flight, etc.)
     
     - Parameter drone: The drone we are connected to
     */
    private func initDroneRefs(_ drone: Drone) {
        pilotingItf = drone.getPilotingItf(PilotingItfs.manualCopter) { [unowned self] pilotingItf in
            takeoffLandButton.isHidden = false
            takeoffLandButton.setImage(handButtonImage, for: .normal)
        }
        
        // Monitor the stream server.
        streamServerRef = drone.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
            // Called when the stream server is available and when it changes.
            if let self = self, let streamServer = streamServer {
                // Enable Streaming
                streamServer.enabled = true
                self.liveStreamRef = streamServer.live { liveStream in
                    // Called when the live stream is available and when it changes.
                    if let liveStream = liveStream {
                        // Set the live stream as the stream to be render by the stream view.
                        self.streamView.setStream(stream: liveStream)
                        // Play the live stream.
                        _ = liveStream.play()
                        self.captureImage()
                    }
                }
            }
        }
    }
}

// Handle Image processing and the overlay
extension HudViewController {

    func captureImage() {
        // captures the current frame of the video feed as an image
        let fps = 1.0
        let seconds = 1.0 / fps
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if self.alive {
                self.runInference(self.streamView.snapshot)
                self.captureImage()
            }
        }
    }
    
    func runInference(_ image:UIImage) {
        let pixelBuffer:CVPixelBuffer = image.pixelBuffer()!
        
        // Get time
        let curr = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let currTime: String = formatter.string(from: curr) // 10:48:53 PM
        
        guard let inferences = self.modelDataHandler.runModel(onFrame: pixelBuffer)?.inferences else {
            return
        }
        if(inferences.count > 0) {
            var nc: Int = Int(count.text ?? "0") ?? 0
            nc+=1
            count.text = String(nc)
            let loc: CLLocation? = gpsRef?.value?.lastKnownLocation
//            let angle: Double? = gimRef?.value?.currentAttitude[GimbalAxis.pitch]
//            let altitude: Double? = altRef?.value?.groundRelativeAltitude
            detections.append(Detection(location: loc!, img: image, time: currTime, maxConf: 0))
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        DispatchQueue.main.async {
            // Draws the bounding boxes and displays class names and confidence scores.
            self.drawDetections(onInferences: inferences, withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
        }
    }
    
    private func monitorGps() {
        // Monitor the battery info instrument.
        gpsRef = drone?.getInstrument(Instruments.gps) { gps in
//            if let gps = gps {
//                // Update drone battery level view.
//                print(gps.lastKnownLocation)
//            }
        }
        altRef = drone?.getInstrument(Instruments.altimeter) { altimeter in
//            if let altimeter = altimeter {
//                // Update drone battery level view.
//                print(altimeter.groundRelativeAltitude)
//            }
        }
        gimRef = drone?.getPeripheral(Peripherals.gimbal) { gimbal in
//            if let gimbal = gimbal {
//                // Update drone battery level view.
//                print(gimbal.currentAttitude)
//            }
        }
    }
    
    func drawDetections(onInferences inferences: [Inference], withImageSize imageSize:CGSize) {
       self.overlayView.objectOverlays = []
       self.overlayView.setNeedsDisplay()

       guard !inferences.isEmpty else {
         return
       }

       var objectOverlays: [ObjectOverlay] = []

       for inference in inferences {

         // Translates bounding box rect to current view.
         var convertedRect = inference.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))

         if convertedRect.origin.x < 0 {
           convertedRect.origin.x = self.edgeOffset
         }

         if convertedRect.origin.y < 0 {
           convertedRect.origin.y = self.edgeOffset
         }

         if convertedRect.maxY > self.overlayView.bounds.maxY {
           convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
         }

         if convertedRect.maxX > self.overlayView.bounds.maxX {
           convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
         }

         let confidenceValue = Int(inference.confidence * 100.0)
         let string = "\(inference.className)  (\(confidenceValue)%)"

         let size = string.size(usingFont: self.displayFont)

         let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: size, color: inference.displayColor, font: self.displayFont)

         objectOverlays.append(objectOverlay)
       }

       // Hands off drawing to the OverlayView
       self.draw(objectOverlays: objectOverlays)

     }

     /** Calls methods to update overlay view with detected bounding boxes and class names.
      */
     func draw(objectOverlays: [ObjectOverlay]) {
       self.overlayView.objectOverlays = objectOverlays
       self.overlayView.setNeedsDisplay()
     }
}
