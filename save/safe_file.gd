class_name SafeFile
extends RefCounted
## Crash-safe file writes: data goes to "<path>.tmp" first and is renamed over
## the target only after it was fully written, so a crash mid-save leaves the
## previous version intact. Thread-safe as long as callers do not write the
## same path concurrently (ChunkStorage serializes its writes).

const TMP_SUFFIX := ".tmp"


static func write_bytes(path: String, bytes: PackedByteArray) -> Error:
	var tmp := path + TMP_SUFFIX
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	var err := file.get_error()
	file.close()
	if err != OK:
		return err
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK and FileAccess.file_exists(path):
		# Some platforms refuse to rename over an existing file.
		DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp, path)
	return err


static func write_text(path: String, text: String) -> Error:
	return write_bytes(path, text.to_utf8_buffer())


## Returns empty bytes when the file does not exist. Falls back to a leftover
## .tmp if the real file is missing (crash between remove and rename).
static func read_bytes(path: String) -> PackedByteArray:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_bytes(path)
	if FileAccess.file_exists(path + TMP_SUFFIX):
		return FileAccess.get_file_as_bytes(path + TMP_SUFFIX)
	return PackedByteArray()


static func read_text(path: String) -> String:
	return read_bytes(path).get_string_from_utf8()


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + TMP_SUFFIX)
