//
//  NMS.swift
//  ObjectDetection
//
//  Created by Nathaniel Friedman on 2/24/21.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import Foundation
import Accelerate

public struct BoundingBox {
  /** Index of the predicted class. */
  public let classIndex: Int

  /** Confidence score. */
  public let score: Float

  /** Normalized coordinates between 0 and 1. */
  public let rect: CGRect

  public init(classIndex: Int, score: Float, rect: CGRect) {
    self.classIndex = classIndex
    self.score = score
    self.rect = rect
  }
}

/**
  Computes intersection-over-union overlap between two bounding boxes.
*/
public func IOU(_ a: CGRect, _ b: CGRect) -> Float {
  let areaA = a.width * a.height
  if areaA <= 0 { return 0 }

  let areaB = b.width * b.height
  if areaB <= 0 { return 0 }

  let intersectionMinX = max(a.minX, b.minX)
  let intersectionMinY = max(a.minY, b.minY)
  let intersectionMaxX = min(a.maxX, b.maxX)
  let intersectionMaxY = min(a.maxY, b.maxY)
  let intersectionArea = max(intersectionMaxY - intersectionMinY, 0) *
                         max(intersectionMaxX - intersectionMinX, 0)
  return Float(intersectionArea / (areaA + areaB - intersectionArea))
}

public func nms(boundingBox: [Float], outputClasses: [Float], outputScores: [Float], outputCount: Int) -> ([Float], [Float], [Float]) {
    var bb: [BoundingBox] = []
    for i in 0..<outputCount {
        var rect: CGRect = CGRect.zero

        // Translates the detected bounding box to CGRect.
        rect.origin.x = CGFloat(boundingBox[4*i])
        rect.origin.y = CGFloat(boundingBox[4*i+1])
        rect.size.width = CGFloat(boundingBox[4*i+2])
        rect.size.height = CGFloat(boundingBox[4*i+3])
        bb.append(BoundingBox(classIndex: 0, score: outputScores[i], rect: rect))
    }
    let ind: [Int] = nonMaxSuppression(boundingBoxes: bb, iouThreshold: 0.45, maxBoxes: 30000)
    var boxes: [Float] = []
    for i in ind {
        boxes.append(boundingBox[i*4])
        boxes.append(boundingBox[i*4 + 1])
        boxes.append(boundingBox[i*4 + 2])
        boxes.append(boundingBox[i*4 + 3])
    }
    let cls: [Float] = ind.map {outputClasses[$0]}
    let scores: [Float] = ind.map {outputScores[$0]}
    return (boxes, cls, scores)
}

/**
  Removes bounding boxes that overlap too much with other boxes that have
  a higher score.
*/
public func nonMaxSuppression(boundingBoxes: [BoundingBox],
                              iouThreshold: Float,
                              maxBoxes: Int) -> [Int] {
  return nonMaxSuppression(boundingBoxes: boundingBoxes,
                           indices: Array(boundingBoxes.indices),
                           iouThreshold: iouThreshold,
                           maxBoxes: maxBoxes)
}

/**
  Removes bounding boxes that overlap too much with other boxes that have
  a higher score.
  Based on code from https://github.com/tensorflow/tensorflow/blob/master/tensorflow/core/kernels/non_max_suppression_op.cc
  - Note: This version of NMS ignores the class of the bounding boxes. Since it
    selects the bounding boxes in a greedy fashion, if a certain class has many
    boxes that are selected, then it is possible none of the boxes of the other
    classes get selected.
  - Parameters:
    - boundingBoxes: an array of bounding boxes and their scores
    - indices: which predictions to look at
    - iouThreshold: used to decide whether boxes overlap too much
    - maxBoxes: the maximum number of boxes that will be selected
  - Returns: the array indices of the selected bounding boxes
*/
public func nonMaxSuppression(boundingBoxes: [BoundingBox],
                              indices: [Int],
                              iouThreshold: Float,
                              maxBoxes: Int) -> [Int] {

  // Sort the boxes based on their confidence scores, from high to low.
  let sortedIndices = indices.sorted { boundingBoxes[$0].score > boundingBoxes[$1].score }

  var selected: [Int] = []

  // Loop through the bounding boxes, from highest score to lowest score,
  // and determine whether or not to keep each box.
  for i in 0..<sortedIndices.count {
    if selected.count >= maxBoxes { break }

    var shouldSelect = true
    let boxA = boundingBoxes[sortedIndices[i]]

    // Does the current box overlap one of the selected boxes more than the
    // given threshold amount? Then it's too similar, so don't keep it.
    for j in 0..<selected.count {
      let boxB = boundingBoxes[selected[j]]
      if IOU(boxA.rect, boxB.rect) > iouThreshold {
        shouldSelect = false
        break
      }
    }

    // This bounding box did not overlap too much with any previously selected
    // bounding box, so we'll keep it.
    if shouldSelect {
      selected.append(sortedIndices[i])
    }
  }

  return selected
}
