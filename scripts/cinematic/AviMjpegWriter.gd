class_name AviMjpegWriter
extends RefCounted
## Minimal AVI (RIFF) writer for Motion-JPEG video, no external tools needed.
## Plays in VLC, Windows Media Player / Films & TV, QuickTime-compatible players
## and imports into DaVinci Resolve, Premiere, Shotcut, etc.
##
## Layout: RIFF 'AVI ' { LIST 'hdrl' { avih, LIST 'strl' { strh, strf } },
##         LIST 'movi' { '00dc' JPEG frames }, idx1 }
## Header sizes and frame counts are patched in [method close].

const MAX_FILE_BYTES := 4_000_000_000  # RIFF size fields are 32-bit

var _file: FileAccess
var _width := 0
var _height := 0
var _fps := 30
var _frames := 0
var _max_frame_bytes := 0
var _index := PackedByteArray()

# Byte offsets of fields patched on close.
var _riff_size_pos := 0
var _avih_total_frames_pos := 0
var _avih_buffer_pos := 0
var _avih_max_bytes_pos := 0
var _strh_length_pos := 0
var _strh_buffer_pos := 0
var _movi_size_pos := 0
var _movi_fourcc_pos := 0


func open(path: String, width: int, height: int, fps: int) -> Error:
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		return FileAccess.get_open_error()
	_width = width
	_height = height
	_fps = maxi(fps, 1)
	_file.big_endian = false

	_fourcc("RIFF")
	_riff_size_pos = _file.get_position()
	_file.store_32(0)
	_fourcc("AVI ")

	# LIST hdrl = 4 ('hdrl') + avih chunk (8+56) + LIST strl (8 + 4 + strh (8+56) + strf (8+40))
	_fourcc("LIST")
	_file.store_32(4 + (8 + 56) + (8 + 4 + (8 + 56) + (8 + 40)))
	_fourcc("hdrl")

	_fourcc("avih")
	_file.store_32(56)
	_file.store_32(int(1_000_000 / _fps))     # microseconds per frame
	_avih_max_bytes_pos = _file.get_position()
	_file.store_32(0)                          # max bytes per second (patched)
	_file.store_32(0)                          # padding granularity
	_file.store_32(0x10)                       # AVIF_HASINDEX
	_avih_total_frames_pos = _file.get_position()
	_file.store_32(0)                          # total frames (patched)
	_file.store_32(0)                          # initial frames
	_file.store_32(1)                          # streams
	_avih_buffer_pos = _file.get_position()
	_file.store_32(0)                          # suggested buffer size (patched)
	_file.store_32(_width)
	_file.store_32(_height)
	for i in 4:
		_file.store_32(0)                      # reserved

	_fourcc("LIST")
	_file.store_32(4 + (8 + 56) + (8 + 40))
	_fourcc("strl")

	_fourcc("strh")
	_file.store_32(56)
	_fourcc("vids")
	_fourcc("MJPG")
	_file.store_32(0)                          # flags
	_file.store_16(0)                          # priority
	_file.store_16(0)                          # language
	_file.store_32(0)                          # initial frames
	_file.store_32(1)                          # scale
	_file.store_32(_fps)                       # rate  (fps = rate / scale)
	_file.store_32(0)                          # start
	_strh_length_pos = _file.get_position()
	_file.store_32(0)                          # length in frames (patched)
	_strh_buffer_pos = _file.get_position()
	_file.store_32(0)                          # suggested buffer size (patched)
	_file.store_32(0xFFFFFFFF)                 # quality (-1 = default)
	_file.store_32(0)                          # sample size
	_file.store_16(0)                          # rcFrame
	_file.store_16(0)
	_file.store_16(_width)
	_file.store_16(_height)

	_fourcc("strf")
	_file.store_32(40)                         # BITMAPINFOHEADER
	_file.store_32(40)
	_file.store_32(_width)
	_file.store_32(_height)
	_file.store_16(1)                          # planes
	_file.store_16(24)                         # bit count
	_fourcc("MJPG")
	_file.store_32(_width * _height * 3)       # image size
	_file.store_32(0)
	_file.store_32(0)
	_file.store_32(0)
	_file.store_32(0)

	_fourcc("LIST")
	_movi_size_pos = _file.get_position()
	_file.store_32(0)                          # movi size (patched)
	_movi_fourcc_pos = _file.get_position()
	_fourcc("movi")
	return OK


## Appends one JPEG-encoded frame.
func add_frame(jpeg: PackedByteArray) -> Error:
	if _file == null:
		return ERR_UNCONFIGURED
	var size := jpeg.size()
	if _file.get_position() + size + 8 + (_frames + 1) * 16 > MAX_FILE_BYTES:
		return ERR_OUT_OF_MEMORY
	var chunk_pos := _file.get_position()
	_fourcc("00dc")
	_file.store_32(size)
	_file.store_buffer(jpeg)
	if size % 2 == 1:
		_file.store_8(0)                       # chunks are word-aligned

	var entry := StreamPeerBuffer.new()
	entry.big_endian = false
	entry.put_data("00dc".to_ascii_buffer())
	entry.put_u32(0x10)                        # AVIIF_KEYFRAME
	entry.put_u32(chunk_pos - _movi_fourcc_pos)
	entry.put_u32(size)
	_index.append_array(entry.data_array)

	_frames += 1
	_max_frame_bytes = maxi(_max_frame_bytes, size)
	return OK


func frame_count() -> int:
	return _frames


func close() -> Error:
	if _file == null:
		return ERR_UNCONFIGURED
	var movi_end := _file.get_position()
	_fourcc("idx1")
	_file.store_32(_index.size())
	_file.store_buffer(_index)
	var file_end := _file.get_position()

	_patch(_riff_size_pos, file_end - 8)
	_patch(_movi_size_pos, movi_end - _movi_fourcc_pos)
	_patch(_avih_total_frames_pos, _frames)
	_patch(_strh_length_pos, _frames)
	_patch(_avih_buffer_pos, _max_frame_bytes + 8)
	_patch(_strh_buffer_pos, _max_frame_bytes + 8)
	_patch(_avih_max_bytes_pos, (_max_frame_bytes + 8) * _fps)

	var err := _file.get_error()
	_file.close()
	_file = null
	return err if err != ERR_FILE_EOF else OK


func _fourcc(code: String) -> void:
	_file.store_buffer(code.to_ascii_buffer())


func _patch(position: int, value: int) -> void:
	var back := _file.get_position()
	_file.seek(position)
	_file.store_32(value)
	_file.seek(back)
