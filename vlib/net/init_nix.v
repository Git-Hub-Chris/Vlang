module net

#include <sys/socket.h>
#include <unistd.h>
#include <netinet/in.h>
#include <netdb.h>
#include <errno.h>

const(
    ERROR_CODES = {
        //socket creation errors
        "not_authorized": C.EACCES,
        "not_supported": C.EAFNOSUPPORT,
        "invalid": C.EINVAL,//exact signification depending on the context
        "no_buffer": C.ENOBUFS,
        "m_file": C.EMFILE,
        "no_memory": C.WSA_NOT_ENOUGH_MEMORY,
        "protocol_not_supported": C.EPROTONOSUPPORT,
        
        //connection errors
        "connection_refused": C.ECONNREFUSED,
        "memory_fault": C.EFAULT,
        "again": C.EAGAIN,
        "would_block":C.EWOULDBLOCK,
        "invalid_descriptor": C.EBADF,
        "interrupted": C.EINTR,
        "address_unavailable": C.EADDRNOTAVAIL,
        "address_in_use": C.EADDRINUSE,
        "op_not_supported": C.EOPNOTSUPP,
        "not_connected": C.ENOTCONN,
        "connection_reset": C.ECONNRESET,
        "required_dest_addr": C.EDESTADDRREQ,
        "msg_size": C.EMSGSIZE,
        "host_down": C.EHOSTDOWN,
        "host_unreachable": C.EHOSTUNREACH,



        //linux specific:
        "n_file": C.ENFILE,
        "pipe": C.EPIPE,
        "loop": C.ELOOP,
        "name_too_long": C.ENAMETOOLONG,
        "no_file": C.ENOENT,
        "not_dir": C.ENOTDIR,
        "read_only": C.EROFS,
        "firewall_error": C.EPERM
    }
)

pub fn error_code() int {
    return C.errno
}
