module iconv

// Module iconv provides functions convert between vstring(UTF8) to/from different encodings.

#include <iconv.h>
#flag darwin -liconv

fn C.iconv_open(tocode &u8, fromcode &u8) voidptr
fn C.iconv_close(cd voidptr) int
fn C.iconv(cd voidptr, inbuf &&u8, inbytesleft &usize, outbuf &&u8, outbytesleft &usize) usize

// conv convert `fromcode` encoding string to `tocode` encoding string
@[direct_array_access]
fn conv(tocode string, fromcode string, src &u8, src_len int) ![]u8 {
	if src_len < 0 {
		return error('src length error')
	}

	mut src_encoding := fromcode.to_upper()
	mut dst_encoding := tocode.to_upper()

	// As macos-12 has no UTF16LE/UTF16BE/UTF32LE/UTF32BE, change them to UTF-16LE/UTF-16BE/UTF-32LE/UTF-32BE
	match src_encoding {
		'UTF16LE' { src_encoding = 'UTF-16LE' }
		'UTF16BE' { src_encoding = 'UTF-16BE' }
		'UTF32LE' { src_encoding = 'UTF-32LE' }
		'UTF32BE' { src_encoding = 'UTF-32BE' }
		else {}
	}
	match dst_encoding {
		'UTF16LE' { dst_encoding = 'UTF-16LE' }
		'UTF16BE' { dst_encoding = 'UTF-16BE' }
		'UTF32LE' { dst_encoding = 'UTF-32LE' }
		'UTF32BE' { dst_encoding = 'UTF-32BE' }
		else {}
	}

	mut cd := C.iconv_open(dst_encoding.str, src_encoding.str)
	if isize(cd) == -1 {
		return error('platform can\'t convert from ${src_encoding} to ${dst_encoding}')
	}
	defer { C.iconv_close(cd) }

	mut dst := []u8{len: (src_len + 1) * 4} // this should be enough to hold the dst encoding string

	mut src_ptr := &u8(src)
	mut dst_ptr := &u8(dst.data)
	mut src_left := usize(src_len)
	mut dst_left := usize(dst.len)
	res := C.iconv(cd, &src_ptr, &src_left, &dst_ptr, &dst_left)
	if res == usize(-1) {
		return error('convert encoding string fail, iconv return ${res}')
	}

	// resize dst buf to real length
	dst.trim(dst.len - int(dst_left))
	return dst
}
