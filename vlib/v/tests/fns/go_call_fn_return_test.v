const text = 'Hello world'

fn test_go_call_fn_return() {
	hex_go := spawn text.hex()
	hex := text.hex()

	assert hex == '48656c6c6f20776f726c64'
	assert hex_go.wait() == hex
}
