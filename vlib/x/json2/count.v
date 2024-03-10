module json2

import time

pub struct Count {
mut:
	total int
}

// count_chars count json sizen whithout new encode
pub fn (mut count Count) count_chars[T](val T) {
	$if val is $option {
		workaround := val
		if workaround != none {
			count.count_chars(val)
		}
	} $else $if T is string {
		count.chars_in_string(val)
	} $else $if T is $sumtype {
		$for v in val.variants {
			if val is v {
				count.count_chars(val)
			}
		}
	} $else $if T is $alias {
	} $else $if T is time.Time {
		count.total += 26 // "YYYY-MM-DDTHH:mm:ss.123Z"
	} $else $if T is $map {
		count.total += 3 // {:}
		for k, v in value {
			count.count_chars(k)
			count.count_chars(v)
		}
	} $else $if T is $array {
		count.total += 2 // []
		for element in val {
			count.count_chars(element)
		}
	} $else $if T is $struct {
		count.chars_in_struct(val)
	} $else $if T is $enum {
	} $else $if T is $int {
		// TODO test
		// TODO benchmark
		if val < 0 {
			count.total++ // -
		}
		for number_value := i64(val*1); number_value >= 1; number_value /= 10 {
			count.total++
		}
	} $else $if T is $float {
	} $else $if T is bool {
		if val {
			count.total += 4 // true
		} else {
			count.total += 5 // false
		}
	} $else {
	}
}

// chars_in_struct
fn (mut count Count) chars_in_struct[T](val T) {
	count.total += 2 // {}
	$for field in T.fields {
		// TODO handle attributes
		count.total += field.name.len + 3 // "":
		workaround := val.$(field.name)
		count.count_chars(workaround)
	}
}

// chars_in_string
fn (mut count Count) chars_in_string(val string) {
	count.total += val.len + 2 // ""
}
