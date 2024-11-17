struct TaggedSource {}

type SumType = TaggedSource | int

fn test_main() {
	f()
}

fn f() {
	source := SumType(0)
	path := match source {
		TaggedSource {
			$if foo ? {
				'a'
			} $else {
				'b'
			}
		}
		else {
			'c'
		}
	}
	assert path == 'c'
}
