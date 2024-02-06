module os

// stat returns a platform-agnostic Stat struct comparable to what is
// available in other programming languages and fails with the POSIX
// error if the stat call fails. If a link is stat'd, the stat info
// for the link is provided.
pub fn stat(path string) !Stat {
	mut s := C.stat{}
	unsafe {
		res := C.lstat(&char(path.str), &s)
		if res != 0 {
			return error_posix()
		}
		return Stat{
			dev: s.st_dev
			inode: s.st_ino
			nlink: s.st_nlink
			mode: s.st_mode
			uid: s.st_uid
			gid: s.st_gid
			rdev: s.st_rdev
			size: s.st_size
			atime: s.st_atime
			mtime: s.st_mtime
			ctime: s.st_ctime
		}
	}
}

// get_filetype returns the FileType from the Stat struct
pub fn (st Stat) get_filetype() FileType {
	match st.mode & u32(C.S_IFMT) {
		u32(C.S_IFREG) {
			return .regular
		}
		u32(C.S_IFDIR) {
			return .directory
		}
		u32(C.S_IFCHR) {
			return .character_device
		}
		u32(C.S_IFBLK) {
			return .block_device
		}
		u32(C.S_IFIFO) {
			return .fifo
		}
		u32(C.S_IFLNK) {
			return .symbolic_link
		}
		u32(C.S_IFSOCK) {
			return .socket
		}
		else {
			return .unknown
		}
	}
}

// get_mode returns the file type and permissions (readable, writable, executable)
// in owner/group/others format
pub fn (st Stat) get_mode() FileMode {
	return FileMode{
		typ: st.get_filetype()
		owner: FilePermission{
			read: (st.mode & u32(C.S_IRUSR)) != 0
			write: (st.mode & u32(C.S_IWUSR)) != 0
			execute: (st.mode & u32(C.S_IXUSR)) != 0
		}
		group: FilePermission{
			read: (st.mode & u32(C.S_IRGRP)) != 0
			write: (st.mode & u32(C.S_IWGRP)) != 0
			execute: (st.mode & u32(C.S_IXGRP)) != 0
		}
		others: FilePermission{
			read: (st.mode & u32(C.S_IROTH)) != 0
			write: (st.mode & u32(C.S_IWOTH)) != 0
			execute: (st.mode & u32(C.S_IXOTH)) != 0
		}
	}
}
