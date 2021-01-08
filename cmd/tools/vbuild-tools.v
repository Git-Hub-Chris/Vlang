module main

import os
import testing
import v.util

// NB: tools like vdoc are compiled in their own subfolder
// => cmd/tools/vdoc/vdoc.exe
// Usually, they have several top level .v files in the
// subfolder. That is why these folders are initially skipped,
// then added as a whole after the testing.prepare_test_session call.
const tools_in_subfolders = ['vdoc']

// non_packaged_tools are tools that should not be packaged with
// prebuild versions of V, to keep the size smaller.
// They are mainly usefull for the V project itself, not to end users.
const non_packaged_tools = ['gen1m', 'gen_vc', 'fast', 'wyhash']

fn main() {
	util.ensure_modules_for_all_tools_are_installed('-v' in os.args)
	args_string := os.args[1..].join(' ')
	vexe := os.getenv('VEXE')
	vroot := os.dir(vexe)
	os.chdir(vroot)
	folder := 'cmd/tools'
	tfolder := os.join_path(vroot, 'cmd', 'tools')
	main_label := 'Building $folder ...'
	finish_label := 'building $folder'
	//
	mut skips := []string{}
	for stool in tools_in_subfolders {
		skips << os.join_path(tfolder, stool)
	}
	buildopts := args_string.all_before('build-tools')
	mut session := testing.prepare_test_session(buildopts, folder, skips, main_label)
	session.rm_binaries = false
	for stool in tools_in_subfolders {
		session.add(os.join_path(tfolder, stool))
	}
	session.test()
	eprintln(session.benchmark.total_message(finish_label))
	if session.failed {
		exit(1)
	}
	//
	mut executables := os.ls(session.vtmp_dir) ?
	executables.sort()
	for texe in executables {
		tname := texe.replace(os.file_ext(texe), '')
		if tname in non_packaged_tools {
			continue
		}
		//
		tpath := os.join_path(session.vtmp_dir, texe)
		if tname in tools_in_subfolders {
			os.mv_by_cp(tpath, os.join_path(tfolder, tname, texe))
			continue
		}
		os.mv_by_cp(tpath, os.join_path(tfolder, texe))
	}
}
