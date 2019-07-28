// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

module term

import os

// Calling this functions enables color terminal output on windows
// Maybe implement a way to auto run an init function when a module
// is imported on a certain os. for example to run this?
pub fn enable_term_color_win() {
    $if windows {
        mode_wanted := os.ENABLE_PROCESSED_OUTPUT | os.ENABLE_VIRTUAL_TERMINAL_PROCESSING
        mut mode_current := 0
        h_output := C.GetStdHandle(os.STD_OUTPUT_HANDLE)
        if h_output == os.INVALID_HANDLE_VALUE {
            panic('term.enable_term_color_win(): error getting output handle.')
        }
        if !C.GetConsoleMode(h_output, &mode_current) {
            panic('term.enable_term_color_win(): error getting console mode.')
        }
        if mode_current == mode_wanted {
            return
        }
        if !C.SetConsoleMode(h_output, mode_wanted) {
            panic('term.enable_term_color_win(): error setting console mode.')
        }
    }
    $else {
        println('term.enable_term_color_win(): should only be called on windows.')
    }
}

pub fn format(msg, open, close string) string {
    $if windows {
        enable_term_color_win()
    }

    return '\x1b[' + open + 'm' + msg + '\x1b[' + close + 'm'
}

pub fn bg_black(msg string) string {
    return format(msg, '40', '49')
}

pub fn bg_blue(msg string) string {
    return format(msg, '44', '49')
}

pub fn bg_cyan(msg string) string {
    return format(msg, '46', '49')
}

pub fn bg_green(msg string) string {
    return format(msg, '42', '49')
}

pub fn bg_magenta(msg string) string {
    return format(msg, '45', '49')
}

pub fn bg_red(msg string) string {
    return format(msg, '41', '49')
}

pub fn bg_white(msg string) string {
    return format(msg, '47', '49')
}

pub fn bg_yellow(msg string) string {
    return format(msg, '43', '49')
}

pub fn black(msg string) string {
    return format(msg, '30', '39')
}

pub fn blue(msg string) string {
    return format(msg, '34', '39')
}

pub fn bold(msg string) string {
    return format(msg, '1', '22')
}

pub fn cyan(msg string) string {
    return format(msg, '36', '39')
}

pub fn dim(msg string) string {
    return format(msg, '2', '22')
}

pub fn green(msg string) string {
    return format(msg, '32', '39')
}

pub fn gray(msg string) string {
    return format(msg, '90', '39')
}

pub fn hidden(msg string) string {
    return format(msg, '8', '28')
}

pub fn italic(msg string) string {
    return format(msg, '3', '23')
}

pub fn inverse(msg string) string {
    return format(msg, '7', '27')
}

pub fn magenta(msg string) string {
    return format(msg, '35', '39')
}

pub fn reset(msg string) string {
    return format(msg, '0', '0')
}

pub fn red(msg string) string {
    return format(msg, '31', '39')
}

pub fn strikethrough(msg string) string {
    return format(msg, '9', '29')
}

pub fn underline(msg string) string {
    return format(msg, '4', '24')
}

pub fn white(msg string) string {
    return format(msg, '37', '39')
}

pub fn yellow(msg string) string {
    return format(msg, '33', '39')
}
