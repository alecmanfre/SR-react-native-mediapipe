//
//  PoseDetectionModule.swift
//  react-native-mediapipe
//
//  Created by Charles Parker on 3/24/24.
//

import Foundation
import MediaPipeTasksVision
import React
import AVFoundation

@objc(PoseDetectionModule)
class PoseDetectionModule: RCTEventEmitter {
  private static var nextId = 22  // Equivalent to Kotlin's starting point
  static var detectorMap = [Int: PoseDetectorHelper]()  // Maps to the Kotlin detectorMap

  override func supportedEvents() -> [String]! {
    return ["onResults", "onError"]
  }

  @objc override func constantsToExport() -> [AnyHashable: Any] {
    return [:]
  }

  @objc override static func requiresMainQueueSetup() -> Bool {
    return false
  }

  @objc func createDetector(
    _ numPoses: NSInteger,
    withMinPoseDetectionConfidence minPoseDetectionConfidence: NSNumber,
    withMinPosePresenceConfidence minPosePresenceConfidence: NSNumber,
    withMinTrackingConfidence minTrackingConfidence: NSNumber,
    withShouldOutputSegmentationMasks shouldOutputSegmentationMasks: Bool,
    withModel model: String,
    withDelegate delegate: NSInteger,
    withRunningMode runningMode: NSInteger,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    let id = PoseDetectionModule.nextId
    PoseDetectionModule.nextId += 1

    // Convert runningMode to RunningMode enum
    guard let mode = RunningMode(rawValue: UInt(runningMode)) else {
      reject("E_MODE_ERROR", "Invalid running mode", nil)
      return
    }

    do {
      let helper = try PoseDetectorHelper(
        handle: id,
        numPoses: numPoses,
        minPoseDetectionConfidence: minPoseDetectionConfidence.floatValue,
        minPosePresenceConfidence: minPosePresenceConfidence.floatValue,
        minTrackingConfidence: minTrackingConfidence.floatValue,
        shouldOutputSegmentationMasks: shouldOutputSegmentationMasks,
        modelName: model,
        delegate: delegate,
        runningMode: mode)
      helper.liveStreamDelegate = self  // Assuming `self` conforms to `PoseDetectorHelperDelegate`

      PoseDetectionModule.detectorMap[id] = helper
      resolve(id)
    } catch let error as NSError {
      // If an error is thrown, reject the promise
      // You can customize the error code and message as needed
      reject("ERROR_CODE", "An error occurred: \(error.localizedDescription)", error)
    }
  }

  @objc func releaseDetector(
    _ handle: NSInteger,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    if let helper = PoseDetectionModule.detectorMap.removeValue(forKey: handle) {
      // Clean up on main thread to avoid threading issues
      DispatchQueue.main.async {
        helper.cleanup()
        resolve(true)
      }
    } else {
      resolve(false)
    }
  }

  @objc func detectOnImage(
    _ imagePath: String,
    withNumPoses numPoses: NSInteger,
    withMinPoseDetectionConfidence minPoseDetectionConfidence: NSNumber,
    withMinPosePresenceConfidence minPosePresenceConfidence: NSNumber,
    withMinTrackingConfidence minTrackingConfidence: NSNumber,
    withShouldOutputSegmentationMasks shouldOutputSegmentationMasks: Bool,
    withModel model: String,
    withDelegate delegate: NSInteger,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    do {
      let helper = try PoseDetectorHelper(
        handle: 0,
        numPoses: numPoses,
        minPoseDetectionConfidence: minPoseDetectionConfidence.floatValue,
        minPosePresenceConfidence: minPosePresenceConfidence.floatValue,
        minTrackingConfidence: minTrackingConfidence.floatValue,
        shouldOutputSegmentationMasks: shouldOutputSegmentationMasks,
        modelName: model,
        delegate: delegate, runningMode: RunningMode.image)
      helper.liveStreamDelegate = self  // Assuming `self` conforms to `PoseDetectorHelperDelegate`

      // convert path to UIImage
      let image = try loadImageFromPath(from: imagePath)
      if let result = helper.detect(image: image) {
        let resultArgs = convertPdResultBundleToDictionary(result)
        resolve(resultArgs)
      } else {
        throw NSError(
          domain: "com.PoseDetection.error", code: 1001,
          userInfo: [NSLocalizedDescriptionKey: "Detection failed."])
      }
    } catch let error as NSError {
      // If an error is thrown, reject the promise
      // You can customize the error code and message as needed
      reject("ERROR_CODE", "An error occurred: \(error.localizedDescription)", error)
    }
  }

  @objc func detectPoseOnVideo(
    _ videoPath: String,
    withFps fps: NSNumber,
    withNumPoses numPoses: NSInteger,
    withOptions options: NSDictionary,
    withModel model: String,
    withDelegate delegate: NSInteger,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    // Extract options from the dictionary
    let minPoseDetectionConfidence = options["minPoseDetectionConfidence"] as? NSNumber ?? 0.5
    let minPosePresenceConfidence = options["minPosePresenceConfidence"] as? NSNumber ?? 0.5
    let minTrackingConfidence = options["minTrackingConfidence"] as? NSNumber ?? 0.5
    let shouldOutputSegmentationMasks = options["shouldOutputSegmentationMasks"] as? Bool ?? false
    
    // 1. Open the video file using AVAsset
    let url = URL(fileURLWithPath: videoPath)
    let asset = AVAsset(url: url)
    let duration = asset.duration
    let durationSeconds = CMTimeGetSeconds(duration)
    let fpsValue = fps.doubleValue > 0 ? fps.doubleValue : 30.0
    let frameInterval = 1.0 / fpsValue

    // 2. Set up AVAssetImageGenerator to extract frames
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    imageGenerator.requestedTimeToleranceAfter = .zero
    imageGenerator.requestedTimeToleranceBefore = .zero

    // 3. Prepare times for frame extraction
    var times = [NSValue]()
    var currentTime = 0.0
    while currentTime < durationSeconds {
      let cmTime = CMTimeMakeWithSeconds(currentTime, preferredTimescale: 600)
      times.append(NSValue(time: cmTime))
      currentTime += frameInterval
    }

    // 4. Run on background queue
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        // Prepare pose detector helper in video mode
        let helper = try PoseDetectorHelper(
          handle: 0,
          numPoses: numPoses,
          minPoseDetectionConfidence: minPoseDetectionConfidence.floatValue,
          minPosePresenceConfidence: minPosePresenceConfidence.floatValue,
          minTrackingConfidence: minTrackingConfidence.floatValue,
          shouldOutputSegmentationMasks: shouldOutputSegmentationMasks,
          modelName: model,
          delegate: delegate,
          runningMode: .video
        )
        var results: [[String: Any]] = []
        for (i, timeValue) in times.enumerated() {
          let time = timeValue.timeValue
          do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            // Run pose detection in video mode using MediaPipe's detect method
            let timestampMs = Int(CMTimeGetSeconds(time) * 1000)
            let mpImage = try MPImage(uiImage: uiImage)
            if let result = try helper.poseLandmarker?.detect(videoFrame: mpImage, timestampInMilliseconds: timestampMs) {
              var dict = convertPdResultBundleToDictionary(PoseDetectionResultBundle(
                inferenceTime: 0, // We can calculate this if needed
                poseDetectorResults: [result],
                size: uiImage.size
              ))
              dict["frameIndex"] = i
              dict["timestampMs"] = timestampMs
              results.append(dict)
            } else {
              results.append(["frameIndex": i, "timestampMs": timestampMs, "error": "No result"])
            }
          } catch let error {
            results.append(["frameIndex": i, "timestampMs": Int64(CMTimeGetSeconds(time) * 1000), "error": error.localizedDescription])
          }
        }
        resolve(results)
      } catch let error as NSError {
        reject("ERROR_CODE", "An error occurred: \(error.localizedDescription)", error)
      }
    }
  }

  // MARK: Event Emission Helpers
  private func sendErrorEvent(handle: Int, message: String, code: Int) {
    self.sendEvent(withName: "onError", body: ["handle": handle, "message": message, "code": code])
  }

  private func sendResultsEvent(handle: Int, bundle: PoseDetectionResultBundle) {
    // Assuming convertResultBundleToDictionary exists and converts ResultBundle to a suitable dictionary
    var resultArgs = convertPdResultBundleToDictionary(bundle)
    resultArgs["handle"] = handle
    self.sendEvent(withName: "onResults", body: resultArgs)
  }
}

extension PoseDetectionModule: PoseDetectorHelperLiveStreamDelegate {
  func poseDetectorHelper(
    _ PoseDetectorHelper: PoseDetectorHelper,
    onResults result: PoseDetectionResultBundle?,
    error: Error?
  ) {
    if let result = result {
      sendResultsEvent(handle: PoseDetectorHelper.handle, bundle: result)
    } else if let error = error as? NSError {
      sendErrorEvent(
        handle: PoseDetectorHelper.handle, message: error.localizedDescription,
        code: error.code)
    }
  }
}
