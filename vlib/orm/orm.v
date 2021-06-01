module orm

pub const (
	num64    = [8, 12]
	nums     = [5, 6, 7, 9, 10, 11, 16]
	float    = [13, 14]
	string   = 18
	type_idx = map{
		'i8':     5
		'i16':    6
		'int':    7
		'i64':    8
		'byte':   9
		'u16':    10
		'u32':    11
		'u64':    12
		'f32':    13
		'f64':    14
		'bool':   16
		'string': 18
	}
)

pub enum OperationKind {
	neq // !=
	eq // ==
	gt // >
	lt // <
	ge // >=
	le // <=
}

pub enum StmtKind {
	insert
	update
	delete
}

pub enum OrmOrderType {
	desc
}

pub enum OrmTypeKind {
	primitive
	struct_
	array
}

fn (kind OperationKind) to_str() string {
	str := match kind {
		.neq { '!=' }
		.eq { '==' }
		.gt { '>' }
		.lt { '<' }
		.ge { '>=' }
		.le { '<=' }
	}
	return str
}

fn (kind OrmOrderType) to_str() string {
	return match kind {
		.desc {
			'DESC'
		}
	}
}

pub struct OrmQueryData {
pub:
	fields []string
	data   []voidptr
	types  []int
	kinds  []OperationKind
}

pub struct OrmTableField {
pub:
	name        string
	typ         int
	kind        OrmTypeKind
	arr_kind    OrmTypeKind
	arr_dim     int
	default_val string
	attrs       []StructAttribute
}

pub struct OrmSelectConfig {
pub:
	table      string
	is_count   bool
	has_where  bool
	has_order  bool
	order_type OrmOrderType
	has_limit  bool
	primary    string = 'id' // should be set if primary is different than 'id' and 'has_limit' is false
	has_offset bool
	fields     []string
}

pub interface OrmConnection {
	@select(table string, data OrmQueryData, where OrmQueryData) ?[][]string
	insert(table string, data OrmQueryData) ?
	update(table string, data OrmQueryData, where OrmQueryData) ?
	delete(table string, data OrmQueryData, where OrmQueryData) ?
	create(table string, fields []OrmTableField) ?
	drop(talbe string, fields []OrmTableField) ?
}

pub fn orm_stmt_gen(table string, para string, kind StmtKind, nums bool, qm string, data OrmQueryData, where OrmQueryData) string {
	mut str := ''

	mut c := 0

	match kind {
		.insert {
			str += 'INSERT INTO $para$table$para ('
			for i, field in data.fields {
				str += '$para$field$para'
				if i < data.fields.len - 1 {
					str += ', '
				}
			}
			str += ') VALUES ('
			for i, _ in data.fields {
				str += qm
				if nums {
					str += '$c'
					c++
				}
				if i < data.fields.len - 1 {
					str += ', '
				}
			}
			str += ')'
		}
		.update {
			str += 'UPDATE $para$table$para SET '
			for i, field in data.fields {
				str += '$para$field$para = $qm'
				if nums {
					str += '$c'
					c++
				}
				if i < data.fields.len - 1 {
					str += ', '
				}
			}
			str += ' WHERE '
		}
		.delete {
			str += 'DELETE FROM $para$table$para WHERE '
		}
	}
	if kind == .update || kind == .delete {
		for i, field in where.fields {
			str += '$para$field$para ${where.kinds[i].to_str()} $qm'
			if nums {
				str += '$c'
				c++
			}
			if i < where.fields.len - 1 {
				str += ' AND '
			}
		}
	}
	str += ';'
	return str
}

pub fn orm_select_gen(orm OrmSelectConfig, para string, nums bool, qm string, where OrmQueryData) string {
	mut str := 'SELECT '

	if orm.is_count {
		str += 'COUNT(*)'
	} else {
		for i, field in orm.fields {
			str += '$para$field$para'
			if i < orm.fields.len - 1 {
				str += ', '
			}
		}
	}

	str += ' FROM $para$orm.table$para'

	mut c := 0

	if orm.has_where {
		str += ' WHERE '
		for i, field in where.fields {
			str += '$para$field$para ${where.kinds[i].to_str()} $qm'
			if nums {
				str += '$c'
				c++
			}
			if i < where.fields.len - 1 {
				str += ' AND '
			}
		}
	}

	str += ' ORDER BY '
	if orm.has_order {
		str += orm.order_type.to_str()
	} else {
		str += '$para$orm.primary$para'
	}

	if orm.has_limit {
		str += ' LIMIT ?'
		if nums {
			str += '$c'
			c++
		}
	}

	if orm.has_offset {
		str += ' OFFSET ?'
		if nums {
			str += '$c'
			c++
		}
	}

	str += ';'
	return str
}

pub fn orm_table_gen(table string, para string, defaults bool, def_unique_len int, fields []OrmTableField, sql_from_v fn (int) string) ?string {
	mut str := 'CREATE TABLE IF NOT EXISTS $para$table$para ('

	mut fs := []string{}
	mut unique_fields := []string{}
	mut unique := map[string][]string{}
	mut primary := ''

	for field in fields {
		mut no_null := false
		mut is_unique := false
		mut is_skip := false
		mut unique_len := 0
		mut fkey := ''
		for attr in field.attrs {
			match attr.name {
				'primary' {
					primary = field.name
				}
				'unique' {
					if attr.arg != '' {
						if attr.kind == .string {
							unique[attr.arg] << field.name
							continue
						} else if attr.kind == .number {
							unique_len = attr.arg.int()
							is_unique = true
							continue
						}
					}
					is_unique = true
				}
				'nonull' {
					no_null = true
				}
				'skip' {
					is_skip = true
				}
				'fkey' {
					if attr.arg != '' {
						if attr.kind == .string {
							fkey = attr.arg
							continue
						}
					}
				}
				else {}
			}
		}
		if is_skip {
			continue
		}
		mut stmt := ''
		mut ctyp := sql_from_v(sql_field_type(field))
		if ctyp == '' {
			if field.kind == .struct_ {
				// TODO add multistructs
			} else if field.kind == .array {
				if field.arr_dim > 1 {
					return error('Arrays with just one dim are supported in orm')
				}
				if field.arr_kind == .struct_ {
					if fkey == '' {
						return error('Array field ($field.name) needs a fkey')
					}
					// TODO add multistructs
				} else if field.arr_kind == .primitive {
					return error('Array with non-struct types is not supported yet')
				} else {
					return error('Unknown type ($field.typ) for field $field.name in struct $table')
				}
			} else {
				return error('Unknown type ($field.typ) for field $field.name in struct $table')
			}
		}
		stmt = '$para$field.name$para $ctyp'
		if defaults {
			stmt += ' DEFAULT $field.default_val'
		}
		if no_null {
			stmt += ' NOT NULL'
		}
		if is_unique {
			mut f := 'UNIQUE KEY($para$field.name$para'
			if ctyp == 'TEXT' && def_unique_len > 0 {
				if unique_len > 0 {
					f += '($unique_len)'
				} else {
					f += '($def_unique_len)'
				}
			}
			f += ')'
			unique_fields << f
		}
		fs << stmt
	}
	if unique.len > 0 {
		for k, v in unique {
			mut tmp := []string{}
			for f in v {
				tmp << '$para$f$para'
			}
			fs << '/* $k */UNIQUE(${tmp.join(', ')})'
		}
	}
	fs << 'PRIMARY KEY($para$primary$para)'
	fs << unique_fields
	str += fs.join(', ')
	str += ');'
	return str
}

fn sql_field_type(field OrmTableField) int {
	mut typ := field.typ
	for attr in field.attrs {
		if attr.kind == .plain && attr.name == 'sql' && attr.arg != '' {
			if attr.arg.to_lower() == 'serial' {
				typ = -1
				break
			}
		}
		typ = orm.type_idx[attr.arg]
	}
	return typ
}
