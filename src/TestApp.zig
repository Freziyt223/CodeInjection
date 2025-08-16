const std = @import("std");
const windows = std.os.windows;
const print = std.debug.print;

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
  const allocator = std.heap.page_allocator;

  const args = try std.process.argsAlloc(allocator);
  defer std.process.argsFree(allocator, args);

  if (args.len < 2) {
    print("Usage: {s} <password>\n", .{args[0]});
    return;
  }

  const password = args[1];

  if (validate_password(password)) {
    print("Access granted!\n", .{});
    _ = MessageBoxA(null, "Access granted!", "Info", 0);
  } else {
    print("Access denied.\n", .{});
  }

  print("Done.\n", .{});
}
