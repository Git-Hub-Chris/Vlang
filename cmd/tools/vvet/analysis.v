// Copyright (c) 2025 Felipe Pena. All rights reserved.
// Use of this source code is governed by an MIT license that can be found in the LICENSE file.
module main

import v.ast
import v.token
import arrays

struct VetAnalysis {
mut:
	repeated_global    shared map[string]map[string][]token.Pos            // repeated exprs in whole codebase
	repeated_fn_scoped shared map[string]map[string]map[string][]token.Pos // repeated exprs in fn scope
	cur_fn             ast.FnDecl // current fn declaration
}

fn (mut vt Vet) add_repeated_code(expr string, pos token.Pos) {
	lock vt.analysis.repeated_global {
		vt.analysis.repeated_global[expr][vt.file] << pos
	}
	lock vt.analysis.repeated_fn_scoped {
		vt.analysis.repeated_fn_scoped[vt.analysis.cur_fn.name][expr][vt.file] << pos
	}
}

fn (mut vt Vet) repeated_code(expr ast.Expr) {
	match expr {
		ast.IndexExpr {
			vt.add_repeated_code('${expr.left}[${expr.index}]', expr.pos)
		}
		ast.SelectorExpr {
			// nested selectors
			if expr.expr is ast.SelectorExpr {
				vt.add_repeated_code('${ast.Expr(expr.expr).str()}.${expr.field_name}',
					expr.pos)
			}
		}
		ast.CallExpr {
			if expr.is_static_method || expr.is_method {
				vt.add_repeated_code('${expr.left}.${expr.name}(${expr.args.map(it.str()).join(', ')})',
					expr.pos)
			} else {
				vt.add_repeated_code('${expr.name}(${expr.args.map(it.str()).join(', ')})',
					expr.pos)
			}
		}
		else {}
	}
}

fn (mut vt Vet) long_or_empty_fns(fn_decl ast.FnDecl) {
	nr_lines := if fn_decl.stmts.len == 0 {
		0
	} else {
		fn_decl.stmts.last().pos.line_nr - fn_decl.pos.line_nr
	}
	if nr_lines > 300 {
		vt.notice('Long function - ${nr_lines} lines long.', fn_decl.pos.line_nr, .long_fns)
	} else if nr_lines == 0 {
		vt.notice('Empty function.', fn_decl.pos.line_nr, .empty_fn)
	}
}

fn (mut vt Vet) vet_repeated_code() {
	rlock vt.analysis.repeated_global {
		for expr, info in vt.analysis.repeated_global {
			occurrences := arrays.sum(info.values().map(it.len)) or { 0 }
			if occurrences < 30 {
				continue
			}
			for file, info_pos in info {
				for pos in info_pos {
					vt.notice_with_file(file, '${expr} occurs ${occurrences} times on ${info.len} file(s).',
						pos.line_nr, .repeated_code)
				}
			}
		}
	}

	rlock vt.analysis.repeated_fn_scoped {
		for fn_name, ref_expr in vt.analysis.repeated_fn_scoped {
			scope_name := if fn_name == '' { 'global scope' } else { 'function scope (${fn_name})' }
			for expr, info in ref_expr {
				occurrences := arrays.sum(info.values().map(it.len)) or { 0 }
				if occurrences < 15 {
					continue
				}
				for file, info_pos in info {
					for pos in info_pos {
						vt.notice_with_file(file, '${expr} occurs ${occurrences} times in ${scope_name}.',
							pos.line_nr, .repeated_code)
					}
				}
			}
		}
	}
}

fn (mut vt Vet) vet_code_analysis() {
	if vt.opt.repeated_code {
		vt.vet_repeated_code()
	}
}
