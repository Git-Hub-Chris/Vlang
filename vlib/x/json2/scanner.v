// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module json2

import strconv

struct Scanner {
	text     []byte
	pos      int
	cur_line int
	cur_col  int
}

enum TokenKind {
	none_
	error
	str
	float
	int_
	null
	true_
	false_
	eof
	comma = 44
	colon = 58
	lsbr = 91
	rsbr = 93
	lcbr = 123
	rcbr = 125
}

struct Error {
	description string
	line int
	col int
}

struct Token {
	lit  []byte
	kind TokenKind
	line int
	col  int
	errors []Token
}

const (
	char_list = [`{`, `}`, `[`, `]`, `,`, `:`]
	newlines = [`\r`, `\n`]
	num_indicators = [`-`, `+`]
	important_escapable_chars = [byte(9), byte(10), byte(0)]
	invalid_unicode_endpoints = [byte(9), byte(229)]
	valid_unicode_escapes = [`b`, `f`, `n`, `r`, `t`, `\\`, `"`, `/`]
	unicode_escapes = {
		98: `\b`
		102: `\f`
		110: `\n`
		114: `\r`
		116: `\t`
		92: `\\`
		34: `"`
		47: `/`
	}
)

fn (mut s Scanner) move_pos() {
	if s.pos + 1 < s.text.len && s.text[s.pos + 1] in json2.newlines {
		s.line++
		s.col = 0
		if s.pos + 2 < s.text.len && s.text[s.pos + 1] == `\r` && s.text[s.pos + 2] == `\n` {
			s.pos++
		}
	} else if s.text[s.pos] == ` ` {
		s.pos++
		s.col++
	} else {
		s.col++
	}
	s.pos++
}

fn (mut s Scanner) move_pos_upto(num int) {
	for i := 0; i < num; i++ {
		s.move_pos()
	}
}

fn (mut s Scanner) error(description string) Token {
	err := s.tokenize(description.bytes(), .error)
	s.errors << err
	return err
}

fn (s Scanner) tokenize(lit []byte, kind TokenKind) Token {
	return Token{
		lit: lit
		kind: kind
		col: s.cur_col
		line: s.cur_line
	}
}

fn (mut s Scanner) text_scan() Token {
	start_pos := s.pos + 1
	mut has_closed := false
	mut chrs := []byte{}
	for s.pos < s.text.len {
		s.move_pos()
		ch := s.text[s.pos]
		if ((s.pos - 1 >= 0 && s.text[s.pos - 1] != `/`) || s.pos == 0) && ch in json2.important_escapable_chars {
			return s.error('character must be escaped with a backslash')
		} else if s.pos == s.text.len - 1 && ch == `\\` {
			return s.error('invalid backslash escape')
		} else if s.pos + 1 < s.text.len && ch == `\\` {
			peek := s.text[s.pos + 1]
			if peek in json2.valid_unicode_escapes {
				chrs << unicode_escapes[int(peek)]
				s.move_pos()
				continue
			} else if peek == `u` {
				if s.pos + 5 < s.text.len {
					mut codepoint := []int{}
					s.move_pos_upto(2)
					codepoint_start := s.pos
					for s.pos < s.text.len && s.pos < codepoint_start + 3 {
						if !s.text[s.pos].is_hex_digit() {
							return s.error('`${s.text[s.pos]}` is not a hex digit')
						}
						codepoint << int(s.text[s.pos])
						s.move_pos()
					}
					if codepoint.len != 4 {
						return s.error('unicode escape must be 4 characters')
					}
					chrs << byte(strconv.parse_int(codepoint, 16, 0))
				} else {
					return s.error('incomplete unicode escape')
				}
			} else if peek == `U` {
				return s.error('unicode endpoints must be in lowercase `u`')
			} else if peek in json2.invalid_unicode_endpoints {
				return s.error('unicode endpoint not allowed')
			} else {
				return s.error('invalid backslash escape')
			}
		} else if ch == `"` {
			has_closed = true
			break
		}
		chrs << ch
	}
	if !has_closed {
		s.error('missing double-quote in string')
		return s.tokenize([]byte{}, .eof)
	}
	return s.tokenize(s.text[start_pos..s.pos], .str)
}

fn (mut s Scanner) parse_num() ?[]byte {
	mut digits := []byte{}
	for s.pos < s.text.len {
		if s.text[s.pos].is_digit() {
			digits << s.text[s.pos]
			s.move_pos()
		} else if s.text[s.pos] in [`.`, `e`, `E`] {
			break
		} else {
			return error('unknown token `${s.text[s.pos]}`')
		}
	}
	return digits
}

fn (mut s Scanner) scan() Token {
	if s.text[s.pos] in json2.char_list {
		tok := s.text[s.pos]
		s.move_pos()
		return s.tokenize([]byte{}, TokenKind(int(tok)))
	} else if s.text[s.pos] == `"` {
		return s.text_scan()
	} else if s.text[s.pos].is_digit() || s.text[s.pos] == `-` {
		// analyze json number structure
		// -[digit][?[dot][digit]][?[E/e][?-/+][digit]]
		mut is_fl := false
		mut has_exp := false
		mut digits := []byte{}

		is_minus := s.text[s.pos] == `-`
		start_pos := s.pos
		start_digit_pos := if is_minus { s.pos + 1 } else { s.pos }

		if is_minus {
			digits << `-`
			s.move_pos()
		}
		if !s.text[start_digit_pos].is_digit() {
			return s.error('invalid token `${s.text[start_digit_pos]}`')
		} else if s.text[start_digit_pos] == `0` && (start_digit_pos + 1 < s.text.len && s.text[start_digit_pos + 1].is_digit()) {
			return s.error('leading zeroes in integers are not allowed')
		}

		digits << s.parse_num() or {
			return s.error(err)
		}
		if s.text[s.pos] == `.` {
			is_fl = true
			digits << `.`
			s.move_pos()
			dec_digits := s.parse_num() or {
				return s.error(err)
			}
			digits << dec_digits
		} else if s.text[s.pos] !in [`.`, `e`, `E`] {
			return s.error('invalid token `${s.text[s.pos]}`')
		}
	} else if s.pos >= s.text.len {
		return s.tokenize([]byte{}, .eof)
	} else {
		return s.error('invalid token `${s.text[s.pos]}`')
	}
}
