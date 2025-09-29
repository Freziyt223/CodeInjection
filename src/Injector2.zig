const std = @import("std");

fn stringCompare(String1: [:0]const u8, String2: [:0]const u8) bool {
  var i: u8 = 0;
  while (String1[i] == String2[i]) : (i += 1) {
    if (String1[i] == 0 or String2[i] == 0) {
      return true;
    }
  }
  return false;
}

pub fn main() !void {
  var Args = try std.process.argsWithAllocator(std.heap.page_allocator);
  _ = Args.skip();
  while (Args.next()) |Arg| {
    std.debug.print("{s}\n", .{Arg});
    if (stringCompare(Arg, "-he")) {
      std.debug.print("Hello!\n", .{});
      return;
    }
  }
  std.debug.print("No arguments passed!\n", .{});
}