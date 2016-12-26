
//	Copyright 2005-2016 Michel Fortin
//
//	Licensed under the Apache License, Version 2.0 (the "License");
//	you may not use this file except in compliance with the License.
//	You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
//	Unless required by applicable law or agreed to in writing, software
//	distributed under the License is distributed on an "AS IS" BASIS,
//	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//	See the License for the specific language governing permissions and
//	limitations under the License.

#import "AboutController.h"

@implementation AboutController

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if (cell == self.websiteCell) {
		[[UIApplication sharedApplication] openURL:self.localizedWebsiteURL];
	} else if (cell == self.feedbackCell) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@", self.localizedFeedbackEmailAddress]]];
	} else if (cell == self.appStoreCell) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://itunes.apple.com/us/app/sim-daltonism/id1050503579?ls=1&mt=8&at=11l78F&ct=SDapp&action=viewContentsUserReviews"]];
	} else if (cell == self.redStripeCell) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://itunes.apple.com/us/app/red-stripe/id997446505?ls=1&mt=8&at=11l78F&ct=SDapp"]];
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([indexPath isEqual:self.aboutIndexPath]) {
		CGSize availableSize = CGSizeMake(tableView.bounds.size.width, 100000);
		return [self.aboutCell sizeThatFits:availableSize].height;
	}
	if ([indexPath isEqual:self.creditsIndexPath]) {
		CGSize availableSize = CGSizeMake(tableView.bounds.size.width, 100000);
		return [self.creditsCell sizeThatFits:availableSize].height;
	}
	return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (NSIndexPath *)aboutIndexPath {
	return [NSIndexPath indexPathForRow:0 inSection:1];
}

- (NSIndexPath *)creditsIndexPath {
	return [NSIndexPath indexPathForRow:0 inSection:3];
}

- (NSURL *)localizedWebsiteURL {
	return [NSURL URLWithString:NSLocalizedStringFromTable(@"https://michelf.ca/projects/sim-daltonism/", @"URLs", @"Sim Daltonism website URL")];
}

- (NSString *)localizedFeedbackEmailAddress {
	return NSLocalizedStringFromTable(@"sim-daltonism@michelf.ca", @"URLs", @"Sim Daltonism feedback email");
}

@end
