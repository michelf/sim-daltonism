
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

#import "VisionPicker.h"
#import "SimDaltonismFilter.h"

@implementation VisionPicker

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDefaults) name:NSUserDefaultsDidChangeNotification object:nil];

	[self performSelector:@selector(scrollCurrentChoiceToVisible) withObject:nil afterDelay:0.0];
}
- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateDefaults {
	[self.tableView reloadData];
}

- (void)scrollCurrentChoiceToVisible {
	NSInteger currentVisionType = [[NSUserDefaults standardUserDefaults] integerForKey:SimVisionTypeKey];

	UITableView *tableView = self.tableView;
	NSInteger sectionCount = tableView.numberOfSections;
	for (NSInteger section = 0; section < sectionCount; ++section) {
		NSInteger rowCount = [tableView numberOfRowsInSection:section];
		for (NSInteger row = 0; row < rowCount; ++row) {
			NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
			if ([self tableView:tableView cellForRowAtIndexPath:indexPath].tag == currentVisionType) {
				NSIndexPath *sectionIndexPath = [NSIndexPath indexPathForRow:rowCount-1 inSection:section];
				[tableView scrollToRowAtIndexPath:sectionIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
				return;
			}
		}
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

	NSInteger currentVisionType = [[NSUserDefaults standardUserDefaults] integerForKey:SimVisionTypeKey];
	if (cell.tag == currentVisionType) {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	} else {
		cell.accessoryType = UITableViewCellAccessoryNone;
	}

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSInteger currentVisionType = cell.tag;
	[[NSUserDefaults standardUserDefaults] setInteger:currentVisionType forKey:SimVisionTypeKey];

	// Move the checkmark before animation
	for (UITableViewCell *cell in tableView.visibleCells) {
		if (cell.tag == currentVisionType) {
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		} else {
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
	}

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self.navigationController popViewControllerAnimated:YES];
}

@end
