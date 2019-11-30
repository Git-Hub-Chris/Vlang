import log

fn main() {
	mut l := log.Log{}
	l.set_level(log.INFO)
	// Make a new file called info.log in the current folder
	l.set_full_logpath('./info')
  println('Please check the file: ${l.output_file_name} after this example crashes.')
  
	l.info('info')
	l.warn('warn')
	l.error('error')
	l.debug('no debug')
	l.set_level(log.DEBUG)
	l.debug('debug')
	l.fatal('fatal')
}
