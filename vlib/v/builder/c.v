module builder

import os
import v.pref
import v.util
import v.gen.c

pub fn (mut b Builder) gen_c(v_files []string) string {
	b.front_and_middle_stages(v_files) or { return '' }
	// TODO: move gen.cgen() to c.gen()
	util.timing_start('C GEN')
	res := c.gen(b.parsed_files, b.table, b.pref)
	util.timing_measure('C GEN')
	// println('cgen done')
	// println(res)
	return res
}

pub fn (mut b Builder) build_c(v_files []string, out_file string) {
	b.out_name_c = out_file
	b.pref.out_name_c = os.real_path(out_file)
	b.info('build_c($out_file)')
	output2 := b.gen_c(v_files)
	os.write_file(out_file, output2) or { panic(err) }
	if b.pref.is_stats {
		b.stats_lines = output2.count('\n') + 1
		b.stats_bytes = output2.len
	}
}

pub fn (mut b Builder) compile_c() {
	if os.user_os() != 'windows' && b.pref.ccompiler == 'msvc' && !b.pref.out_name.ends_with('.c') {
		verror('Cannot build with msvc on $os.user_os()')
	}
	// cgen.genln('// Generated by V')
	// println('compile2()')
	if b.pref.is_verbose {
		println('all .v files before:')
		// println(files)
	}
	$if windows {
		b.find_win_cc() or { verror(no_compiler_error) }
		// TODO Probably extend this to other OS's?
	}
	// v1 compiler files
	// v.add_v_files_to_compile()
	// v.files << v.dir
	// v2 compiler
	// b.set_module_lookup_paths()
	mut files := b.get_builtin_files()
	files << b.get_user_files()
	b.set_module_lookup_paths()
	if b.pref.is_verbose {
		println('all .v files:')
		println(files)
	}
	mut out_name_c := b.get_vtmp_filename(b.pref.out_name, '.tmp.c')
	if b.pref.is_shared {
		out_name_c = b.get_vtmp_filename(b.pref.out_name, '.tmp.so.c')
	}
	b.build_c(files, out_name_c)
	b.cc()
}
