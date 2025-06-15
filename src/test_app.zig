
const std = @import("std");
const windows = std.os.windows;

extern "user32" fn MessageBoxA(
    ?windows.HWND, 
    ?windows.LPCSTR, 
    ?windows.LPCSTR, 
    windows.UINT
) c_int;

fn validate_password(pw: [*:0]const u8) bool {
    return std.mem.eql(u8, std.mem.span(pw), "hunter2");
}

pub fn main() !void {
    _ = MessageBoxA(null, "Hello, this is a program speaking!", "Greetings", 0);
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try stdout.print("Usage: {s} <password>\n", .{args[0]});
        return;
    }

    const password = args[1];

    if (validate_password(password)) {
        try stdout.print("Access granted!\n", .{});
        _ = MessageBoxA(null, "Access granted!", "Info", 0);
    } else {
        try stdout.print("Access denied.\n", .{});
    }

    try stdout.print("Done.\n", .{});
}
