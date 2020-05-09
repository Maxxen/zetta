const std = @import("std");
const os = std.os;
const screen = @import("./screen.zig");
const c = @cImport({
    @cInclude("termios.h"); // Needed for VMIN and VMAX. TODO: Submit PR?
    @cInclude("ctype.h");
});

const stdout = std.io.getStdOut().outStream();

const EditorError = error {
    TermSetAttr,
    TermGetAttr,
    Read,
};

const Editor = struct {

    // TODO: use zig.os termios instead, better error management!
    orig_term_handle: os.termios,
    term_handle: os.termios,
    
    pub fn init() !Editor {
        var term: os.termios = try os.tcgetattr(os.STDIN_FILENO);
        var orig_term: os.termios = term;
        
        const input_flags: os.tcflag_t
            = os.BRKINT
            | os.INPCK
            | os.ISTRIP
            | os.IXON
            | os.ICRNL;

        const local_flags: os.tcflag_t
            = os.ECHO
            | os.ICANON
            | os.ISIG
            | os.IEXTEN;

        const output_flags: os.tcflag_t
            = os.OPOST;
        
        const control_modes: os.tcflag_t
            = os.CS8;


        term.iflag &= ~(input_flags);
        term.lflag &= ~(local_flags);
        term.oflag &= ~(output_flags);
        term.cflag |= (control_modes);

        term.cc[c.VMIN] = 0;
        term.cc[c.VTIME] = 1;

        try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, term);
        
        return Editor {
            .orig_term_handle = orig_term,
            .term_handle = term,
        };
    }

    pub fn deInit(self: Editor) !void {
        try os.tcsetattr(os.STDIN_FILENO, os.TCSA.FLUSH, self.orig_term_handle);
        try screen.clear();
    }
};

const EditorKey = enum(u8) {
    CTRL = 0x1f,

    pub fn mod(self: EditorKey, key: u8) u8 {
        return @enumToInt(self) & key;
    }
};

fn ctrl_key(key: comptime u8) u8 {
    return comptime (key & 0x1f);
}

pub fn read_key() !u8 {
    var buf: [1]u8 = undefined;
    var nread: usize = try os.read(os.STDIN_FILENO, buf[0..]);

    // TODO: Handle multibyte chars
    // TODO: Zig apparently handles EAGAIN if "global event loop", whatever that means...
    // Otherwise make sure to catch 'ReadError.WouldBlock' (which is thrown on EAGAIN)

    while(nread != 1){
        nread = try os.read(os.STDIN_FILENO, buf[0..]);
    }
    return buf[0];
}

pub fn process_key() !bool {
    var char: u8 = try read_key();
    return switch(char) {
        comptime ctrl_key('q') => false,
        else => print: {
            _ = try stdout.print("{} ('{c}')\r\n", .{char, char});
            break :print true;},
    };
}

pub fn editor_start() !void {
    // Clear screen on error!
    var editor: Editor = try Editor.init();
    
    defer _= editor.deInit() catch unreachable;
    
    var running: bool = true;
    while(running) {
        try screen.clear();
        running = try process_key();
    }
}

pub fn main() anyerror!void {
    try editor_start();
}
