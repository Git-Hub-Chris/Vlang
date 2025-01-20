module sqlite

import regex { regex_opt }

$if freebsd || openbsd {
	#flag -I/usr/local/include
	#flag -L/usr/local/lib
}
$if windows {
	#flag windows -I@VEXEROOT/thirdparty/sqlite
	#flag windows -L@VEXEROOT/thirdparty/sqlite
	#flag windows @VEXEROOT/thirdparty/sqlite/sqlite3.o
	#include "sqlite3.h" # The SQLite header file is missing. Please run .github/workflows/windows-install-sqlite.bat to download an SQLite amalgamation.
} $else {
	#flag -lsqlite3
	#include "sqlite3.h" # The SQLite header file is missing. Please install its development package first.
}

// https://www.sqlite.org/rescode.html
pub const sqlite_ok = 0
pub const sqlite_error = 1
pub const sqlite_row = 100
pub const sqlite_done = 101
pub const sqlite_cantopen = 14
pub const sqlite_ioerr_read = 266
pub const sqlite_ioerr_short_read = 522
pub const sqlite_ioerr_write = 778
pub const sqlite_ioerr_fsync = 1034
pub const sqlite_ioerr_fstat = 1802
pub const sqlite_ioerr_delete = 2570

pub const sqlite_open_main_db = 0x00000100
pub const sqlite_open_temp_db = 0x00000200
pub const sqlite_open_transient_db = 0x00000400
pub const sqlite_open_main_journal = 0x00000800
pub const sqlite_open_temp_journal = 0x00001000
pub const sqlite_open_subjournal = 0x00002000
pub const sqlite_open_super_journal = 0x00004000
pub const sqlite_open_wal = 0x00080000

pub enum SyncMode {
	off
	normal
	full
}

pub enum JournalMode {
	off
	delete
	truncate
	persist
	memory
}

pub struct C.sqlite3 {
}

pub struct C.sqlite3_stmt {
}

@[heap]
pub struct Stmt {
	stmt &C.sqlite3_stmt = unsafe { nil }
	db   &DB             = unsafe { nil }
}

struct SQLError {
	MessageError
}

//
@[heap]
pub struct DB {
pub mut:
	is_open bool
mut:
	conn &C.sqlite3 = unsafe { nil }
}

// str returns a text representation of the DB
pub fn (db &DB) str() string {
	return 'sqlite.DB{ conn: ' + ptr_str(db.conn) + ' }'
}

pub struct Row {
pub mut:
	vals []string
}

pub struct QuerySet {
pub mut:
	vals map[string]string
}

//
fn C.sqlite3_open(&char, &&C.sqlite3) int

fn C.sqlite3_close(&C.sqlite3) int

fn C.sqlite3_busy_timeout(db &C.sqlite3, ms int) int

fn C.sqlite3_last_insert_rowid(&C.sqlite3) i64

//
fn C.sqlite3_prepare_v2(&C.sqlite3, &char, int, &&C.sqlite3_stmt, &&char) int

fn C.sqlite3_step(&C.sqlite3_stmt) int

fn C.sqlite3_finalize(&C.sqlite3_stmt) int

//
fn C.sqlite3_column_name(&C.sqlite3_stmt, int) &char

fn C.sqlite3_column_text(&C.sqlite3_stmt, int) &u8

fn C.sqlite3_column_int(&C.sqlite3_stmt, int) int

fn C.sqlite3_column_int64(&C.sqlite3_stmt, int) i64

fn C.sqlite3_column_double(&C.sqlite3_stmt, int) f64

fn C.sqlite3_column_count(&C.sqlite3_stmt) int

fn C.sqlite3_column_type(&C.sqlite3_stmt, int) int

//
fn C.sqlite3_errstr(int) &char

fn C.sqlite3_errmsg(&C.sqlite3) &char

fn C.sqlite3_free(voidptr)

fn C.sqlite3_changes(&C.sqlite3) int

// connect Opens the connection with a database.
pub fn connect(path string) !DB {
	db := &C.sqlite3(unsafe { nil })
	code := C.sqlite3_open(&char(path.str), &db)
	if code != 0 {
		return &SQLError{
			msg:  unsafe { cstring_to_vstring(&char(C.sqlite3_errmsg(db))) }
			code: code
		}
	}
	return DB{
		conn:    db
		is_open: true
	}
}

// close Closes the DB.
// TODO: For all functions, determine whether the connection is
// closed first, and determine what to do if it is
pub fn (mut db DB) close() !bool {
	code := C.sqlite3_close(db.conn)
	if code == 0 {
		db.is_open = false
	} else {
		return &SQLError{
			msg:  unsafe { cstring_to_vstring(&char(C.sqlite3_errmsg(db.conn))) }
			code: code
		}
	}
	return true // successfully closed
}

// Only for V ORM
fn get_int_from_stmt(stmt &C.sqlite3_stmt) int {
	x := C.sqlite3_step(stmt)
	if x != C.SQLITE_OK && x != C.SQLITE_DONE {
		C.puts(C.sqlite3_errstr(x))
	}
	res := C.sqlite3_column_int(stmt, 0)
	C.sqlite3_finalize(stmt)
	return res
}

// last_insert_rowid returns last inserted rowid
// https://www.sqlite.org/c3ref/last_insert_rowid.html
pub fn (db &DB) last_insert_rowid() i64 {
	return C.sqlite3_last_insert_rowid(db.conn)
}

// get_affected_rows_count returns `sqlite changes()` meaning amount of rows affected by most recent sql query
pub fn (db &DB) get_affected_rows_count() int {
	return C.sqlite3_changes(db.conn)
}

// q_int returns a single integer value, from the first column of the result of executing `query`, or an error on failure
pub fn (db &DB) q_int(query string) !int {
	$if trace_sqlite ? {
		eprintln('> q_int query: "${query}"')
	}
	stmt := &C.sqlite3_stmt(unsafe { nil })
	pres := C.sqlite3_prepare_v2(db.conn, &char(query.str), query.len, &stmt, 0)
	if pres != sqlite_ok {
		return db.error_message(pres, query)
	}
	defer {
		C.sqlite3_finalize(stmt)
	}
	code := C.sqlite3_step(stmt)
	if code != sqlite_row {
		return db.error_message(code, query)
	}
	res := C.sqlite3_column_int(stmt, 0)
	return res
}

// q_string returns a single string value, from the first column of the result of executing `query`, or an error on failure
pub fn (db &DB) q_string(query string) !string {
	$if trace_sqlite ? {
		eprintln('> q_string query: "${query}"')
	}
	stmt := &C.sqlite3_stmt(unsafe { nil })
	pres := C.sqlite3_prepare_v2(db.conn, &char(query.str), query.len, &stmt, 0)
	if pres != sqlite_ok {
		return db.error_message(pres, query)
	}
	defer {
		C.sqlite3_finalize(stmt)
	}
	code := C.sqlite3_step(stmt)
	if code != sqlite_row {
		return db.error_message(code, query)
	}
	val := unsafe { &u8(C.sqlite3_column_text(stmt, 0)) }
	return if val != &u8(0) { unsafe { tos_clone(val) } } else { '' }
}

// exec_map executes the query on the given `db`, and returns an array of maps of strings, or an error on failure
@[manualfree]
pub fn (db &DB) exec_map(query string) ![]map[string]string {
	$if trace_sqlite ? {
		eprintln('> exec_map query: "${query}"')
	}
	stmt := &C.sqlite3_stmt(unsafe { nil })
	mut code := C.sqlite3_prepare_v2(db.conn, &char(query.str), query.len, &stmt, 0)
	if code != sqlite_ok {
		return db.error_message(code, query)
	}
	defer {
		C.sqlite3_finalize(stmt)
	}
	nr_cols := C.sqlite3_column_count(stmt)
	mut res := 0
	mut rows := []map[string]string{}
	for {
		res = C.sqlite3_step(stmt)
		if res != 100 {
			break
		}
		mut row := map[string]string{}
		for i in 0 .. nr_cols {
			val := unsafe { &u8(C.sqlite3_column_text(stmt, i)) }
			col_char := unsafe { &u8(C.sqlite3_column_name(stmt, i)) }
			col := unsafe { col_char.vstring() }
			if val == &u8(0) {
				row[col] = ''
			} else {
				row[col] = unsafe { tos_clone(val) }
			}
		}
		rows << row
	}
	return rows
}

fn C.sqlite3_memory_used() i64

// exec executes the query on the given `db`, and returns an array of all the results, or an error on failure
@[manualfree]
pub fn (db &DB) exec(query string) ![]Row {
	$if trace_sqlite ? {
		eprintln('> exec query: "${query}"')
	}
	stmt := &C.sqlite3_stmt(unsafe { nil })
	mut code := C.sqlite3_prepare_v2(db.conn, &char(query.str), query.len, &stmt, 0)
	if code != sqlite_ok {
		return db.error_message(code, query)
	}
	defer {
		C.sqlite3_finalize(stmt)
	}
	nr_cols := C.sqlite3_column_count(stmt)
	mut res := 0
	mut rows := []Row{}
	for {
		res = C.sqlite3_step(stmt)
		// Result Code SQLITE_ROW; Another row is available
		if res != 100 {
			// C.puts(C.sqlite3_errstr(res))
			break
		}
		mut row := Row{}
		for i in 0 .. nr_cols {
			val := unsafe { &u8(C.sqlite3_column_text(stmt, i)) }
			if val == &u8(0) {
				row.vals << ''
			} else {
				row.vals << unsafe { val.vstring() }
			}
		}
		rows << row
	}
	return rows
}

// get_queryset returns the values resulting from a 'SELECT' query and the name of each column. If an alias is provided either through the 'as' command or not, the returned value becomes the alias.
@[manualfree]
pub fn (db &DB) get_queryset(query string) ![]QuerySet {
	query_lower := query.to_lower()

	// 'select' syntax verified on: https://www.sqlite.org/lang_select.html and
	// https://www.sqlite.org/syntax/join-clause.html
	mut select_header := regex_opt(r'select((\s)+(all)|(distinct)(\s)+)|(\s)+')!
	mut from := regex_opt(r'(\s)+from(\s)+')!

	// or do not include 'FROM', just like 'SELECT 1 + 1'
	if query_lower.count('select') == 1 && query_lower.contains('from') {
		// The execution of this function indicates that the passed
		// query is syntactically correct, which is why no additional verification
		rows := db.exec(query)!

		defer {
			unsafe { rows.free() }
		}

		if rows.len == 0 {
			return []QuerySet{}
		} else {
			// Finding final index of select((\s)+(all)|(distinct)(\s)+)|(\s)+ inside query_lower string
			_, end_select := select_header.match_string(query_lower)

			// Finding initial and final index of (\s)+from(\s)+ inside query_lower string
			init_from, end_from := from.find(query_lower)

			// Get fields possibly separated by ',' like: select field_1, field_2 as f2, from table_name
			fields := query.substr(end_select, init_from).split(',')

			mut query_set := []QuerySet{}
			mut tuple := map[string]string{}

			if fields[0] == '*' {
				table_name := query.substr(end_from, query.len).replace(';', '').split(' ')[0]

				// Get all fields
				all_columns_name := db.exec('pragma table_info(${table_name})')!

				defer {
					unsafe { all_columns_name.free() }
				}

				mut i := 0

				for row in rows {
					for i < row.vals.len {
						// position 1 has a database column attribute
						tuple[all_columns_name[i].vals[1]] = row.vals[i]
						i++
					}
					i = 0

					query_set << QuerySet{tuple}
					tuple = map[string]string{}
				}
			} else {
				mut i := 0

				for row in rows {
					for field in fields {
						// verifying formats like:
						// select column_1 as alias_column_1 from table_name  ->  alias creation with 'as'
						// select column_1 alias_column_1 from table_name     ->  alias creationg without 'as'
						// select column_1 from table_name -> with alias being column_1
						all_field_alias := if field.contains('as') {
							field.split('as')
						} else {
							field.split(' ')
						}

						alias := all_field_alias[all_field_alias.len - 1].replace(' ',
							'')
						tuple[alias] = row.vals[i]
						i++
					}

					i = 0
					query_set << QuerySet{tuple}
					tuple = map[string]string{}
				}
			}

			return query_set
		}
	} else {
		return &SQLError{
			msg: 'This is not a selection query or contains subqueries'
			code: sqlite.sqlite_done
		}
	}
}

// exec_one executes a query on the given `db`.
// It returns either the first row from the result, if the query was successful, or an error.
@[manualfree]
pub fn (db &DB) exec_one(query string) !Row {
	rows := db.exec(query)!
	defer {
		unsafe { rows.free() }
	}
	if rows.len == 0 {
		return &SQLError{
			msg:  'No rows'
			code: sqlite_done
		}
	}
	res := rows[0]
	return res
}

// error_message returns a proper V error, given an integer error code received from SQLite, and a query string
@[manualfree]
pub fn (db &DB) error_message(code int, query string) IError {
	errmsg := unsafe { cstring_to_vstring(&char(C.sqlite3_errmsg(db.conn))) }
	msg := '${errmsg} (${code}) (${query})'
	unsafe { errmsg.free() }
	return SQLError{
		msg:  msg
		code: code
	}
}

// exec_none executes a query, and returns the integer SQLite result code.
// Use it, in case you don't expect any row results, but still want a result code.
// e.g. for queries like these: `INSERT INTO ... VALUES (...)`
pub fn (db &DB) exec_none(query string) int {
	$if trace_sqlite ? {
		eprintln('> exec_none query: "${query}"')
	}
	stmt := &C.sqlite3_stmt(unsafe { nil })
	pres := C.sqlite3_prepare_v2(db.conn, &char(query.str), query.len, &stmt, 0)
	if pres != sqlite_ok {
		return -1
	}
	defer {
		C.sqlite3_finalize(stmt)
	}
	code := C.sqlite3_step(stmt)
	return code
}

// exec_param_many executes a query with parameters provided as ?,
// and returns either an error on failure, or the full result set on success
pub fn (db &DB) exec_param_many(query string, params []string) ![]Row {
	$if trace_sqlite ? {
		eprintln('> exec_param_many query: "${query}", params: ${params}')
	}
	mut stmt := &C.sqlite3_stmt(unsafe { nil })
	mut code := C.sqlite3_prepare_v2(db.conn, &char(query.str), -1, &stmt, 0)
	if code != 0 {
		return db.error_message(code, query)
	}
	defer {
		C.sqlite3_finalize(stmt)
	}
	for i, param in params {
		code = C.sqlite3_bind_text(stmt, i + 1, voidptr(param.str), param.len, 0)
		if code != 0 {
			return db.error_message(code, query)
		}
	}
	nr_cols := C.sqlite3_column_count(stmt)
	mut res := 0
	mut rows := []Row{}
	for {
		res = C.sqlite3_step(stmt)
		if res != sqlite_row {
			if rows.len == 0 && is_error(res) {
				return db.error_message(res, query)
			}
			break
		}
		mut row := Row{}
		for i in 0 .. nr_cols {
			val := unsafe { &u8(C.sqlite3_column_text(stmt, i)) }
			if val == &u8(0) {
				row.vals << ''
			} else {
				row.vals << unsafe { val.vstring() }
			}
		}
		rows << row
	}
	return rows
}

// exec_param executes a query with one parameter provided as a ?,
// and returns either an error on failure, or the full result set on success
pub fn (db &DB) exec_param(query string, param string) ![]Row {
	return db.exec_param_many(query, [param])
}

// create_table issues a "create table if not exists" command to the db.
// It creates the table named 'table_name', with columns generated from 'columns' array.
// The default columns type will be TEXT.
pub fn (db &DB) create_table(table_name string, columns []string) ! {
	db.exec('create table if not exists ${table_name} (' + columns.join(',\n') + ')')!
}

// busy_timeout sets a busy timeout in milliseconds.
// Sleeps for a specified amount of time when a table is locked. The handler
// will sleep multiple times until at least "ms" milliseconds of sleeping have accumulated.
// (see https://www.sqlite.org/c3ref/busy_timeout.html)
pub fn (db &DB) busy_timeout(ms int) int {
	return C.sqlite3_busy_timeout(db.conn, ms)
}

// synchronization_mode sets disk synchronization mode, which controls how
// aggressively SQLite will write data to physical storage.
// If the command fails to execute an error is returned
// .off: No syncs at all. (fastest)
// .normal: Sync after each sequence of critical disk operations.
// .full: Sync after each critical disk operation (slowest).
pub fn (db &DB) synchronization_mode(sync_mode SyncMode) ! {
	if sync_mode == .off {
		db.exec('pragma synchronous = OFF;')!
	} else if sync_mode == .full {
		db.exec('pragma synchronous = FULL;')!
	} else {
		db.exec('pragma synchronous = NORMAL;')!
	}
}

// journal_mode controls how the journal file is stored and processed.
// If the command fails to execute an error is returned
// .off: No journal record is kept. (fastest)
// .memory: Journal record is held in memory, rather than on disk.
// .delete: At the conclusion of a transaction, journal file is deleted.
// .truncate: Journal file is truncated to a length of zero bytes.
// .persist: Journal file is left in place, but the header is overwritten to indicate journal is no longer valid.
pub fn (db &DB) journal_mode(journal_mode JournalMode) ! {
	if journal_mode == .off {
		db.exec('pragma journal_mode = OFF;')!
	} else if journal_mode == .delete {
		db.exec('pragma journal_mode = DELETE;')!
	} else if journal_mode == .truncate {
		db.exec('pragma journal_mode = TRUNCATE;')!
	} else if journal_mode == .persist {
		db.exec('pragma journal_mode = PERSIST;')!
	} else if journal_mode == .memory {
		db.exec('pragma journal_mode = MEMORY;')!
	} else {
		db.exec('pragma journal_mode = MEMORY;')!
	}
}
