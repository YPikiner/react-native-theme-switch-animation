
#import <UIKit/UIKit.h>

#import "ThemeSwitchAnimationModule.h"


@implementation ThemeSwitchAnimationModule
{
    UIImageView *overlayView;
    BOOL isAnimating;
}

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents {
    return @[@"FINISHED_FREEZING_SCREEN"];
}

RCT_EXPORT_METHOD(freezeScreen)
{
    if (!isAnimating) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *capturedScreen = [self captureScreen];
            self->isAnimating = YES;
            [self displayCapturedImageFullScreen:capturedScreen];
            [self triggerEvent];
        });
    }
}

- (void)triggerEvent {
    [self sendEventWithName:@"FINISHED_FREEZING_SCREEN" body:@{@"key": @"value"}];
}

RCT_EXPORT_METHOD(unfreezeScreen: (NSString*) type duration:(NSInteger) duration csRation:(CGFloat) cxRatio cyRation:(CGFloat) cyRatio)
{
    if (isAnimating) {
        void (^completionCallback)(void) = ^{
            NSLog(@"Animation Completed");
            self->isAnimating = false;
            self->overlayView.layer.mask = nil;
            self->overlayView.hidden = YES;
            [self->overlayView removeFromSuperview];
        };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([type isEqualToString:@"inverted-circular"]) {
                [self performInvertedCircleAnimation: self->overlayView duration:duration cxRatio:cxRatio cyRatio:cyRatio callback: completionCallback];
            } else {
                [self performFadeAnimation:duration callback: completionCallback];
            }
        });
    }
}

- (void)displayCapturedImageFullScreen:(UIImage *)image {
    overlayView = [[UIImageView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    overlayView.image = image;
    overlayView.contentMode = UIViewContentModeScaleAspectFill;
    [[UIApplication sharedApplication].keyWindow addSubview:overlayView];
}

- (UIImage *)captureScreen {
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    CGRect rect = [keyWindow bounds];
    UIGraphicsBeginImageContextWithOptions(rect.size,YES,0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [keyWindow.layer renderInContext:context];
    UIImage *capturedScreen = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return capturedScreen;
}

- (void)performFadeAnimation: (NSInteger) duration  callback: (void (^)(void))callback {
    [UIView animateWithDuration: duration / 1000
                     animations:^{
        self->overlayView.alpha = 0.0;
    }
                     completion:^(BOOL finished){
        if (callback) {
            callback();
        }
        [self->overlayView removeFromSuperview];
    }];
}

- (void)performInvertedCircleAnimation:(UIView *)overlayView
                              duration:(CFTimeInterval)duration
                               cxRatio:(CGFloat)cxRatio
                               cyRatio:(CGFloat)cyRatio
                              callback:(void (^)(void))callback {
    CGFloat width = CGRectGetWidth(overlayView.bounds);
    CGFloat height = CGRectGetHeight(overlayView.bounds);
    CGPoint center = CGPointMake(width * cxRatio, height * cyRatio);
    CGFloat startRadius = [self getPointMaxDistanceInsideContainerWithCx:center.x cy:center.y width:width height:height];
    
    
    UIBezierPath *startPath = [self generateCircule:startRadius center:center];
    UIBezierPath *endPath = [self generateCircule:0 center:center];
    
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = startPath.CGPath;
    overlayView.layer.mask = maskLayer;
    
    CABasicAnimation *maskLayerAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    maskLayerAnimation.fromValue = (__bridge id)(startPath.CGPath);
    maskLayerAnimation.toValue = (__bridge id)(endPath.CGPath);
    
    maskLayerAnimation.duration = duration / 1000;
    maskLayerAnimation.delegate = self;
    maskLayerAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    maskLayerAnimation.fillMode = kCAFillModeForwards;
    maskLayerAnimation.removedOnCompletion = NO;
    
    
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        if (callback) {
            callback();
        }
        maskLayerAnimation.delegate = nil;
    }];
    
    [maskLayer addAnimation:maskLayerAnimation forKey:@"path"];
    [CATransaction commit];
}

- (CGFloat)getPointMaxDistanceInsideContainerWithCx:(CGFloat)cx cy:(CGFloat)cy width:(CGFloat)width height:(CGFloat)height {
    CGFloat topLeftDistance = hypotf(cx, cy);
    CGFloat topRightDistance = hypotf(width - cx, cy);
    CGFloat bottomLeftDistance = hypotf(cx, height - cy);
    CGFloat bottomRightDistance = hypotf(width - cx, height - cy);
    return MAX(MAX(topLeftDistance, topRightDistance), MAX(bottomLeftDistance, bottomRightDistance));
}

- (UIBezierPath*) generateCircule: (CGFloat)radius center:(CGPoint)center {
    UIBezierPath *circule = [UIBezierPath bezierPathWithArcCenter:center
                                                           radius:radius == 0 ? 0.1 : radius // 0 produces weired animation
                                                       startAngle:0
                                                         endAngle:M_PI * 2
                                                        clockwise:YES];
    
    return circule;
}

@end
