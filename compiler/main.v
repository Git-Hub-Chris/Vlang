// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module main

import os
import time

const (
	Version = '0.1.7'
)

// TODO no caps
enum BuildMode {
	// `v program.v'
	// Build user code only, and add pre-compiled vlib (`cc program.o builtin.o os.o...`)
	DEFAULT_MODE
	// `v -embed_vlib program.v`
	// vlib + user code in one file (slower compilation, but easier when working on vlib and cross-compiling)
	EMBED_VLIB
	// `v -lib ~/v/os`
	// build any module (generate os.o + os.vh)
	BUILD // TODO a better name would be smth like `.build_module` I think
}

fn vtmp_path() string {
	return os.home_dir() + '/.vlang/'
}

const (
	SupportedPlatforms = ['windows', 'mac', 'linux']
	TmpPath            = vtmp_path()
)

enum Os {
	MAC
	LINUX
	WINDOWS
}

enum Pass {
	// A very short pass that only looks at imports in the begginning of each file
	RUN_IMPORTS
	// First pass, only parses and saves declarations (fn signatures, consts, types).
	// Skips function bodies.
	// We need this because in V things can be used before they are declared.
	RUN_DECLS
	// Second pass, parses function bodies and generates C or machine code.
	RUN_MAIN
}

/* 
// TODO rename to: 
enum Pass {
	imports
	decls
	main
}
*/
struct V {
mut:
	build_mode BuildMode
	os         Os // the OS to build for
	nofmt      bool // disable vfmt
	out_name_c string // name of the temporary C file
	files      []string // all V files that need to be parsed and compiled
	dir        string // directory (or file) being compiled (TODO rename to path?)
	table      *Table // table with types, vars, functions etc
	cgen       *CGen // C code generator
	is_test    bool // `v test string_test.v`
	is_script  bool // single file mode (`v program.v`), `fn main(){}` can be skipped
	is_so      bool
	is_live    bool // for hot code reloading
	is_prof    bool // benchmark every function
	translated bool // `v translate doom.v` are we running V code translated from C? allow globals, ++ expressions, etc
	obfuscate  bool // `v -obf program.v`, renames functions to "f_XXX"
	lang_dir   string // "~/code/v"
	is_verbose bool // print extra information with `v.log()`
	is_run     bool // `v run program.v`
	is_play    bool // playground mode
	show_c_cmd bool // `v -show_c_cmd` prints the C command to build program.v.c
	sanitize   bool // use Clang's new "-fsanitize" option
	out_name   string // "program.exe"
	is_prod    bool // use "-O2" and skip printlns (TODO I don't thik many people want printlns to disappear in prod buidls)
	is_repl    bool
	vroot      string
}

struct REPL {
mut:
	indent int
	in_func bool
	lines[]string
	imports []string
	functions []string
}

fn main() {
	// There's no `flags` module yet, so args have to be parsed manually
	args := os.args
	// Print the version and exit.
	if '-v' in args || 'version' in args {
		println('V $Version')
		return
	}
	if '-h' in args || '--help' in args || 'help' in args {
		println(HelpText)
		return
	}
	if 'translate' in args {
		println('Translating C to V will be available in V 0.3') 
		return 
	} 
	// TODO quit if the compiler is too old 
	// u := os.file_last_mod_unix('/var/tmp/alex')
	// Create a temp directory if it's not there. 
	if !os.file_exists(TmpPath)  { 
		os.mkdir(TmpPath)
	} 
	// If there's no tmp path with current version yet, the user must be using a pre-built package
	// Copy the `vlib` directory to the tmp path.
/* 
	// TODO 
	if !os.file_exists(TmpPath) && os.file_exists('vlib') {
	}
*/ 
	// Just fmt and exit
	if args.contains('fmt') {
		file := args.last()
		if !os.file_exists(file) {
			println('"$file" does not exist')
			exit(1)
		}
		if !file.ends_with('.v') {
			println('v fmt can only be used on .v files')
			exit(1)
		}
		println('vfmt is temporarily disabled')
		return
	}
	// V with no args? REPL
	if args.len < 2 || (args.len == 2 && args[1] == '-') {
		run_repl()
		return
	}
	// Construct the V object from command line arguments
	mut c := new_v(args)
	if c.is_verbose {
		println(args)
	}
	// Generate the docs and exit
	if args.contains('doc') {
		// c.gen_doc_html_for_module(args.last())
		exit(0)
	}
	c.compile()
}

fn (c mut V) compile() {
	mut cgen := c.cgen
	cgen.genln('// Generated by V')
	// Add user files to compile
	c.add_user_v_files()
	if c.is_verbose {
		println('all .v files:')
		println(c.files)
	}
	// First pass (declarations)
	for file in c.files {
		mut p := c.new_parser(file, RUN_DECLS)
		p.parse()
	}
	// Main pass
	cgen.run = RUN_MAIN
	if c.is_play {
		cgen.genln('#define VPLAY (1) ')
	}
	cgen.genln('   
#include <stdio.h>  // TODO remove all these includes, define all function signatures and types manually 
#include <stdlib.h>
#include <signal.h>
#include <stdarg.h> // for va_list 
#include <inttypes.h>  // int64_t etc 


#ifdef __linux__ 
#include <pthread.h> 
#endif 


#ifdef __APPLE__ 

#endif 


#ifdef _WIN32 
#include <windows.h>
//#include <WinSock2.h> 
#endif 

//================================== TYPEDEFS ================================*/ 

typedef unsigned char byte;
typedef unsigned int uint;
typedef int64_t i64;
typedef int32_t i32;
typedef int16_t i16;
typedef int8_t i8;
typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t u8;
typedef uint32_t rune;
typedef float f32;
typedef double f64; 
typedef unsigned char* byteptr;
typedef int* intptr;
typedef void* voidptr;
typedef struct array array;
typedef struct map map;
typedef array array_string; 
typedef array array_int; 
typedef array array_byte; 
typedef array array_uint; 
typedef array array_float; 
typedef map map_int; 
typedef map map_string; 
#ifndef bool
	typedef int bool;
	#define true 1
	#define false 0
#endif

//============================== HELPER C MACROS =============================*/ 

#define _PUSH(arr, val, tmp, tmp_typ) {tmp_typ tmp = (val); array__push(arr, &tmp);}
#define _IN(typ, val, arr) array_##typ##_contains(arr, val) 
#define ALLOC_INIT(type, ...) (type *)memdup((type[]){ __VA_ARGS__ }, sizeof(type)) 
#define UTF8_CHAR_LEN( byte ) (( 0xE5000000 >> (( byte >> 3 ) & 0x1e )) & 3 ) + 1 

//================================== GLOBALS =================================*/   
//int V_ZERO = 0; 
byteptr g_str_buf; 
int load_so(byteptr);
void reload_so();
void init_consts();')
	imports_json := c.table.imports.contains('json')
	// TODO remove global UI hack
	if c.os == MAC && ((c.build_mode == EMBED_VLIB && c.table.imports.contains('ui')) ||
	(c.build_mode == BUILD && c.dir.contains('/ui'))) {
		cgen.genln('id defaultFont = 0; // main.v')
	}
	// TODO remove ugly .c include once V has its own json parser
	// Embed cjson either in embedvlib or in json.o
	if imports_json && c.build_mode == EMBED_VLIB ||
	(c.build_mode == BUILD && c.out_name.contains('json.o')) {
		cgen.genln('#include "cJSON.c" ')
	}
	// We need the cjson header for all the json decoding user will do in default mode
	if c.build_mode == DEFAULT_MODE {
		if imports_json {
			cgen.genln('#include "cJSON.h"')
		}
	}
	if c.build_mode == EMBED_VLIB || c.build_mode == DEFAULT_MODE {
		// If we declare these for all modes, then when running `v a.v` we'll get
		// `/usr/bin/ld: multiple definition of 'total_m'`
		// TODO
		//cgen.genln('i64 total_m = 0; // For counting total RAM allocated')
		cgen.genln('int g_test_ok = 1; ')
		if c.table.imports.contains('json') {
			cgen.genln(' 
#define js_get(object, key) cJSON_GetObjectItemCaseSensitive((object), (key))
')
		}
	}
	if os.args.contains('-debug_alloc') {
		cgen.genln('#define DEBUG_ALLOC 1')
	}
	cgen.genln('/*================================== FNS =================================*/')
	cgen.genln('this line will be replaced with definitions')
	defs_pos := cgen.lines.len - 1
	for file in c.files {
		mut p := c.new_parser(file, RUN_MAIN)
		p.parse()
		// p.g.gen_x64()
		// Format all files (don't format automatically generated vlib headers)
		if !c.nofmt && !file.contains('/vlib/') {
			// new vfmt is not ready yet
		}
	}
	c.log('Done parsing.')
	// Write everything
	mut d := new_string_builder(10000)// Just to avoid some unnecessary allocations
	d.writeln(cgen.includes.join_lines())
	d.writeln(cgen.typedefs.join_lines())
	d.writeln(cgen.types.join_lines())
	d.writeln('\nstring _STR(const char*, ...);\n')
	d.writeln('\nstring _STR_TMP(const char*, ...);\n')
	d.writeln(cgen.fns.join_lines())
	d.writeln(cgen.consts.join_lines())
	d.writeln(cgen.thread_args.join_lines())
	if c.is_prof {
		d.writeln('; // Prof counters:')
		d.writeln(c.prof_counters())
	}
	dd := d.str()
	cgen.lines.set(defs_pos, dd)// TODO `def.str()` doesn't compile
	// if c.build_mode in [.default, .embed_vlib] {
	if c.build_mode == DEFAULT_MODE || c.build_mode == EMBED_VLIB {
		// vlib can't have `init_consts()`
		cgen.genln('void init_consts() { g_str_buf=malloc(1000); ${cgen.consts_init.join_lines()} }')
		// _STR function can't be defined in vlib
		cgen.genln('
string _STR(const char *fmt, ...) {
	va_list argptr;
	va_start(argptr, fmt);
	size_t len = vsnprintf(0, 0, fmt, argptr) + 1;  
	va_end(argptr);
	byte* buf = malloc(len);  
	va_start(argptr, fmt);
	vsprintf(buf, fmt, argptr);
	va_end(argptr);
#ifdef DEBUG_ALLOC 
	puts("_STR:"); 
	puts(buf); 
#endif 
	return tos2(buf);
}

string _STR_TMP(const char *fmt, ...) {
	va_list argptr;
	va_start(argptr, fmt);
	size_t len = vsnprintf(0, 0, fmt, argptr) + 1;  
	va_end(argptr);
	va_start(argptr, fmt);
	vsprintf(g_str_buf, fmt, argptr);
	va_end(argptr);
#ifdef DEBUG_ALLOC 
	//puts("_STR_TMP:"); 
	//puts(g_str_buf); 
#endif 
	return tos2(g_str_buf);
}

')
	}
	// Make sure the main function exists
	// Obviously we don't need it in libraries
	if c.build_mode != BUILD {
		if !c.table.main_exists() && !c.is_test {
			// It can be skipped in single file programs
			if c.is_script {
				println('Generating main()...')
				cgen.genln('int main() { $cgen.fn_main; return 0; }')
			}
			else {
				println('panic: function `main` is undeclared in the main module')
			}
		}
		// Generate `main` which calls every single test function
		else if c.is_test {
			cgen.genln('int main() { init_consts();')
			for v in c.table.fns {
				if v.name.starts_with('test_') {
					cgen.genln('$v.name();')
				}
			}
			cgen.genln('return g_test_ok == 0; }')
		}
	}
	if c.is_live {
		cgen.genln(' int load_so(byteptr path) {
	 printf("load_so %s\\n", path); dlclose(live_lib); live_lib = dlopen(path, RTLD_LAZY);
	 if (!live_lib) {puts("open failed"); exit(1); return 0;}
	 ')
		for so_fn in cgen.so_fns {
			cgen.genln('$so_fn = dlsym(live_lib, "$so_fn");  ')
		}
		cgen.genln('return 1; }')
	}
	cgen.save()
	c.log('flags=')
	if c.is_verbose {
		println(c.table.flags)
	}
	c.cc()
	if c.is_test || c.is_run {
		if true || c.is_verbose {
			println('============running $c.out_name==============================')
		}
		mut cmd := if c.out_name.starts_with('/') {
			c.out_name
		}
		else {
			'./' + c.out_name
		}
		if os.args.len > 3 {
			cmd += ' ' + os.args.right(3).join(' ')
		}
		ret := os.system(cmd)
		if ret != 0 {
			s := os.exec(cmd)
			println(s)
			println('ret not 0, exiting')
			exit(1)
		}
	}
}

fn (c mut V) cc() {
	linux_host := os.user_os() == 'linux'
	c.log('cc() isprod=$c.is_prod outname=$c.out_name')
	mut a := ['-w']// arguments for the C compiler
	flags := c.table.flags.join(' ')
	/* 
	mut shared := ''
	if c.is_so {
		a << '-shared'// -Wl,-z,defs'
		c.out_name = c.out_name + '.so'
	}
*/
	if c.is_prod {
		a << '-O2'
	}
	else {
		a << '-g'
	}
	mut libs := ''// builtin.o os.o http.o etc
	if c.build_mode == BUILD {
		a << '-c'
	}
	else if c.build_mode == EMBED_VLIB {
		// 
	}
	else if c.build_mode == DEFAULT_MODE {
		libs = '$TmpPath/vlib/builtin.o'
		if !os.file_exists(libs) {
			println('`builtin.o` not found')
			exit(1)
		}
		for imp in c.table.imports {
			if imp == 'webview' {
				continue
			}
			libs += ' $TmpPath/vlib/${imp}.o'
		}
	}
	// -I flags
	/* 
mut args := '' 
	for flag in c.table.flags {
		if !flag.starts_with('-l') {
			args += flag
			args += ' '
		}
	}
*/
	if c.sanitize {
		a << '-fsanitize=leak'
	}
	// Cross compiling linux
	sysroot := '/Users/alex/tmp/lld/linuxroot/'
	if c.os == LINUX && !linux_host {
		// Build file.o
		a << '-c --sysroot=$sysroot -target x86_64-linux-gnu'
		// Right now `out_name` can be `file`, not `file.o`
		if !c.out_name.ends_with('.o') {
			c.out_name = c.out_name + '.o'
		}
	}
	// Cross compiling windows
	// sysroot := '/Users/alex/tmp/lld/linuxroot/'
	// Output executable name
	// else {
	a << '-o $c.out_name'
	// The C file we are compiling
	a << '$TmpPath/$c.out_name_c'
	// }
	// Min macos version is mandatory I think?
	if c.os == MAC {
		a << '-mmacosx-version-min=10.7'
	}
	a << flags
	a << libs
	// macOS code can include objective C  TODO remove once objective C is replaced with C
	if c.os == MAC {
		a << '-x objective-c'
	}
	// Without these libs compilation will fail on Linux
	if c.os == LINUX && c.build_mode != BUILD {
		a << '-lm -ldl -lpthread'
	}
	// Find clang executable
	fast_clang := '/usr/local/Cellar/llvm/8.0.0/bin/clang'
	args := a.join(' ')
	cmd := if os.file_exists(fast_clang) {
		'$fast_clang -I. $args'
	}
	else {
		'cc -I. $args'
	}
	// Print the C command
	if c.show_c_cmd || c.is_verbose {
		println('\n==========\n$cmd\n=========\n')
	}
	// Run
	res := os.exec(cmd)
	// println('C OUTPUT:')
	if res.contains('error: ') {
		println(res)
		panic('clang error')
	}
	// Link it if we are cross compiling and need an executable
	if c.os == LINUX && !linux_host && c.build_mode != BUILD {
		c.out_name = c.out_name.replace('.o', '')
		obj_file := c.out_name + '.o'
		println('linux obj_file=$obj_file out_name=$c.out_name')
		ress := os.exec('/usr/local/Cellar/llvm/8.0.0/bin/ld.lld --sysroot=$sysroot ' +
		'-v -o $c.out_name ' +
		'-m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2 ' +
		'/usr/lib/x86_64-linux-gnu/crt1.o ' +
		'$sysroot/lib/x86_64-linux-gnu/libm-2.28.a ' +
		'/usr/lib/x86_64-linux-gnu/crti.o ' +
		obj_file +
		' /usr/lib/x86_64-linux-gnu/libc.so ' +
		'/usr/lib/x86_64-linux-gnu/crtn.o')
		println(ress)
		if ress.contains('error:') {
			exit(1)
		}
		println('linux cross compilation done. resulting binary: "$c.out_name"')
	}
	// print_time('after gcc')
}

fn (c &V) v_files_from_dir(dir string) []string {
	mut res := []string
	if !os.file_exists(dir) {
		panic('$dir doesn\'t exist')
	} else if !os.dir_exists(dir) {
		panic('$dir isn\'t a directory')
	}
	mut files := os.ls(dir)
	if c.is_verbose {
		println('v_files_from_dir ("$dir")')
	}
	// println(files.len)
	// println(files)
	files.sort()
	for file in files {
		c.log('F=$file')
		if !file.ends_with('.v') && !file.ends_with('.vh') {
			continue
		}
		if file.ends_with('_test.v') {
			continue
		}
		if file.ends_with('_win.v') && c.os != WINDOWS {
			continue
		}
		if file.ends_with('_lin.v') && c.os != LINUX {
			continue
		}
		if file.ends_with('_mac.v') && c.os != MAC {
			lin_file := file.replace('_mac.v', '_lin.v')
			// println('lin_file="$lin_file"')
			// If there are both _mac.v and _lin.v, don't use _mac.v
			if os.file_exists('$dir/$lin_file') {
				continue
			}
			else if c.os == WINDOWS {
				continue
			}
			else {
				// If there's only _mac.v, then it can be used on Linux too
			}
		}
		res << '$dir/$file'
	}
	return res
}

// Parses imports, adds necessary libs, and then user files
fn (c mut V) add_user_v_files() {
	mut dir := c.dir
	c.log('add_v_files($dir)')
	// Need to store user files separately, because they have to be added after libs, but we dont know
	// which libs need to be added yet
	mut user_files := []string
	// v volt/slack_test.v: compile all .v files to get the environment
	// I need to implement user packages! TODO
	is_test_with_imports := dir.ends_with('_test.v') &&
	(dir.contains('/volt') || dir.contains('/c2volt'))// TODO
	if is_test_with_imports {
		user_files << dir
		pos := dir.last_index('/')
		dir = dir.left(pos) + '/'// TODO WHY IS THIS NEEDED?
	}
	if dir.ends_with('.v') {
		// Just compile one file and get parent dir
		user_files << dir
		dir = dir.all_before('/')
	}
	else {
		// Add files from the dir user is compiling (only .v files)
		files := c.v_files_from_dir(dir)
		for file in files {
			user_files << file
		}
	}
	if user_files.len == 0 {
		println('No input .v files')
		exit(1)
	}
	if c.is_verbose {
		c.log('user_files:')
		println(user_files)
	}
	// Parse user imports
	for file in user_files {
		mut p := c.new_parser(file, RUN_IMPORTS)
		p.parse()
	}
	// Parse lib imports
	if c.build_mode == DEFAULT_MODE {
		for i := 0; i < c.table.imports.len; i++ {
			pkg := c.table.imports[i]
			vfiles := c.v_files_from_dir('$TmpPath/vlib/$pkg')
			// Add all imports referenced by these libs
			for file in vfiles {
				mut p := c.new_parser(file, RUN_IMPORTS)
				p.parse()
			}
		}
	}
	else {
		// TODO this used to crash compiler?
		// for pkg in c.table.imports {
		for i := 0; i < c.table.imports.len; i++ {
			pkg := c.table.imports[i]
			// mut import_path := '$c.lang_dir/$pkg'
			vfiles := c.v_files_from_dir('$c.lang_dir/$pkg')
			// Add all imports referenced by these libs
			for file in vfiles {
				mut p := c.new_parser(file, RUN_IMPORTS)
				p.parse()
			}
		}
	}
	if c.is_verbose {
		c.log('imports:')
		println(c.table.imports)
	}
	// Only now add all combined lib files
	for pkg in c.table.imports {
		mut module_path := '$c.lang_dir/$pkg'
		// If we are in default mode, we don't parse vlib .v files, but header .vh files in
		// TmpPath/vlib
		// These were generated by vfmt
		if c.build_mode == DEFAULT_MODE || c.build_mode == BUILD {
			module_path = '$TmpPath/vlib/$pkg'
		}
		vfiles := c.v_files_from_dir(module_path)
		for vfile in vfiles {
			c.files << vfile
		}
		// TODO c.files.append_array(vfiles)
	}
	// Add user code last
	for file in user_files {
		c.files << file
	}
	// c.files.append_array(user_files)
}

fn get_arg(joined_args, arg, def string) string {
	key := '-$arg '
	mut pos := joined_args.index(key)
	if pos == -1 {
		return def
	}
	pos += key.len
	mut space := joined_args.index_after(' ', pos)
	if space == -1 {
		space = joined_args.len
	}
	res := joined_args.substr(pos, space)
	// println('get_arg($arg) = "$res"')
	return res
}

fn (c &V) log(s string) {
	if !c.is_verbose {
		return
	}
	println(s)
}

fn new_v(args[]string) *V {
	mut dir := args.last()
	if args.contains('run') {
		dir = args[2]
	}
	// println('new compiler "$dir"')
	if args.len < 2 {
		dir = ''
	}
	joined_args := args.join(' ')
	target_os := get_arg(joined_args, 'os', '')
	mut out_name := get_arg(joined_args, 'o', 'a.out')
	// build mode
	mut build_mode := DEFAULT_MODE
	if args.contains('-lib') {
		build_mode = BUILD
		// v -lib ~/v/os => os.o
		base := dir.all_after('/')
		println('Building module ${base}...')
		out_name = '$TmpPath/vlib/${base}.o'
		// Cross compiling? Use separate dirs for each os
		if target_os != os.user_os() {
			os.mkdir('$TmpPath/vlib/$target_os')
			out_name = '$TmpPath/vlib/$target_os/${base}.o'
			println('Cross compiling $out_name')
		}
	}
	// TODO embed_vlib is temporarily the default mode. It's much slower.
	else if !args.contains('-embed_vlib') {
		build_mode = EMBED_VLIB
	}
	// 
	is_test := dir.ends_with('_test.v')
	is_script := dir.ends_with('.v')
	if is_script && !os.file_exists(dir) {
		println('`$dir` does not exist')
		exit(1)
	}
	// No -o provided? foo.v => foo
	if out_name == 'a.out' && dir.ends_with('.v') {
		out_name = dir.left(dir.len - 2)
	}
	// if we are in `/foo` and run `v .`, the executable should be `foo`
	if dir == '.' && out_name == 'a.out' {
		base := os.getwd().all_after('/')
		out_name = base.trim_space()
	}
	mut _os := MAC
	// No OS specifed? Use current system
	if target_os == '' {
		$if linux {
			_os = LINUX
		}
		$if mac {
			_os = MAC
		}
		$if windows {
			_os = WINDOWS
		}
	}
	else {
		switch target_os {
		case 'linux': _os = LINUX
		case 'windows': _os = WINDOWS
		case 'mac': _os = MAC
		}
	}
	builtins := [
	'array.v',
	'string.v',
	'builtin.v',
	'int.v',
	'utf8.v',
	'map.v',
	'option.v',
	'string_builder.v',
	]
	// Location of all vlib files
	mut lang_dir = ''
	// First try fetching it from VROOT if it's defined
	for { // TODO tmp hack for optionals
	vroot_path := TmpPath + '/VROOT'
	if os.file_exists(vroot_path) {
		mut vroot := os.read_file(vroot_path) or {
			break
		}
		vroot=vroot.trim_space() 
		if os.dir_exists(vroot) && os.dir_exists(vroot + '/builtin') {
			lang_dir = vroot
		}
	}
	break
	}
	// no "~/.vlang/VROOT" file, so the user must be running V for the first 
	// time.
	if lang_dir == ''  {
		println('Looks like you are running V for the first time.')
		// The parent directory should contain vlib if V is run
		// from "v/compiler"
		cur_dir := os.getwd()
		lang_dir = cur_dir.all_before_last('/')
		if os.dir_exists('$lang_dir/builtin') {
			println('Setting VROOT to "$lang_dir".')
			os.write_file(TmpPath + '/VROOT', lang_dir)
		} else {
			println('V repo not found. Cloning...') 
			os.mv('v', 'v.bin') 
			os.exec('git clone https://github.com/vlang/v') 
			if !os.dir_exists('v') {
				println('failed to clone github.com/vlang/v') 
				exit(1) 
			} 
			os.mv('v.bin', 'v/compiler/v') 
			println('Re-launch V from v/compiler') 
			exit(1) 
		}
	} 
	out_name_c := out_name.all_after('/') + '.c'
	mut files := []string
	// Add builtin files
	if !out_name.contains('builtin.o') {
		for builtin in builtins {
			mut f := '$lang_dir/builtin/$builtin'
			// In default mode we use precompiled vlib.o, point to .vh files with signatures
			if build_mode == DEFAULT_MODE || build_mode == BUILD {
				f = '$TmpPath/vlib/builtin/${builtin}h'
			}
			files << f
		}
	}
	obfuscate := args.contains('-obf')
	return &V {
		os: _os
		out_name: out_name
		files: files
		dir: dir
		lang_dir: lang_dir
		table: new_table(obfuscate)
		out_name: out_name
		out_name_c: out_name_c
		is_test: is_test
		is_script: is_script
		is_so: args.contains('-shared')
		is_play: args.contains('play')
		is_prod: args.contains('-prod')
		is_verbose: args.contains('-verbose')
		obfuscate: obfuscate
		is_prof: args.contains('-prof')
		is_live: args.contains('-live')
		sanitize: args.contains('-sanitize')
		nofmt: args.contains('-nofmt')
		show_c_cmd: args.contains('-show_c_cmd')
		translated: args.contains('translated')
		cgen: new_cgen(out_name_c)
		build_mode: build_mode
		is_run: args.contains('run')
		is_repl: args.contains('-repl')
		vroot: lang_dir
	}
}

fn (r mut REPL) repl_checks(line string) {
	mut in_string := false

	for i := 0; i < line.len; i++ {
		if line[i] == `\'` && line[i - 1] != `\\` {
			in_string = !in_string
		}
		if line[i] == `{` && !in_string {
			r.indent++
		}
		if line[i] == `}` && !in_string {
			r.indent--
			if r.indent == 0 {
				r.in_func = false
			}
		}
		if i + 2 < line.len && r.indent == 0 && line[i + 1] == `f` && line[i + 2] == `n` {
			r.in_func = true
		}
	}
}

fn run_repl() []string {
	println('V $Version')
	println('Use Ctrl-D to exit')
	println('For now you have to use println() to print values, this will be fixed soon\n')
	file := TmpPath + '/vrepl.v'
	mut r := REPL{0, false, []string, []string, []string}

	for {
		// Add indentation for better visual about being inside a function
		print('>>> ')
		for i := 0 ; i < r.indent ; i++ {
			print('  ')
		}
		line := os.get_line().trim_space()
		if line == '' {
			break
		}

		// If the line starts with fn, saves next lines as functions
		// It prevents writing functions in main, which do not compile
		if line.starts_with('fn') {
			r.in_func = true
		}
		if r.in_func {
			// If open bracket add an indentation
			// If closing bracket remove an indentation and check if exits the function
			r.repl_checks(line)
			r.functions << line
		} else {
			// Save the source only if the user is printing something,
			// but don't add this print call to the `lines` array,
			// so that it doesn't get called during the next print.
			if line.starts_with('print') {
				// TODO remove this once files without main compile correctly
				void_line := line.substr(line.index('(') + 1, line.len - 1)
				r.lines << void_line
				source_code := r.imports.join('\n') + '\n' + r.functions.join('\n') + '\n' + 'fn main(){' + r.lines.join('\n') + '\n' + line + '}'
				os.write_file(file, source_code)
				mut v := new_v( ['v', '-repl', file])
				v.compile()
				s := os.exec(TmpPath + '/vrepl')
				println(s)
			}
			else if line.starts_with('import') {
				r.imports << line
			}
			else {
				r.lines << line
			}
		}
	}
	return r.lines
}

// This definitely needs to be better :)
const (
	HelpText = '
Usage: v [options] [file | directory]

Options:
  -                 Read from stdin (Default; Interactive mode if in a tty)
  -h, --help, help  Display this information.
  -v, version       Display compiler version.
  -prod             Build an optimized executable.
  -o <file>         Place output into <file>.
  -obf              Obfuscate the resulting binary.
  run               Build and execute a V program.
                    You can add arguments after file name.
Files:
  <file>_test.v     Test file.
'
)

/* 
- To disable automatic formatting: 
v -nofmt file.v

- To build a program with an embedded vlib  (use this if you do not have prebuilt vlib libraries or if you
are working on vlib) 
v -embed_vlib file.v 
*/
