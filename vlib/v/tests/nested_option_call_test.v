fn ret(s string) string {
	return s
}

fn raise() ?string {
	return none
}

fn xx() {
	s := ret(raise() or { return })
	println(s)
}

fn test_nested_or() {
	xx()
}

fn yy() {
	s := ret(raise() ?)
	println(s)
}

fn test_nested_propagation() {
	yy()
}

struct St {
mut:
	z f64
}

fn (mut s St) raise() ?f64 {
	return error('some error')
}

fn retf(f f64) f64 {
	return f
}

fn (mut s St) aa() {
	f := retf(s.raise() or { return })
	s.z = 7.5
	println(f)
}

fn test_nested_or_method_call() {
	mut x := St{
		z: 2.25
	}
	x.aa()
	assert x.z == 2.25
}

fn (mut s St) bb() {
	f := retf(s.raise() ?)
	println(f)
}

fn test_nested_propagation_method_call() {
	mut y := St{
		z: -3.5
	}
	y.bb()
	assert y.z == -3.5
}
