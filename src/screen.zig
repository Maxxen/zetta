const std = @import("std");
const os = std.os;

const stdout = std.io.getStdOut().outStream();
pub fn clear() !void {
    _ = try stdout.print("{}", .{"\x1b[2J"});
    _ = try stdout.print("{}", .{"\x1b[H"});
}
