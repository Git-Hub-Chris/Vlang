import toml

const toml_text = '
modules = [ "ui", "toml" ]
errors = []

[[themes]]
name = "Dracula"
colors = [ "red", "black", "white" ]

[[themes]]
name = "Lemon"
colors = [
	"green",
	"yellow",
	[ "transparent" ]
]

[[tests]]
id = 1

[[tests]]
id = 2

[values]
test = 2

[[themes]]
name = "Ice"
colors = [
	"blue",
	"white"
]
'

fn test_value_query_in_array() {
	toml_doc := toml.parse(toml_text) or { panic(err) }
	mut value := toml_doc.value('themes[0].colors[1]').string()
	assert value == 'black'
	value = toml_doc.value('themes[1].colors[0]').string()
	assert value == 'green'
	value = toml_doc.value('themes[1].colors[2].[0]').string()
	assert value == 'transparent'
	value = toml_doc.value('modules[1]').string()
	assert value == 'toml'
	value = toml_doc.value('errors[11]').default_to('<none>').string()
	assert value == '<none>'
	value = toml_doc.value('themes[2].colors[0]').string()
	assert value == 'blue'
}

fn test_any_value_query() {
	toml_doc := toml.parse(toml_text) or { panic(err) }
	themes := toml_doc.value('themes')
	assert themes.value('[0].colors[0]').string() == 'red'

	mut any := themes
	assert any.value('[1].name').string() == 'Lemon'
	any = any.value('[1]')
	assert any.value('name').string() == 'Lemon'

	any = toml_doc.value('themes').value('[1].colors').value('[1]')
	assert any.string() == 'yellow'

	any = toml_doc.value('themes[1]').value('colors[1]')
	assert any.string() == 'yellow'

	any = toml_doc.value('themes[1].colors[0]')
	assert any.string() == 'green'

	any = toml_doc.value('values')
	any = any.value('test')
	assert any.int() == 2
}
