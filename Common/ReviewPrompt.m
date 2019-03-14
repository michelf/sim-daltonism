#import "ReviewPrompt.h"
@import StoreKit;

@implementation ReviewPrompt

static NSString *const numberOfLaunchesKey = @"NumberOfLaunches";
static NSString *const firstLaunchDateKey = @"FirstLaunchDate";
static NSString *const lastDatePrompedForReviewKey = @"LastDatePromptedForReview";
static NSString *const lastVersionPrompedForReviewKey = @"LastVersionPromptedForReview";

+ (void)promptForReviewAfterDelay:(NSTimeInterval)delay minimumNumberOfLaunches:(NSInteger)launchThreshold minimumDaysSinceFirstLaunch:(NSInteger)daysSinceFirstLaunch minimumDaysSinceLastPrompt:(NSInteger)daysBetweenPrompts {
	if (@available(iOS 10.3, macOS 10.14, *)) {
#if TARGET_OS_IPHONE
#elif TARGET_OS_MAC
		// Mac: skip prompt if this app is not from the App Store
		NSURL *receiptURL = NSBundle.mainBundle.appStoreReceiptURL;
		if (!receiptURL || ![NSFileManager.defaultManager fileExistsAtPath:receiptURL.path]) {
			// not from the App Store, can't review
			return;
		}
#endif
		// set first launch date (if applicable)
		NSInteger firstLaunchDateInterval = [NSUserDefaults.standardUserDefaults doubleForKey:firstLaunchDateKey];
		if (firstLaunchDateInterval == 0) {
			[NSUserDefaults.standardUserDefaults setFloat:NSDate.date.timeIntervalSinceReferenceDate forKey:firstLaunchDateKey];
		}

		// increment number of launches
		NSInteger numberOfLaunches = [NSUserDefaults.standardUserDefaults integerForKey:numberOfLaunchesKey];
		numberOfLaunches += 1;
		[[NSUserDefaults standardUserDefaults] setInteger:numberOfLaunches forKey:numberOfLaunchesKey];

		// skip condition: number of launches too small
		if (numberOfLaunches < launchThreshold) {
			return; // don't ask for review before the choosen threshold
		}

		// skip condition: first launch date too close
		NSDate * firstLaunchDate = [NSDate dateWithTimeIntervalSinceReferenceDate:firstLaunchDateInterval];
		if (-firstLaunchDate.timeIntervalSinceNow < 60*60*24*daysSinceFirstLaunch) {
			return; // don't ask twice within a 1.5 year period
		}

		// skip condition: last date promped too close
		NSDate * lastDatePromptedForReview = [NSDate dateWithTimeIntervalSinceReferenceDate:[NSUserDefaults.standardUserDefaults doubleForKey:lastDatePrompedForReviewKey]];
		if (-lastDatePromptedForReview.timeIntervalSinceNow < 60*60*24*daysBetweenPrompts) {
			return;
		}

		// skip condition: same version as last prompt
		NSString * currentVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
		NSString * lastVersionPromptedForReview = [NSUserDefaults.standardUserDefaults stringForKey:lastVersionPrompedForReviewKey];
		if (currentVersion == nil) {
			return; // shouldn't happen
		}
		if ([lastVersionPromptedForReview isEqual:currentVersion]) {
			// already promped for this version
			return;
		}

		// prompt after a small delay
		[NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(_showReviewPrompt:) userInfo:currentVersion repeats:NO];
	}
}

+ (void)_showReviewPrompt:(NSTimer *)timer {
	if (@available(iOS 10.3, macOS 10.14, *)) {
		[SKStoreReviewController requestReview];
		// reset number of launches so we don't prompt immediatly after an update
		[NSUserDefaults.standardUserDefaults setInteger:0 forKey:numberOfLaunchesKey];
		[NSUserDefaults.standardUserDefaults setObject:timer.userInfo forKey:lastVersionPrompedForReviewKey];
		[NSUserDefaults.standardUserDefaults setFloat:NSDate.date.timeIntervalSinceReferenceDate forKey:lastDatePrompedForReviewKey];
	}
}

@end
