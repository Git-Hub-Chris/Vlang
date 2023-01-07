fn check[T](val T) string {
	$if T in [$Array, $Struct] {
		return 'array or struct'
	} $else $if T in [$Int, $Struct] {
		return 'int'
	} $else $if T in [$Float, $Struct] {
		return 'f64'
	} $else $if T in [$Map, $Struct] {
		return 'map'
	} $else $if T in [$Sumtype, $Struct] {
		return 'sumtype'
	}
	return ''
}

type Abc = f64 | int

struct Test {
	a int
	b []string
	c f64
	d Abc
	e map[string]string
}

fn test_main() {
	var := Test{
		a: 1
		b: ['foo']
		c: 1.2
		d: 1
		e: {
			'a': 'b'
		}
	}
	assert check(var) == 'array or struct'
	assert check(var.a) == 'int'
	assert check(var.b) == 'array or struct'
	assert check(var.c) == 'f64'
	assert check(var.d) == 'sumtype'
	assert check(var.e) == 'map'
}
