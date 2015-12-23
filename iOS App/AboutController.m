
//	Copyright 2015 Michel Fortin
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
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://michelf.ca/"]];
	} else if (cell == self.feedbackCell) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:sim-daltonism@michelf.ca"]];
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1 && indexPath.row == 0) {
		CGSize availableSize = CGSizeMake(tableView.bounds.size.width, 100000);
		return [self.aboutCell sizeThatFits:availableSize].height;
	}
	if (indexPath.section == 3 && indexPath.row == 0) {
		CGSize availableSize = CGSizeMake(tableView.bounds.size.width, 100000);
		return [self.creditsCell sizeThatFits:availableSize].height;
	}
	return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

@end
