// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

fn test_add() {
	mut a := 'a'
	a += 'b'
	assert a==('ab')
	a = 'a'
	for i := 1; i < 1000; i++ {
		a += 'b'
	}
	assert a.len == 1000
	assert a.ends_with('bbbbb')
	a += '123'
	assert a.ends_with('3')
	mut foo := Foo{0, 'hi'}
	foo.str += '!'
	assert foo.str == 'hi!'
}

fn test_ends_with() {
	a := 'browser.v'
	assert a.ends_with('.v')
}

fn test_between() {
	 s := 'hello [man] how you doing'
	assert s.find_between('[', ']') == 'man'
}

fn test_compare() {
	a := 'Music'
	b := 'src'
	assert b>=(a)
}

fn test_lt() {
	a := ''
	b := 'a'
	c := 'a'
	d := 'b'
	e := 'aa'
	f := 'ab'
	assert a < (b)
	assert !(b < c)
	assert c < (d)
	assert !(d < e)
	assert c < (e)
	assert e < (f)
}

fn test_ge() {
	a := 'aa'
	b := 'aa'
	c := 'ab'
	d := 'abc'
	e := 'aaa'
	assert b >= (a)
	assert c >= (b)
	assert d >= (c)
	assert !(c >= d)
	assert e >= (a)
}

fn test_compare_strings() {
	a := 'aa'
	b := 'aa'
	c := 'ab'
	d := 'abc'
	e := 'aaa'
	assert compare_strings(a, b) == 0
	assert compare_strings(b, c) == -1
	assert compare_strings(c, d) == -1
	assert compare_strings(d, e) == 1
	assert compare_strings(a, e) == -1
	assert compare_strings(e, a) == 1
}

fn test_sort() {
	mut vals := [
		'arr', 'an', 'a', 'any'
	]
	len := vals.len
	vals.sort()
	assert len == vals.len
	assert vals[0] == 'a'
	assert vals[1] == 'an'
	assert vals[2] == 'any'
	assert vals[3] == 'arr'
}

fn test_split_nth() {
	a := "1,2,3"
	assert (a.split(',').len == 3)
	assert (a.split_nth(',', -1).len == 3)
	assert (a.split_nth(',', 0).len == 3)
	assert (a.split_nth(',', 1).len == 1)
	assert (a.split_nth(',', 2).len == 2)
	assert (a.split_nth(',', 10).len == 3)
	b := "1::2::3"
	assert (b.split('::').len == 3)
	assert (b.split_nth('::', -1).len == 3)
	assert (b.split_nth('::', 0).len == 3)
	assert (b.split_nth('::', 1).len == 1)
	assert (b.split_nth('::', 2).len == 2)
	assert (b.split_nth('::', 10).len == 3)
	c := "ABCDEF"
	assert (c.split('').len == 6)
	assert (c.split_nth('', 3).len == 3)
	assert (c.split_nth('BC', -1).len == 2)
	d := ","
	assert (d.split(',').len == 2)
	assert (d.split_nth('', 3).len == 1)
	assert (d.split_nth(',', -1).len == 2)
	assert (d.split_nth(',', 3).len == 2)
	e := ",,,0,,,,,a,,b,"
	// assert (e.split(',,').len == 5)
	// assert (e.split_nth(',,', 3).len == 2)
	assert (e.split_nth(',', -1).len == 12)
	assert (e.split_nth(',', 3).len == 3)
}

fn test_split_nth_values() {
	line := 'CMD=eprintln(phase=1)'

	a0 := line.split_nth('=', 0)
	assert a0.len == 3
	assert a0[0] == 'CMD'
	assert a0[1] == 'eprintln(phase'
	assert a0[2] == '1)'

	a1 := line.split_nth('=', 1)
	assert a1.len == 1
	assert a1[0] == 'CMD=eprintln(phase=1)'

	a2 := line.split_nth('=', 2)
	assert a2.len == 2
	assert a2[0] == 'CMD'
	assert a2[1] == 'eprintln(phase=1)'

	a3 := line.split_nth('=', 3)
	assert a3.len == 3
	assert a3[0] == 'CMD'
	assert a3[1] == 'eprintln(phase'
	assert a3[2] == '1)'

	a4 := line.split_nth('=', 4)
	assert a4.len == 3
	assert a4[0] == 'CMD'
	assert a4[1] == 'eprintln(phase'
	assert a4[2] == '1)'
}

fn test_split() {
	mut s := 'volt/twitch.v:34'
	mut vals := s.split(':')
	assert vals.len == 2
	assert vals[0] == 'volt/twitch.v'
	assert vals[1] == '34'
	// /////////
	s = '2018-01-01z13:01:02'
	vals = s.split('z')
	assert vals.len == 2
	assert vals[0] =='2018-01-01'
	assert vals[1] == '13:01:02'
	// //////////
	s = '4627a862c3dec29fb3182a06b8965e0025759e18___1530207969___blue'
	vals = s.split('___')
	assert vals.len == 3
	assert vals[0]== '4627a862c3dec29fb3182a06b8965e0025759e18'
	assert vals[1]=='1530207969'
	assert vals[2]== 'blue'
	// /////////
	s = 'lalala'
	vals = s.split('a')
	assert vals.len == 4
	assert vals[0] == 'l'
	assert vals[1] == 'l'
	assert vals[2] == 'l'
	assert vals[3] == ''
	// /////////
	s = 'awesome'
	a := s.split('')
	assert a.len == 7
	assert a[0] == 'a'
	assert a[1] == 'w'
	assert a[2] == 'e'
	assert a[3] == 's'
	assert a[4] == 'o'
	assert a[5] == 'm'
	assert a[6] == 'e'
}

fn test_trim_space() {
	a := ' a '
	assert a.trim_space() == 'a'
	code := '

fn main() {
        println(2)
}

'
	code_clean := 'fn main() {
        println(2)
}'
	assert code.trim_space() == code_clean
}

fn test_join() {
	mut strings := [ 'a', 'b', 'c' ]
	mut s := strings.join(' ')
	assert s == 'a b c'
	strings = ['one
two ',
	'three!
four!']
	s = strings.join(' ')
	assert s.contains('one') && s.contains('two ') && s.contains('four')
}

fn test_clone() {
	mut a := 'a'
	a += 'a'
	a += 'a'
	b := a
	c := a.clone()
	assert c == a
	assert c == 'aaa'
	assert b == 'aaa'
}

fn test_replace() {
	a := 'hello man!'
	mut b := a.replace('man', 'world')
	assert b==('hello world!')
	b = b.replace('!', '')
	assert b==('hello world')
	b = b.replace('h', 'H')
	assert b==('Hello world')
	b = b.replace('foo', 'bar')
	assert b==('Hello world')
	s := 'hey man how are you'
	assert s.replace('man ', '') == 'hey how are you'
	lol := 'lol lol lol'
	assert lol.replace('lol', 'LOL') == 'LOL LOL LOL'
	b = 'oneBtwoBBthree'
	assert b.replace('B', '') == 'onetwothree'
	b = '*charptr'
	assert b.replace('charptr', 'byteptr') == '*byteptr'
	c :='abc'
	assert c.replace('','-') == c
	v :='a   b c d'
	assert v.replace('  ',' ') == 'a  b c d'

}

fn test_replace_each() {
	s := 'hello man man :)'
	q := s.replace_each([
		'man', 'dude',
		'hello', 'hey'
	])
	assert q == 'hey dude dude :)'
	bb := '[b]bold[/b] [code]code[/code]'
	assert bb.replace_each([
		'[b]', '<b>',
		'[/b]', '</b>',
		'[code]', '<code>',
		'[/code]', '</code>'
	]) == '<b>bold</b> <code>code</code>'
	bb2 := '[b]cool[/b]'
	assert bb2.replace_each([
		'[b]', '<b>',
		'[/b]', '</b>',
	]) == '<b>cool</b>'
}

fn test_itoa() {
	num := 777
	assert num.str() == '777'
	big := 7779998
	assert big.str() == '7779998'
	a := 3
	assert a.str() == '3'
	b := 5555
	assert b.str() == '5555'
	zero := 0
	assert zero.str() == '0'
	neg := -7
	assert neg.str() == '-7'
}

fn test_reassign() {
	a := 'hi'
	mut b := a
	b += '!'
	assert a == 'hi'
	assert b == 'hi!'
}

fn test_runes() {
	s := 'привет'
	assert s.len == 12
	s2 := 'privet'
	assert s2.len == 6
	u := s.ustring()
	assert u.len == 6
	assert s2.substr(1, 4).len == 3
	assert s2.substr(1, 4) == 'riv'
	assert s2[1..4].len == 3
	assert s2[1..4] == 'riv'
	assert s2[..4].len == 4
	assert s2[..4] == 'priv'
	assert s2[2..].len == 4
	assert s2[2..] == 'ivet'
	assert u.substr(1, 4).len == 6
	assert u.substr(1, 4) == 'рив'
	assert s2.substr(1, 2) == 'r'
	assert u.substr(1, 2) == 'р'
	assert s2.ustring().at(1) == 'r'
	assert u.at(1) == 'р'
	first := u.at(0)
	last := u.at(u.len - 1)
	assert first.len == 2
	assert last.len == 2
}

fn test_lower() {
	mut s := 'A'
	assert s.to_lower() == 'a'
	assert s.to_lower().len == 1
	s = 'HELLO'
	assert s.to_lower() == 'hello'
	assert s.to_lower().len == 5
	s = 'Aloha'
	assert s.to_lower() == 'aloha'
	s = 'Have A nice Day!'
	assert s.to_lower() == 'have a nice day!'
	s = 'hi'
	assert s.to_lower() == 'hi'
}

fn test_upper() {
	mut s := 'a'
	assert s.to_upper() == 'A'
	assert s.to_upper().len == 1
	s = 'hello'
	assert s.to_upper() == 'HELLO'
	assert s.to_upper().len == 5
	s = 'Aloha'
	assert s.to_upper() == 'ALOHA'
	s = 'have a nice day!'
	assert s.to_upper() == 'HAVE A NICE DAY!'
	s = 'hi'
	assert s.to_upper() == 'HI'
}

fn test_left_right() {
	s := 'ALOHA'
	assert s.left(3) == 'ALO'
	assert s.left(0) == ''
	assert s.left(8) == s
	assert s.right(3) == 'HA'
	assert s.right(6) == ''
	assert s[3..] == 'HA'
	u := s.ustring()
	assert u.left(3) == 'ALO'
	assert u.left(0) == ''
	assert s.left(8) == s
	assert u.right(3) == 'HA'
	assert u.right(6) == ''
}

fn test_contains() {
	s := 'view.v'
	assert s.contains('vi')
	assert !s.contains('random')
}

fn test_arr_contains() {
	a := ['a', 'b', 'c']
	assert a.contains('b')
	ints := [1, 2, 3]
	assert ints.contains(2)
}

fn test_to_num() {
	s := '7'
	assert s.int() == 7
	assert s.u64() == 7
	f := '71.5 hasdf'
	assert f.f32() == 71.5
	b := 1.52345
	mut a := '${b:.03f}'
	assert a == '1.523'
	num := 7
	a = '${num:03d}'
	vals := ['9']
	assert vals[0].int() == 9
	big := '93993993939322'
	assert big.u64() == 93993993939322
	assert big.i64() == 93993993939322
}

fn test_hash() {
	s := '10000'
	assert s.hash() == 46730161
	s2 := '24640'
	assert s2.hash() == 47778736
	s3 := 'Content-Type'
	assert s3.hash() == 949037134
	s4 := 'bad_key'
	assert s4.hash() == -346636507
	s5 := '24640'
	// From a map collision test
	assert s5.hash() % ((1 << 20) -1) == s.hash() % ((1 << 20) -1)
	assert s5.hash() % ((1 << 20) -1) == 592861
}

fn test_trim() {
	assert 'banana'.trim('bna') == ''
	assert 'abc'.trim('ac') == 'b'
	assert 'aaabccc'.trim('ac') == 'b'
}

fn test_trim_left() {
	mut s := 'module main'
	assert s.trim_left(' ') == 'module main'
	s = ' module main'
	assert s.trim_left(' ') == 'module main'
	// test cutset
	s = 'banana'
	assert s.trim_left('ba') == 'nana'
}

fn test_trim_right() {
	mut s := 'module main'
	assert s.trim_right(' ') == 'module main'
	s = 'module main '
	assert s.trim_right(' ') == 'module main'
	// test cutset
	s = 'banana'
	assert s.trim_right('na') == 'b'
}

fn test_all_before() {
	s := 'fn hello fn'
	assert s.all_before(' ') == 'fn'
	assert s.all_before('2') == s
	assert s.all_before('') == s
}

fn test_all_before_last() {
	s := 'fn hello fn'
	assert s.all_before_last(' ') == 'fn hello'
	assert s.all_before_last('2') == s
	assert s.all_before_last('') == s
}

fn test_all_after() {
	s := 'fn hello'
	assert s.all_after('fn ') == 'hello'
	assert s.all_after('test') == s
	assert s.all_after('') == s
}

fn test_reverse() {
	assert 'hello'.reverse() == 'olleh'
	assert ''.reverse() == ''
	assert 'a'.reverse() == 'a'
}

struct Foo {
	bar int
mut:
	str string
}

fn (f Foo) baz() string {
	return 'baz'
}

fn test_interpolation() {
	num := 7
	mut s := 'number=$num'
	assert s == 'number=7'
	foo := Foo{}
	s = 'baz=${foo.baz()}'
	assert s == 'baz=baz'

}

fn test_bytes_to_string() {
	mut buf := vcalloc(10)
	buf[0] = `h`
	buf[1] = `e`
	buf[2] = `l`
	buf[3] = `l`
	buf[4] = `o`
	assert string(buf) == 'hello'
	assert string(buf, 2) == 'he'
	bytes := [`h`, `e`, `l`, `l`, `o`]
	assert string(bytes, 5) == 'hello'
}

fn test_count() {
	assert ''.count('') == 0
	assert ''.count('a') == 0
	assert 'a'.count('') == 0
	assert 'aa'.count('a') == 2
	assert 'aa'.count('aa') == 1
	assert 'aabbaa'.count('aa') == 2
	assert 'bbaabb'.count('aa') == 1
}

fn test_capitalize() {
	mut s := 'hello'
	assert s.capitalize() == 'Hello'
	s = 'test'
	assert s.capitalize() == 'Test'
    s = 'i am ray'
	assert s.capitalize() == 'I am ray'
	s = ''
	assert s.capitalize() == ''
}

fn test_title() {
	s := 'hello world'
	assert s.title() == 'Hello World'
	s.to_upper()
	assert s.title() == 'Hello World'
	s.to_lower()
	assert s.title() == 'Hello World'
}

fn test_for_loop() {
	mut i := 0
	s := 'abcd'

	for c in s {
		assert c == s[i]
		i++
	}
}

fn test_for_loop_two() {
	s := 'abcd'

	for i, c in s {
		assert c == s[i]
	}
}

fn test_quote() {
	a := `'`
	println("testing double quotes")
	b := "hi"
	assert b == 'hi'
	assert a.str() == '\''
}

fn test_ustring_comparisons() {
	assert ('h€llô !'.ustring() == 'h€llô !'.ustring()) == true
	assert ('h€llô !'.ustring() == 'h€llô'.ustring()) == false
	assert ('h€llô !'.ustring() == 'h€llo !'.ustring()) == false

	assert ('h€llô !'.ustring() != 'h€llô !'.ustring()) == false
	assert ('h€llô !'.ustring() != 'h€llô'.ustring()) == true

	assert ('h€llô'.ustring() < 'h€llô!'.ustring()) == true
	assert ('h€llô'.ustring() < 'h€llo'.ustring()) == false
	assert ('h€llo'.ustring() < 'h€llô'.ustring()) == true

	assert ('h€llô'.ustring() <= 'h€llô!'.ustring()) == true
	assert ('h€llô'.ustring() <= 'h€llô'.ustring()) == true
	assert ('h€llô!'.ustring() <= 'h€llô'.ustring()) == false

	assert ('h€llô!'.ustring() > 'h€llô'.ustring()) == true
	assert ('h€llô'.ustring() > 'h€llô'.ustring()) == false

	assert ('h€llô!'.ustring() >= 'h€llô'.ustring()) == true
	assert ('h€llô'.ustring() >= 'h€llô'.ustring()) == true
	assert ('h€llô'.ustring() >= 'h€llô!'.ustring()) == false
}

fn test_ustring_count() {
	a := 'h€llôﷰ h€llô ﷰ'.ustring()
	assert (a.count('l'.ustring())) == 4
	assert (a.count('€'.ustring())) == 2
	assert (a.count('h€llô'.ustring())) == 2
	assert (a.count('ﷰ'.ustring())) == 2
	assert (a.count('a'.ustring())) == 0
}

fn test_limit() {
	s := 'hello'
	assert s.limit(2) == 'he'
	assert s.limit(9) == s
	assert s.limit(0) == ''
	// assert s.limit(-1) == ''
}

fn test_repeat() {
	s1 := 'V! '
	assert s1.repeat(5) == 'V! V! V! V! V! '
	assert s1.repeat(1) == s1
	assert s1.repeat(0) == ''
	s2 := ''
	assert s2.repeat(5) == s2
	assert s2.repeat(1) == s2
	assert s2.repeat(0) == s2
	// TODO Add test for negative values
}

fn test_raw() {
	raw := r'raw\nstring'
	lines := raw.split('\n')
	assert lines.len == 1
	println('raw string: "$raw"')
}

fn test_raw_with_quotes() {
	raw := r"some'" + r'"thing' // " should be escaped in the generated C code
	assert raw[0] == `s`
	assert raw[5] == `"`
	assert raw[6] == `t`
}

fn test_escape() {
	// TODO
	//a := 10
	//println("\"$a")
}

fn test_atoi() {
	assert '234232'.int() == 234232
	assert '-9009'.int() == -9009
	assert '0'.int() == 0
	for n in -10000 .. 100000 {
		s := n.str()
		assert s.int() == n
	}
}

fn test_raw_inter() {
	world := 'world'
	println(world)
	s := r'hello\n$world'
	assert s == r'hello\n$world'
	assert s.contains('$')
}

fn test_c_r() {
	// This used to break because of r'' and c''
	c := 42
	println('$c')
	r := 50
	println('$r')
}

fn test_inter_before_comp_if() {
	s := '123'
	// This used to break ('123 $....')
	$if linux {
		println(s)
	}
	assert s == '123'
}

fn test_double_quote_inter() {
	a := 1
	b := 2
	println("${a} ${b}")
	assert "${a} ${b}" == "1 2"
	assert '${a} ${b}' == "1 2"
}

fn test_split_into_lines() {
	line_content := 'Line'
	text_crlf := '${line_content}\r\n${line_content}\r\n${line_content}'
	lines_crlf := text_crlf.split_into_lines()

	assert lines_crlf.len == 3
	for line in lines_crlf {
		assert line == line_content
	}

	text_lf := '${line_content}\n${line_content}\n${line_content}'
	lines_lf := text_lf.split_into_lines()

	assert lines_lf.len == 3
	for line in lines_lf {
		assert line == line_content
	}
}

fn test_strip_margins_no_tabs() {
	no_tabs := ['Hello there',
	            'This is a string',
	            'With multiple lines',
	           ].join('\n')
	no_tabs_stripped := 'Hello there
	                    |This is a string
						|With multiple lines'.strip_margin()
	assert no_tabs == no_tabs_stripped
}

fn test_strip_margins_text_before() {
	text_before := ['There is text',
	                'before the delimiter',
	                'that should be removed as well',
	               ].join('\n')
	text_before_stripped := 'There is text
	f lasj  asldfj j lksjdf |before the delimiter
	Which is removed hello  |that should be removed as well'.strip_margin()
	assert text_before_stripped == text_before
}

fn test_strip_margins_white_space_after_delim() {
	tabs := ['	Tab',
	         '    spaces',
	         '	another tab',
	        ].join('\n')
	tabs_stripped := '	Tab
	                 |    spaces
					 |	another tab'.strip_margin()
	assert tabs == tabs_stripped
}

fn test_strip_margins_alternate_delim() {
	alternate_delimiter := ['This has a different delim,',
	                        'but that is ok',
	                        'because everything works',
	                       ].join('\n')
	alternate_delimiter_stripped := 'This has a different delim,
	                                #but that is ok
                                    #because everything works'.strip_margin(`#`)
	assert alternate_delimiter_stripped == alternate_delimiter
}

fn test_strip_margins_multiple_delims_after_first() {
	delim_after_first_instance := ['The delimiter used',
	                               'only matters the |||| First time it is seen',
	                               'not any | other | times',
	                              ].join('\n')
	delim_after_first_instance_stripped := 'The delimiter used
	                                       |only matters the |||| First time it is seen
	                                       |not any | other | times'.strip_margin()
	assert delim_after_first_instance_stripped == delim_after_first_instance
}

fn test_strip_margins_uneven_delims() {
	uneven_delims := ['It doesn\'t matter if the delims are uneven,',
	                  'The text will still be delimited correctly.',
	                  'Maybe not everything needs 3 lines?',
	                  'Let us go for 4 then',
	                 ].join('\n')
	uneven_delims_stripped := 'It doesn\'t matter if the delims are uneven,
           |The text will still be delimited correctly.
                      |Maybe not everything needs 3 lines?
		 	 	|Let us go for 4 then'.strip_margin()
	assert uneven_delims_stripped == uneven_delims
}

fn test_strip_margins_multiple_blank_lines() {
	multi_blank_lines := ['Multiple blank lines will be removed.',
	                      '	I actually consider this a feature.',
	                     ].join('\n')
	multi_blank_lines_stripped := 'Multiple blank lines will be removed.



		|	I actually consider this a feature.'.strip_margin()
	assert multi_blank_lines == multi_blank_lines_stripped
}

fn test_strip_margins_end_newline() {
	end_with_newline := ['This line will end with a newline',
	                     'Something cool or something.',
	                     '',
	                    ].join('\n')
	end_with_newline_stripped := 'This line will end with a newline
	                             |Something cool or something.

					'.strip_margin()
	assert end_with_newline_stripped == end_with_newline
}

fn test_strip_margins_space_delimiter() {
	space_delimiter := ['Using a white-space char will',
	                    'revert back to default behavior.',
	                   ].join('\n')
	space_delimiter_stripped := 'Using a white-space char will
		|revert back to default behavior.'.strip_margin(`\n`)
	assert space_delimiter == space_delimiter_stripped
}

fn test_strip_margins_crlf() {
	crlf := ['This string\'s line endings have CR as well as LFs.',
	         'This should pass',
	         'Definitely',
	        ].join('\r\n')
	crlf_stripped := 'This string\'s line endings have CR as well as LFs.\r
	                 |This should pass\r
					 |Definitely'.strip_margin()

	assert crlf == crlf_stripped
}
