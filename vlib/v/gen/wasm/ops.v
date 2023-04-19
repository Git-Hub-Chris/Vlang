module wasm

import v.ast
import v.token
import wasm

fn (mut g Gen) get_type_size_align(typ ast.Type) (int, int) {
	ts := g.table.sym(typ)
	if ts.size != -1 && typ in g.structs {
		return ts.size, ts.align
	}

	if ts.info !is ast.Struct {
		return g.table.type_size(typ)
	}

	ti := ts.info as ast.Struct

	// Code borrowed from native, hope you don't mind!

	mut strc := StructInfo{}
	mut size := 0
	mut align := 1
	for f in ti.fields {
		f_size, f_align := g.table.type_size(f.typ)
		if f_size == 0 {
			strc.offsets << 0
			continue
		}
		padding := (f_align - size % f_align) % f_align
		strc.offsets << size + padding
		size += f_size + padding
		if f_align > align {
			align = f_align
		}
	}
	size = (size + align - 1) / align * align
	g.structs[typ.idx()] = strc

	mut ts_ := g.table.sym(typ)
	ts_.size = size
	ts_.align = align

	return size, align
}

fn (mut g Gen) as_numtype(a wasm.ValType) wasm.NumType {
	if a in [.funcref_t, .externref_t, .v128_t] {
		g.w_error("as_numtype: called with '${a}'")
	}

	return unsafe { wasm.NumType(a) }
}

// "Register size" types such as int, i64 and bool boil down to their WASM counterparts.
// Structures and unions are pointers, i32.
fn (mut g Gen) get_wasm_type(typ_ ast.Type) wasm.ValType {
	typ := ast.mktyp(typ_)
	if typ == ast.void_type_idx {
		g.w_error("get_wasm_type: called with 'void'")
	}
	if typ.is_real_pointer() {
		return wasm.ValType.i32_t
	}
	if typ in ast.number_type_idxs {
		return match typ {
			ast.isize_type_idx, ast.usize_type_idx, ast.i8_type_idx, ast.u8_type_idx,
			ast.char_type_idx, ast.rune_type_idx, ast.i16_type_idx, ast.u16_type_idx,
			ast.int_type_idx, ast.u32_type_idx {
				wasm.ValType.i32_t
			}
			ast.i64_type_idx, ast.u64_type_idx, ast.int_literal_type_idx {
				wasm.ValType.i64_t
			}
			ast.f32_type_idx {
				wasm.ValType.f32_t
			}
			ast.f64_type_idx, ast.float_literal_type_idx {
				wasm.ValType.f64_t
			}
			else {
				wasm.ValType.i32_t
			}
		}
	}
	if typ == ast.bool_type_idx {
		return wasm.ValType.i32_t
	}
	ts := g.table.sym(typ)
	match ts.info {
		ast.Struct {
			g.get_type_size_align(typ)
			return wasm.ValType.i32_t // pointer
		}
		ast.MultiReturn {
		}
		ast.Alias {
			return g.get_wasm_type(ts.info.parent_type)
		}
		ast.ArrayFixed {
			return wasm.ValType.i32_t // pointer
		}
		ast.Enum {
			return g.get_wasm_type(ts.info.typ)
		}
		else {}
	}

	g.w_error("get_wasm_type: unreachable type '${*g.table.sym(typ)}' ${ts.info}")
}

fn (mut g Gen) infix_from_typ(typ ast.Type, op token.Kind) {
	wasm_typ := g.as_numtype(g.get_wasm_type(typ))

	match op {
		.plus { g.func.add(wasm_typ) }
		.minus { g.func.sub(wasm_typ)}
		.mul { g.func.mul(wasm_typ) }
		.mod { g.func.rem(wasm_typ, typ.is_signed()) }
		.div { g.func.div(wasm_typ, typ.is_signed()) }
		.eq { g.func.eq(wasm_typ) }
		.ne { g.func.ne(wasm_typ) }
		.gt { g.func.gt(wasm_typ, typ.is_signed()) }
		.lt { g.func.lt(wasm_typ, typ.is_signed()) }
		.ge { g.func.ge(wasm_typ, typ.is_signed()) }
		.le { g.func.le(wasm_typ, typ.is_signed()) }
		.xor { g.func.b_xor(wasm_typ) }
		.pipe { g.func.b_or(wasm_typ) }
		.amp { g.func.b_and(wasm_typ) }
		.left_shift { g.func.b_shl(wasm_typ) }
		.right_shift { g.func.b_shr(wasm_typ, true) }
		.unsigned_right_shift { g.func.b_shr(wasm_typ, false) }
		else {
			g.w_error('bad infix: op `${op}`')
		}
	}
}
