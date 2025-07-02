//
//  PoseDetectionModule.m
//  react-native-mediapipe
//
//  Created by Charles Parker on 3/24/24.
//

#import <Foundation/Foundation.h>
#import "React/RCTBridgeModule.h"
#import "React/RCTEventEmitter.h"

@interface RCT_EXTERN_REMAP_MODULE(PoseDetectionVideo, PoseDetectionModule, RCTEventEmitter)
RCT_EXTERN_METHOD(
                  createDetector:(NSInteger)numPoses
                  withMinPoseDetectionConfidence:(nonnull NSNumber *)minPoseDetectionConfidence
                  withMinPosePresenceConfidence:(nonnull NSNumber *)minPosePresenceConfidence
                  withMinTrackingConfidence:(nonnull NSNumber *)minTrackingConfidence
                  withShouldOutputSegmentationMasks:(BOOL)shouldOutputSegmentationMasks
                  withModel:(nonnull NSString *)model
                  withDelegate:(NSInteger)delegate
                  withRunningMode:(NSInteger)runningMode
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  )

RCT_EXTERN_METHOD(releaseDetector:(NSInteger)handle
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  )

RCT_EXTERN_METHOD(detectOnImage:(nonnull NSString *)imagePath
                  withNumPoses:(NSInteger)numPoses
                  withMinPoseDetectionConfidence:(nonnull NSNumber *)minPoseDetectionConfidence
                  withMinPosePresenceConfidence:(nonnull NSNumber *)minPosePresenceConfidence
                  withMinTrackingConfidence:(nonnull NSNumber *)minTrackingConfidence
                  withShouldOutputSegmentationMasks:(BOOL)shouldOutputSegmentationMasks
                  withModel:(nonnull NSString *)model
                  withDelegate:(NSInteger)delegate
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  )

RCT_EXTERN_METHOD(detectPoseOnVideo:(nonnull NSString *)videoPath
                  withFps:(nonnull NSNumber *)fps
                  withNumPoses:(NSInteger)numPoses
                  withOptions:(nonnull NSDictionary *)options
                  withModel:(nonnull NSString *)model
                  withDelegate:(NSInteger)delegate
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  )
@end

