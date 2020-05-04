// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module gen

import v.ast
import v.table
import v.util

fn (mut g Gen) gen_fn_decl(it ast.FnDecl) {
	if it.is_c {
		// || it.no_body {
		return
	}
	is_main := it.name == 'main'
	//
	if is_main && g.pref.is_liveshared {
		return
	}
	//
	fn_start_pos := g.out.len
	if g.attr == 'inline' {
		g.write('inline ')
	}
	//
	is_livefn := g.attr == 'live'
	is_livemain := g.pref.is_livemain && is_livefn
	is_liveshared := g.pref.is_liveshared && is_livefn
	is_livemode := g.pref.is_livemain || g.pref.is_liveshared
	is_live_wrap := is_livefn && is_livemode
	if is_livefn && !is_livemode {
		eprintln('INFO: compile with `v -live $g.pref.path `, if you want to use the [live] function ${it.name} .')
	}
	//
	g.reset_tmp_count()
	if is_main {
		if g.pref.os == .windows {
			if g.is_gui_app() {
				// GUI application
				g.writeln('int WINAPI wWinMain(HINSTANCE instance, HINSTANCE prev_instance, LPWSTR cmd_line, int show_cmd){')
				g.last_fn_c_name = 'wWinMain'
			} else {
				// Console application
				g.writeln('int wmain(int ___argc, wchar_t* ___argv[], wchar_t* ___envp[]){')
				g.last_fn_c_name = 'wmain'
			}
		} else {
			g.writeln('int main(int ___argc, char** ___argv){')
			g.last_fn_c_name = it.name
		}
	} else {
		mut name := it.name
		if name[0] in [`+`, `-`, `*`, `/`, `%`] {
			name = util.replace_op(name)
		}
		if it.is_method {
			name = g.table.get_type_symbol(it.receiver.typ).name + '_' + name
		}
		if it.is_c {
			name = name.replace('.', '__')
		} else {
			name = c_name(name)
		}
		// if g.pref.show_cc && it.is_builtin {
		// println(name)
		// }
		// type_name := g.table.Type_to_str(it.return_type)
		// Live functions are protected by a mutex, because otherwise they
		// can be changed by the live reload thread, *while* they are
		// running, with unpredictable results (usually just crashing).
		// For this purpose, the actual body of the live function,
		// is put under a non publicly accessible function, that is prefixed
		// with 'impl_live_' .
		if is_livemain {
			g.hotcode_fn_names << name
		}
		mut impl_fn_name := if is_live_wrap { 'impl_live_${name}' } else { name }
		g.last_fn_c_name = impl_fn_name
		type_name := g.typ(it.return_type)
		//
		if is_live_wrap {
			if is_livemain {
				g.definitions.write('$type_name (* ${impl_fn_name})(')
				g.write('$type_name no_impl_${name}(')
			}
			if is_liveshared {
				g.definitions.write('$type_name ${impl_fn_name}(')
				g.write('$type_name ${impl_fn_name}(')
			}
		} else {
			if !it.is_pub {
				g.write('static ')
				g.definitions.write('static ')
			}
			g.definitions.write('$type_name ${name}(')
			g.write('$type_name ${name}(')
		}
		fargs, fargtypes := g.fn_args(it.args, it.is_variadic)
		if it.no_body || (g.pref.use_cache && it.is_builtin) {
			// Just a function header. Builtin function bodies are defined in builtin.o
			g.definitions.writeln(');')
			g.writeln(');')
			return
		}
		g.definitions.writeln(');')
		g.writeln(') {')
		if is_live_wrap {
			// The live function just calls its implementation dual, while ensuring
			// that the call is wrapped by the mutex lock & unlock calls.
			// Adding the mutex lock/unlock inside the body of the implementation
			// function is not reliable, because the implementation function can do
			// an early exit, which will leave the mutex locked.
			mut fn_args_list := []string{}
			for ia, fa in fargs {
				fn_args_list << '${fargtypes[ia]} ${fa}'
			}
			mut live_fncall := '${impl_fn_name}(' + fargs.join(', ') + ');'
			mut live_fnreturn := ''
			if type_name != 'void' {
				live_fncall = '${type_name} res = ${live_fncall}'
				live_fnreturn = 'return res;'
			}
			g.definitions.writeln('$type_name ${name}(' + fn_args_list.join(', ') + ');')
			g.hotcode_definitions.writeln('$type_name ${name}(' + fn_args_list.join(', ') +
				'){')
			g.hotcode_definitions.writeln('  pthread_mutex_lock(&live_fn_mutex);')
			g.hotcode_definitions.writeln('  $live_fncall')
			g.hotcode_definitions.writeln('  pthread_mutex_unlock(&live_fn_mutex);')
			g.hotcode_definitions.writeln('  $live_fnreturn')
			g.hotcode_definitions.writeln('}')
		}
	}
	if is_main {
		if g.pref.os == .windows && g.is_gui_app() {
			g.writeln('\ttypedef LPWSTR*(WINAPI *cmd_line_to_argv)(LPCWSTR, int*);')
			g.writeln('\tHMODULE shell32_module = LoadLibrary(L"shell32.dll");')
			g.writeln('\tcmd_line_to_argv CommandLineToArgvW = (cmd_line_to_argv)GetProcAddress(shell32_module, "CommandLineToArgvW");')
			g.writeln('\tint ___argc;')
			g.writeln('\twchar_t** ___argv = CommandLineToArgvW(cmd_line, &___argc);')
		}
		g.writeln('\t_vinit();')
		if g.is_importing_os() {
			if g.autofree {
				g.writeln('free(_const_os__args.data); // empty, inited in _vinit()')
			}
			if g.pref.os == .windows {
				g.writeln('\t_const_os__args = os__init_os_args_wide(___argc, ___argv);')
			} else {
				g.writeln('\t_const_os__args = os__init_os_args(___argc, (byteptr*)___argv);')
			}
		}
	}
	if g.pref.is_livemain && is_main {
		g.generate_hotcode_reloading_main_caller()
	}
	// Profiling mode? Start counting at the beginning of the function (save current time).
	if g.pref.is_prof {
		g.profile_fn(it.name, is_main)
	}
	g.stmts(it.stmts)
	// ////////////
	if g.autofree {
		// println('\n\ncalling free for fn $it.name')
		g.free_scope_vars(it.body_pos.pos)
	}
	// /////////
	if is_main {
		if g.autofree {
			g.writeln('\t_vcleanup();')
		}
		if g.is_test {
			verror('test files cannot have function `main`')
		}
	}
	g.write_defer_stmts_when_needed()
	if is_main {
		g.writeln('\treturn 0;')
	}
	g.writeln('}')
	g.defer_stmts = []
	if g.pref.printfn_list.len > 0 && g.last_fn_c_name in g.pref.printfn_list {
		println(g.out.after(fn_start_pos))
	}
}

fn (mut g Gen) write_defer_stmts_when_needed() {
	if g.defer_stmts.len > 0 {
		g.write_defer_stmts()
	}
	if g.defer_profile_code.len > 0 {
		g.writeln('')
		g.writeln('\t// defer_profile_code')
		g.writeln(g.defer_profile_code)
		g.writeln('')
	}
}

fn (mut g Gen) fn_args(args []table.Arg, is_variadic bool) ([]string, []string) {
	mut fargs := []string{}
	mut fargtypes := []string{}
	no_names := args.len > 0 && args[0].name == 'arg_1'
	for i, arg in args {
		arg_type_sym := g.table.get_type_symbol(arg.typ)
		mut arg_type_name := g.typ(arg.typ) // arg_type_sym.name.replace('.', '__')
		is_varg := i == args.len - 1 && is_variadic
		if is_varg {
			varg_type_str := int(arg.typ).str()
			if varg_type_str !in g.variadic_args {
				g.variadic_args[varg_type_str] = 0
			}
			arg_type_name = 'varg_' + g.typ(arg.typ).replace('*', '_ptr')
		}
		if arg_type_sym.kind == .function {
			info := arg_type_sym.info as table.FnType
			func := info.func
			if !info.is_anon {
				g.write(arg_type_name + ' ' + arg.name)
				g.definitions.write(arg_type_name + ' ' + arg.name)
				fargs << arg.name
				fargtypes << arg_type_name
			} else {
				g.write('${g.typ(func.return_type)} (*$arg.name)(')
				g.definitions.write('${g.typ(func.return_type)} (*$arg.name)(')
				g.fn_args(func.args, func.is_variadic)
				g.write(')')
				g.definitions.write(')')
			}
		} else if no_names {
			g.write(arg_type_name)
			g.definitions.write(arg_type_name)
			fargs << ''
			fargtypes << arg_type_name
		} else {
			mut nr_muls := arg.typ.nr_muls()
			s := arg_type_name + ' ' + arg.name
			if arg.is_mut {
				// mut arg needs one *
				nr_muls = 1
			}
			// if nr_muls > 0 && !is_varg {
			// s = arg_type_name + strings.repeat(`*`, nr_muls) + ' ' + arg.name
			// }
			g.write(s)
			g.definitions.write(s)
			fargs << arg.name
			fargtypes << arg_type_name
		}
		if i < args.len - 1 {
			g.write(', ')
			g.definitions.write(', ')
		}
	}
	return fargs, fargtypes
}

fn (mut g Gen) call_expr(node ast.CallExpr) {
	if node.should_be_skipped {
		return
	}
	gen_or := !g.is_assign_rhs && node.or_block.stmts.len > 0
	tmp_opt := if gen_or { g.new_tmp_var() } else { '' }
	if gen_or {
		styp := g.typ(node.return_type)
		g.write('$styp $tmp_opt = ')
	}
	if node.is_method {
		g.method_call(node)
	} else {
		g.fn_call(node)
	}
	if gen_or {
		g.or_block(tmp_opt, node.or_block.stmts, node.return_type)
	}
}

fn (mut g Gen) method_call(node ast.CallExpr) {
	// TODO: there are still due to unchecked exprs (opt/some fn arg)
	if node.left_type == 0 {
		verror('method receiver type is 0, this means there are some uchecked exprs')
	}
	mut receiver_type_name := g.cc_type(node.receiver_type)
	typ_sym := g.table.get_type_symbol(node.receiver_type)
	if typ_sym.kind == .interface_ {
		// Speaker_name_table[s._interface_idx].speak(s._object)
		g.write('${c_name(receiver_type_name)}_name_table[')
		g.expr(node.left)
		g.write('._interface_idx].${node.name}(')
		g.expr(node.left)
		g.write('._object')
		if node.args.len > 0 {
			g.write(', ')
			g.call_args(node.args, node.expected_arg_types)
		}
		g.write(')')
		return
	}
	if typ_sym.kind == .array && node.name == 'map' {
		g.gen_map(node)
		return
	}
	// rec_sym := g.table.get_type_symbol(node.receiver_type)
	if typ_sym.kind == .array && node.name == 'filter' {
		g.gen_filter(node)
		return
	}
	if node.name == 'str' {
		mut styp := g.typ(node.receiver_type)
		if node.receiver_type.is_ptr() {
			styp = styp.replace('*', '')
		}
		g.gen_str_for_type_with_styp(node.receiver_type, styp)
	}
	// TODO performance, detect `array` method differently
	if typ_sym.kind == .array && node.name in ['repeat', 'sort_with_compare', 'free', 'push_many',
		'trim',
		'first',
		'last',
		'clone',
		'reverse',
		'slice'
	] {
		// && rec_sym.name == 'array' {
		// && rec_sym.name == 'array' && receiver_name.starts_with('array') {
		// `array_byte_clone` => `array_clone`
		receiver_type_name = 'array'
		if node.name in ['last', 'first'] {
			return_type_str := g.typ(node.return_type)
			g.write('*($return_type_str*)')
		}
	}
	name := '${receiver_type_name}_$node.name'.replace('.', '__')
	// if node.receiver_type != 0 {
	// g.write('/*${g.typ(node.receiver_type)}*/')
	// g.write('/*expr_type=${g.typ(node.left_type)} rec type=${g.typ(node.receiver_type)}*/')
	// }
	g.write('${name}(')
	if node.receiver_type.is_ptr() && !node.left_type.is_ptr() {
		// The receiver is a reference, but the caller provided a value
		// Add `&` automatically.
		// TODO same logic in call_args()
		g.write('&')
	} else if !node.receiver_type.is_ptr() && node.left_type.is_ptr() {
		g.write('/*rec*/*')
	}
	g.expr(node.left)
	is_variadic := node.expected_arg_types.len > 0 && node.expected_arg_types[node.expected_arg_types.len -
		1].flag_is(.variadic)
	if node.args.len > 0 || is_variadic {
		g.write(', ')
	}
	// /////////
	/*
	if name.contains('subkeys') {
	println('call_args $name $node.arg_types.len')
	for t in node.arg_types {
		sym := g.table.get_type_symbol(t)
		print('$sym.name ')
	}
	println('')
}
	*/
	// ///////
	g.call_args(node.args, node.expected_arg_types)
	g.write(')')
	// if node.or_block.stmts.len > 0 {
	// g.or_block(node.or_block.stmts, node.return_type)
	// }
}

fn (mut g Gen) fn_call(node ast.CallExpr) {
	// call struct field with fn type
	// TODO: test node.left instead
	// left & left_type will be `x` and `x type` in `x.fieldfn()`
	// will be `0` for `foo()`
	if node.left_type != 0 {
		g.expr(node.left)
		if node.left_type.is_ptr() {
			g.write('->')
		} else {
			g.write('.')
		}
	}
	mut name := node.name
	is_print := name == 'println' || name == 'print'
	print_method := if name == 'println' { 'println' } else { 'print' }
	g.is_json_fn = name == 'json.encode'
	mut json_type_str := ''
	if g.is_json_fn {
		g.write('json__json_print(')
		g.gen_json_for_type(node.args[0].typ)
		json_type_str = g.table.get_type_symbol(node.args[0].typ).name
	}
	if node.is_c {
		// Skip "C."
		g.is_c_call = true
		name = name[2..].replace('.', '__')
	} else {
		name = c_name(name)
	}
	if g.is_json_fn {
		// `json__decode` => `json__decode_User`
		name += '_' + json_type_str
	}
	// Generate tmp vars for values that have to be freed.
	/*
	mut tmps := []string{}
	for arg in node.args {
		if arg.typ == table.string_type_idx || is_print {
			tmp := g.new_tmp_var()
			tmps << tmp
			g.write('string $tmp = ')
			g.expr(arg.expr)
			g.writeln('; //memory')
		}
	}
	*/
	if is_print && node.args[0].typ != table.string_type {
		typ := node.args[0].typ
		mut styp := g.typ(typ)
		sym := g.table.get_type_symbol(typ)
		if typ.is_ptr() {
			styp = styp.replace('*', '')
		}
		mut str_fn_name := g.gen_str_for_type_with_styp(typ, styp)
		if g.autofree && !typ.flag_is(.optional) {
			// Create a temporary variable so that the value can be freed
			tmp := g.new_tmp_var()
			// tmps << tmp
			g.write('string $tmp = ${str_fn_name}(')
			g.expr(node.args[0].expr)
			g.writeln('); ${print_method}($tmp); string_free($tmp); //MEM2 $styp')
		} else {
			expr := node.args[0].expr
			is_var := match expr {
				ast.SelectorExpr { true }
				ast.Ident { true }
				else { false }
			}
			if typ.is_ptr() && sym.kind != .struct_ {
				// ptr_str() for pointers
				styp = 'ptr'
				str_fn_name = 'ptr_str'
			}
			if sym.kind == .enum_ {
				if is_var {
					g.write('${print_method}(${str_fn_name}(')
				} else {
					// when no var, print string directly
					g.write('${print_method}(tos3("')
				}
				if typ.is_ptr() {
					// dereference
					g.write('*')
				}
				g.enum_expr(expr)
				if !is_var {
					// end of string
					g.write('"')
				}
			} else {
				g.write('${print_method}(${str_fn_name}(')
				if typ.is_ptr() && sym.kind == .struct_ {
					// dereference
					g.write('*')
				}
				g.expr(expr)
				if !typ.flag_is(.variadic) && sym.kind == .struct_ && styp != 'ptr' && !sym.has_method('str') {
					g.write(', 0') // trailing 0 is initial struct indent count
				}
			}
			g.write('))')
		}
	} else if g.pref.is_debug && node.name == 'panic' {
		paline := node.pos.line_nr + 1
		pafile := g.fn_decl.file.replace('\\', '/')
		pafn := g.fn_decl.name.after('.')
		mut pamod := g.fn_decl.name.all_before_last('.')
		if pamod == pafn {
			pamod == 'builtin'
		}
		g.write('panic_debug($paline, tos3("$pafile"), tos3("$pamod"), tos3("$pafn"),  ')
		g.call_args(node.args, node.expected_arg_types)
		g.write(')')
	} else {
		g.write('${name}(')
		g.call_args(node.args, node.expected_arg_types)
		g.write(')')
	}
	// if node.or_block.stmts.len > 0 {
	// g.or_block(node.or_block.stmts, node.return_type)
	// }
	g.is_c_call = false
	if g.is_json_fn {
		g.write(')')
		g.is_json_fn = false
	}
}

fn (mut g Gen) call_args(args []ast.CallArg, expected_types []table.Type) {
	is_variadic := expected_types.len > 0 && expected_types[expected_types.len - 1].flag_is(.variadic)
	is_forwarding_varg := args.len > 0 && args[args.len - 1].typ.flag_is(.variadic)
	gen_vargs := is_variadic && !is_forwarding_varg
	for i, arg in args {
		if gen_vargs && i == expected_types.len - 1 {
			break
		}
		// if arg.typ.name.starts_with('I') {
		// }
		mut is_interface := false
		// some c fn definitions dont have args (cfns.v) or are not updated in checker
		// when these are fixed we wont need this check
		if i < expected_types.len {
			if expected_types[i] != 0 {
				// Cast a type to interface
				// `foo(dog)` => `foo(I_Dog_to_Animal(dog))`
				exp_sym := g.table.get_type_symbol(expected_types[i])
				// exp_styp := g.typ(expected_types[arg_no]) // g.table.get_type_symbol(expected_types[arg_no])
				// styp := g.typ(arg.typ) // g.table.get_type_symbol(arg.typ)
				if exp_sym.kind == .interface_ {
					g.interface_call(arg.typ, expected_types[i])
					// g.write('/*Z*/I_${styp}_to_${exp_styp}(')
					is_interface = true
				}
			}
			g.ref_or_deref_arg(arg, expected_types[i])
		} else {
			g.expr(arg.expr)
		}
		if is_interface {
			g.write(')')
		}
		if i < args.len - 1 || gen_vargs {
			g.write(', ')
		}
	}
	arg_nr := expected_types.len - 1
	if gen_vargs {
		varg_type := expected_types[expected_types.len - 1]
		struct_name := 'varg_' + g.typ(varg_type).replace('*', '_ptr')
		variadic_count := args.len - arg_nr
		varg_type_str := int(varg_type).str()
		if variadic_count > g.variadic_args[varg_type_str] {
			g.variadic_args[varg_type_str] = variadic_count
		}
		g.write('($struct_name){.len=$variadic_count,.args={')
		if variadic_count > 0 {
			for j in arg_nr .. args.len {
				g.ref_or_deref_arg(args[j], varg_type)
				if j < args.len - 1 {
					g.write(', ')
				}
			}
		} else {
			g.write('0')
		}
		g.write('}}')
	}
}

[inline]
fn (mut g Gen) ref_or_deref_arg(arg ast.CallArg, expected_type table.Type) {
	arg_is_ptr := expected_type.is_ptr() || expected_type.idx() in table.pointer_type_idxs
	expr_is_ptr := arg.typ.is_ptr() || arg.typ.idx() in table.pointer_type_idxs
	exp_sym := g.table.get_type_symbol(expected_type)
	if arg.is_mut && !arg_is_ptr {
		g.write('&/*mut*/')
	} else if arg_is_ptr && !expr_is_ptr {
		if arg.is_mut {
			if exp_sym.kind == .array {
				// Special case for mutable arrays. We can't `&` function
				// results,	have to use `(array[]){ expr }[0]` hack.
				g.write('&/*111*/(array[]){')
				g.expr(arg.expr)
				g.write('}[0]')
				return
			}
		}
		if !g.is_json_fn {
			g.write('&/*qq*/')
		}
	} else if !arg_is_ptr && expr_is_ptr && exp_sym.kind != .interface_ {
		// Dereference a pointer if a value is required
		g.write('*/*d*/')
	}
	g.expr_with_cast(arg.expr, arg.typ, expected_type)
}

fn (mut g Gen) is_gui_app() bool {
	$if windows {
		for cf in g.table.cflags {
			if cf.value == 'gdi32' {
				return true
			}
		}
	}
	return false
}
