// 1 line comment // 1 line comment
/*
multi line comment (1)
multi line comment (2)
multi line comment (3)
*/
/*
multi line comment (1)
	/*
		nested comment
	*/
	/*nested comment*/
	/*nested comment
*/
	/* nested comment */
	/* /* nested comment */ */
	multi line comment (2)
*/
type MyFn1 = fn (int) string

type MyFn2 = fn (a int, b int) int

type MyFn3 = fn (int, int)

fn myfn4(string)

fn foobar()

fn slopediv(num, den u32) int

type F1 = fn ()

type F2 = fn (voidptr)

type F3 = fn (voidptr, voidptr)

type F4 = fn (voidptr) int

type F5 = fn (int, int) int

type F6 = fn (int, int)

fn C.atoi(byteptr) int

fn foo() {
}

type ActionfV = fn ()

type ActionfP1 = fn (voidptr)

type ActionfP2 = fn (voidptr, voidptr)

// TODO
fn modify_array(mut a []int) {
	a[0] = 10
	for i in 0 .. a.len {
		a[i] = a[i] * 2
	}
	// a << 888
}

fn modify_array2(mut a []int) {
	a[0] = 10
	for i in 0 .. a.len {
		a[i] = a[i] * 2
	}
	// a << 888
}

fn test_mut_array() {
	mut nums := [1, 2, 3]
	modify_array(mut nums)
	// assert nums.len == 4
	// println(nums)
	assert nums[0] == 20
	assert nums[1] == 4
	assert nums[2] == 6
	// assert nums[3] == 888
	// workaround for // [91, 32, -33686272] windows bug
	println(nums.clone())
}

fn mod_struct(mut user User) {
	user.age++
}

struct User {
mut:
	age int
}

fn test_mut_struct() {
	mut user := User{18}
	mod_struct(mut user)
	assert user.age == 19
}

/*
fn mod_ptr(mut buf &byte) {
	buf[0] = 77
}

fn test_mut_ptr() {
	buf := malloc(10)
	mod_ptr(mut buf)
	assert buf[0] == 77
}
*/

fn assert_in_bool_fn(v int) bool {
	assert v < 3
	return true
}

fn test_assert_in_bool_fn() {
	assert_in_bool_fn(2)
}

type MyFn = fn (int) int

fn test(n int) int {
	return n + 1000
}

struct MySt {
	f MyFn
}

fn test_fn_type_call() {
	mut arr := []MyFn{}
	arr << MyFn(test)
	// TODO: `arr[0](10)`
	// assert arr[0](10) == 1010
	x1 := arr[0]
	x2 := x1(10)
	assert x2 == 1010
	st := MySt{
		f: test
	}
	assert st.f(10) == 1010
	st1 := &MySt{
		f: test
	}
	assert st1.f(10) == 1010
}

fn ff() fn () int {
	return fn () int {
		return 22
	}
}

fn test_fn_return_fn() {
	f := ff()
	assert f() == 22
}

fn cross_assign_anon_fn_one (a int, b bool) string {
	return 'one'
}

fn cross_assign_anon_fn_two (a int, b bool) string {
	return 'two'
}

fn cross_assign_anon_fn_three() (string, string) {
	return 'three', 'three'
}

fn cross_assign_anon_fn_four() (string, string) {
	return 'four', 'four'
}

fn cross_assign_anon_fn_five(a ...int) string {
	return 'five'
}

fn cross_assign_anon_fn_six(a ...int) string {
	return 'six'
}

fn cross_assign_anon_fn_seven (a int, b bool) string {
	return 'seven'
}

fn cross_assign_anon_fn_eight (a int, b bool) string {
	return 'eight'
}

fn test_cross_assign_anon_fn() {
	mut one := cross_assign_anon_fn_one
	mut two := cross_assign_anon_fn_two
	one, two = two, one
	foo := two(0, true) + one(0, true)
	assert foo == 'onetwo'
	
	mut three := cross_assign_anon_fn_three
	mut four := cross_assign_anon_fn_four
	three, four = four, three
	mut foo2, mut foo3 := four()
	foo4, foo5 := three()
	foo2 += foo4
	foo3 += foo5
	assert foo2 == 'threefour'
	assert foo3 == 'threefour'
	
	mut five := cross_assign_anon_fn_five
	mut six := cross_assign_anon_fn_six
	five, six = six, five
	foo6 := six(1, 2, 3) + five(1, 2, 3)
	assert foo6 == 'fivesix'
	
	one, two, three, four, five, six = two, one, four, three, six, five
	mut foo7, _ := three()
	foo8, _ := four()
	foo7 += foo8
	foo9 := one(0, true) + two(0, true) + foo7 + five(1, 2, 3) + six(1, 2, 3)
	assert foo9 == 'onetwothreefourfivesix'
	
	mut seven := cross_assign_anon_fn_seven
	mut eight := cross_assign_anon_fn_eight
	one, two, seven, eight = two, seven, eight, one
	foo10 := one(0, true) + two(0, true) + seven(0, true) + eight(0, true)
	assert foo10 == 'twoseveneightone'
}
