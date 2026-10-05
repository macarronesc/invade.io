#include "backup_file_picker.h"

#include "core/config/engine.h"
#include "core/object/class_db.h"

#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface GodotBackupPicker : NSObject <UIDocumentPickerDelegate>
@property(nonatomic, assign) BackupFilePicker *owner;
@property(nonatomic, copy) NSString *path;
@property(nonatomic, assign) BOOL exporting;
- (void)pickOpen:(NSString *)path;
- (void)pickExport:(NSString *)path;
@end

@implementation GodotBackupPicker

- (void)present:(UIDocumentPickerViewController *)picker {
	UIViewController *presenter = UIApplication.sharedApplication.windows.firstObject.rootViewController;
	while (presenter.presentedViewController) {
		presenter = presenter.presentedViewController;
	}
	if (!presenter) {
		self.owner->picker_failed();
		return;
	}
	picker.delegate = self;
	[presenter presentViewController:picker animated:YES completion:nil];
}

- (void)pickOpen:(NSString *)path {
	self.path = path;
	self.exporting = NO;
	UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
		initForOpeningContentTypes:@[UTTypeJSON] asCopy:YES];
	[self present:picker];
}

- (void)pickExport:(NSString *)path {
	self.path = path;
	self.exporting = YES;
	NSURL *url = [NSURL fileURLWithPath:path];
	UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
		initForExportingURLs:@[url] asCopy:YES];
	[self present:picker];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	if (urls.count == 0) {
		self.owner->picker_failed();
		return;
	}
	if (self.exporting) {
		self.owner->picker_exported();
		return;
	}

	NSURL *source = urls[0];
	BOOL scoped = [source startAccessingSecurityScopedResource];
	NSURL *destination = [NSURL fileURLWithPath:self.path];
	NSFileManager *manager = NSFileManager.defaultManager;
	[manager removeItemAtURL:destination error:nil];
	NSError *error = nil;
	BOOL copied = [manager copyItemAtURL:source toURL:destination error:&error];
	if (scoped) {
		[source stopAccessingSecurityScopedResource];
	}
	if (copied) {
		self.owner->picker_file_selected(String(destination.path.UTF8String));
	} else {
		self.owner->picker_failed();
	}
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
	self.owner->picker_canceled();
}

@end

static BackupFilePicker *backup_file_picker = nullptr;

void BackupFilePicker::_bind_methods() {
	ClassDB::bind_method(D_METHOD("pick_open", "destination_path"), &BackupFilePicker::pick_open);
	ClassDB::bind_method(D_METHOD("pick_export", "source_path"), &BackupFilePicker::pick_export);
	ADD_SIGNAL(MethodInfo("file_selected", PropertyInfo(Variant::STRING, "path")));
	ADD_SIGNAL(MethodInfo("exported"));
	ADD_SIGNAL(MethodInfo("canceled"));
	ADD_SIGNAL(MethodInfo("failed"));
}

BackupFilePicker::BackupFilePicker() {
	_picker = [[GodotBackupPicker alloc] init];
	_picker.owner = this;
}

BackupFilePicker::~BackupFilePicker() {
	_picker = nil;
}

void BackupFilePicker::pick_open(const String &destination_path) {
	_picker.path = [NSString stringWithUTF8String:destination_path.utf8().get_data()];
	[_picker pickOpen:_picker.path];
}

void BackupFilePicker::pick_export(const String &source_path) {
	_picker.path = [NSString stringWithUTF8String:source_path.utf8().get_data()];
	[_picker pickExport:_picker.path];
}

void BackupFilePicker::picker_file_selected(const String &path) {
	emit_signal("file_selected", path);
}

void BackupFilePicker::picker_exported() {
	emit_signal("exported");
}

void BackupFilePicker::picker_canceled() {
	emit_signal("canceled");
}

void BackupFilePicker::picker_failed() {
	emit_signal("failed");
}

extern "C" __attribute__((visibility("default"))) void backup_file_picker_init() {
	ClassDB::register_class<BackupFilePicker>();
	backup_file_picker = memnew(BackupFilePicker);
	Engine::get_singleton()->add_singleton(Engine::Singleton("BackupFilePicker", backup_file_picker));
}

extern "C" __attribute__((visibility("default"))) void backup_file_picker_deinit() {
	if (backup_file_picker) {
		Engine::get_singleton()->remove_singleton("BackupFilePicker");
		memdelete(backup_file_picker);
		backup_file_picker = nullptr;
	}
}
