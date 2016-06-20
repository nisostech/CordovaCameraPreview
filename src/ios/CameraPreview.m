#import <AssetsLibrary/AssetsLibrary.h>
#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>

#import "CameraPreview.h"

@implementation CameraPreview

- (void) startCamera:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera already started!"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    if (command.arguments.count > 3) {
        CGFloat x = (CGFloat)[command.arguments[0] floatValue] + self.webView.frame.origin.x;
        CGFloat y = (CGFloat)[command.arguments[1] floatValue] + self.webView.frame.origin.y+18;
        CGFloat width = (CGFloat)[command.arguments[2] floatValue];
        CGFloat height = (CGFloat)[command.arguments[3] floatValue];
        NSString *defaultCamera = command.arguments[4];
        BOOL tapToTakePicture = (BOOL)[command.arguments[5] boolValue];
        BOOL dragEnabled = (BOOL)[command.arguments[6] boolValue];
        BOOL toBack = (BOOL)[command.arguments[7] boolValue];
                            // Create the session manager
        self.sessionManager = [[CameraSessionManager alloc] init];

            //render controller setup
        self.cameraRenderController = [[CameraRenderController alloc] init];
        self.cameraRenderController.dragEnabled = dragEnabled;
        self.cameraRenderController.tapToTakePicture = tapToTakePicture;
        self.cameraRenderController.sessionManager = self.sessionManager;
        NSLog(@"setting rect %f %f %f %f ",x,y,width,height);
        self.cameraRenderController.view.frame = CGRectMake(x, y, width, height);
        self.cameraRenderController.delegate = self;

        [self.viewController addChildViewController:self.cameraRenderController];
            //display the camera bellow the webview
        if (toBack) {
                //make transparent
            self.webView.opaque = NO;
            self.webView.backgroundColor = [UIColor clearColor];
            NSLog(@"setting cameraRenderController at 0");
            [self.viewController.view insertSubview:self.cameraRenderController.view atIndex:0];
        }
        else{
            self.cameraRenderController.view.alpha = (CGFloat)[command.arguments[8] floatValue];

            [self.viewController.view addSubview:self.cameraRenderController.view];
        }

            // Setup session
        self.sessionManager.delegate = self.cameraRenderController;
        [self.sessionManager setupSession:defaultCamera];

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid number of parameters"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) stopCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"stopCamera");
    CDVPluginResult *pluginResult;

    if(self.sessionManager != nil) {
        [self.cameraRenderController.view removeFromSuperview];
        [self.cameraRenderController removeFromParentViewController];
        self.cameraRenderController = nil;

        [self.sessionManager.session stopRunning];
        self.sessionManager = nil;

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) hideCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"hideCamera");
    CDVPluginResult *pluginResult;

    if (self.cameraRenderController != nil) {
        [self.cameraRenderController.view setHidden:YES];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) showCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"showCamera");
    CDVPluginResult *pluginResult;

    if (self.cameraRenderController != nil) {
        [self.cameraRenderController.view setHidden:NO];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) switchCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"switchCamera");
    CDVPluginResult *pluginResult;

    if (self.sessionManager != nil) {
        [self.sessionManager switchCamera];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) takePicture:(CDVInvokedUrlCommand*)command {
    NSLog(@"takePicture");
    CDVPluginResult *pluginResult;

    if (self.cameraRenderController != NULL) {
        CGFloat maxW = (CGFloat)[command.arguments[0] floatValue];
        CGFloat maxH = (CGFloat)[command.arguments[1] floatValue];
        [self invokeTakePicture:maxW withHeight:maxH];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) setOnPictureTakenHandler:(CDVInvokedUrlCommand*)command {
    NSLog(@"setOnPictureTakenHandler");
    self.onPictureTakenHandlerId = command.callbackId;
}

-(void) setColorEffect:(CDVInvokedUrlCommand*)command {
    NSLog(@"setColorEffect");
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    NSString *filterName = command.arguments[0];

    if ([filterName isEqual: @"none"]) {
        dispatch_async(self.sessionManager.sessionQueue, ^{
            [self.sessionManager setCiFilter:nil];
        });
    } else if ([filterName isEqual: @"mono"]) {
        dispatch_async(self.sessionManager.sessionQueue, ^{
            CIFilter *filter = [CIFilter filterWithName:@"CIColorMonochrome"];
            [filter setDefaults];
            [self.sessionManager setCiFilter:filter];
        });
    } else if ([filterName isEqual: @"negative"]) {
        dispatch_async(self.sessionManager.sessionQueue, ^{
            CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
            [filter setDefaults];
            [self.sessionManager setCiFilter:filter];
        });
    } else if ([filterName isEqual: @"posterize"]) {
        dispatch_async(self.sessionManager.sessionQueue, ^{
            CIFilter *filter = [CIFilter filterWithName:@"CIColorPosterize"];
            [filter setDefaults];
            [self.sessionManager setCiFilter:filter];
        });
    } else if ([filterName isEqual: @"sepia"]) {
        dispatch_async(self.sessionManager.sessionQueue, ^{
            CIFilter *filter = [CIFilter filterWithName:@"CISepiaTone"];
            [filter setDefaults];
            [self.sessionManager setCiFilter:filter];
        });
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Filter not found"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
- (void) invokeTakePicture {
    [self invokeTakePicture:0.0 withHeight:0.0];
}
- (void) invokeTakePicture:(CGFloat) maxWidth withHeight:(CGFloat) maxHeight {
    AVCaptureConnection *connection = [self.sessionManager.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    [self.sessionManager.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef sampleBuffer, NSError *error) {

        NSLog(@"Done creating still image");

        if (error) {
            NSLog(@"%@", error);
        } else {
            [self.cameraRenderController.renderLock lock];
            CIImage *previewCImage = self.cameraRenderController.latestFrame;
            CGImageRef previewImage = [self.cameraRenderController.ciContext createCGImage:previewCImage fromRect:previewCImage.extent];
            [self.cameraRenderController.renderLock unlock];

            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:sampleBuffer];
            UIImage *capturedImage  = [[UIImage alloc] initWithData:imageData];

            CIImage *capturedCImage;
                //image resize

            if(maxWidth > 0 && maxHeight > 0) {
                CGFloat scaleHeight = maxWidth/capturedImage.size.height;
                CGFloat scaleWidth = maxHeight/capturedImage.size.width;
                CGFloat scale = scaleHeight > scaleWidth ? scaleWidth : scaleHeight;

                CIFilter *resizeFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
                [resizeFilter setValue:[[CIImage alloc] initWithCGImage:[capturedImage CGImage]] forKey:kCIInputImageKey];
                [resizeFilter setValue:[NSNumber numberWithFloat:1.0f] forKey:@"inputAspectRatio"];
                [resizeFilter setValue:[NSNumber numberWithFloat:scale] forKey:@"inputScale"];
                capturedCImage = [resizeFilter outputImage];
            }
            else{
                capturedCImage = [[CIImage alloc] initWithCGImage:[capturedImage CGImage]];
            }

            CIImage *imageToFilter;
            CIImage *finalCImage;

                //fix front mirroring
            if (self.sessionManager.defaultCamera == AVCaptureDevicePositionFront) {
                CGAffineTransform matrix = CGAffineTransformTranslate(CGAffineTransformMakeScale(1, -1), 0, capturedCImage.extent.size.height);
                CGAffineTransform matrix2 = CGAffineTransformTranslate(CGAffineTransformMakeRotation(90*(M_PI/180)), 0, capturedCImage.extent.size.height);

                imageToFilter = [capturedCImage imageByApplyingTransform:CGAffineTransformConcat(matrix, matrix2)];

            } else {
                imageToFilter = capturedCImage;
            }

            CIFilter *filter = [self.sessionManager ciFilter];
            if (filter != nil) {
                [self.sessionManager.filterLock lock];
                [filter setValue:imageToFilter forKey:kCIInputImageKey];
                finalCImage = [filter outputImage];
                [self.sessionManager.filterLock unlock];
            } else {
                finalCImage = imageToFilter;
            }
                // NSLog(@" photo image w %f h %f", CGImageGetWidth(finalCImage),CGImageGetHeight(finalCImage));

            CGImageRef finalImage = [self.cameraRenderController.ciContext createCGImage:finalCImage fromRect:finalCImage.extent];
            CGSize imageSize = [[UIScreen mainScreen] bounds].size;
            UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            UIGraphicsPushContext(context);
            CGContextDrawImage(context, self.cameraRenderController.view.frame, finalImage);
            UIGraphicsPopContext();
            [self renderView:self.webView inContext:context];
            UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
            finalImage=[screenshot CGImage];

            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];

            dispatch_group_t group = dispatch_group_create();

            __block NSString *originalPicturePath;
            __block NSString *previewPicturePath;
            __block NSError *photosAlbumError;

            ALAssetOrientation orientation;
            switch ([[UIApplication sharedApplication] statusBarOrientation]) {
                case UIDeviceOrientationPortraitUpsideDown:
                orientation = ALAssetOrientationLeft;
                break;
                case UIDeviceOrientationLandscapeLeft:
                orientation = ALAssetOrientationUp;
                break;
                case UIDeviceOrientationLandscapeRight:
                orientation = ALAssetOrientationDown;
                break;
                case UIDeviceOrientationPortrait:
                default:
                orientation = ALAssetOrientationRight;
            }

                // task 1
            /* dispatch_group_enter(group);
             [library writeImageToSavedPhotosAlbum:previewImage orientation:ALAssetOrientationUp completionBlock:^(NSURL *assetURL, NSError *error) {
             if (error) {
             NSLog(@"FAILED to save Preview picture.");
             photosAlbumError = error;
             } else {
             previewPicturePath = [assetURL absoluteString];
             NSLog(@"previewPicturePath: %@", previewPicturePath);
             }
             dispatch_group_leave(group);
             }];
             */
                //task 2
            dispatch_group_enter(group);
            [library writeImageToSavedPhotosAlbum:finalImage orientation:ALAssetOrientationUp  completionBlock:^(NSURL *assetURL, NSError *error) {
                if (error) {
                    NSLog(@"FAILED to save Original picture.");
                    photosAlbumError = error;
                } else {
                    originalPicturePath = [assetURL absoluteString];
                    NSLog(@"originalPicturePath: %@", originalPicturePath);
                }
                dispatch_group_leave(group);
            }];

            dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                NSMutableArray *params = [[NSMutableArray alloc] init];
                if (photosAlbumError) {
                        // Error returns just one element in the returned array
                    NSString * remedy = @"";
                    if (-3311 == [photosAlbumError code]) {
                        remedy = @"Go to Settings > CodeStudio and allow access to Photos";
                    }
                    [params addObject:[NSString stringWithFormat:@"CameraPreview: %@ - %@ — %@", [photosAlbumError localizedDescription], [photosAlbumError localizedFailureReason], remedy]];
                } else {
                        // Success returns two elements in the returned array
                    NSLog(@"originalPicturePath %@",originalPicturePath);
                    [params addObject:@"to adjust with Android"];
                    [params addObject:originalPicturePath];
                        //[params addObject:previewPicturePath];
                }
                NSLog(@"pluginResult %@ ",params);
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:params];
                [pluginResult setKeepCallbackAsBool:true];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
            });
        }
    }];
}

- (void)renderView:(UIView*)view inContext:(CGContextRef)context
{
        //////////////////////////////////////////////////////////////////////////////////////
        //																					//
        // This works like a charm when you have multiple views that need to be rendered	//
        // in a UIView when one of those views is an OpenGL CALayer view or a camera stream	//
        // or some other view that will not work with - (UIImage*)screenshot, as defined 	//
        // in Technical Q&A QA1703, "Screen Capture in UIKit Applications".					//
        //																					//
        //////////////////////////////////////////////////////////////////////////////////////


        //
        // -renderInContext: renders in the coordinate space of the layer,
        // so we must first apply the layer's geometry to the graphics context.
        //
    CGContextSaveGState(context);


        //
        // Center the context around the window's anchor point.
        //
    CGContextTranslateCTM(context, [view center].x, [view center].y);


        //
        // Apply the window's transform about the anchor point.
        //
    CGContextConcatCTM(context, [view transform]);


        //
        // Offset by the portion of the bounds left of and above the anchor point.
        //
    CGContextTranslateCTM(context,
                          -[view bounds].size.width * [[view layer] anchorPoint].x,
                          -[view bounds].size.height * [[view layer] anchorPoint].y);


        //
        // Render the layer hierarchy to the current context.
        //
    [[view layer] renderInContext:context];


        //
        // Restore the context. BTW, you're done.
        //
    CGContextRestoreGState(context);
}


@end
