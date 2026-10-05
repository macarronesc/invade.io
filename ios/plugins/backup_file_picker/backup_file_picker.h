#pragma once

#include "core/object/object.h"
#include "core/string/ustring.h"

#ifdef __OBJC__
@class GodotBackupPicker;
#else
class GodotBackupPicker;
#endif

class BackupFilePicker : public Object {
	GDCLASS(BackupFilePicker, Object);

	static void _bind_methods();
	GodotBackupPicker *_picker = nullptr;

public:
	void pick_open(const String &destination_path);
	void pick_export(const String &source_path);
	void picker_file_selected(const String &path);
	void picker_exported();
	void picker_canceled();
	void picker_failed();

	BackupFilePicker();
	~BackupFilePicker();
};
