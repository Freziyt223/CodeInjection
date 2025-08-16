const print = @import("std").debug.print;
const windows = @import("std").os.windows;
const std = @import("std");

extern "kernel32" fn GetModuleHandleA(
  Name: ?windows.LPCSTR
) callconv(.winapi) windows.HMODULE;

extern "user32" fn MessageBoxA(
  HWND: ?windows.HWND,
  Text: ?windows.LPCSTR,
  Caption: ?windows.LPCSTR,
  Type: windows.UINT
) callconv(.winapi) c_int;

var OriginalBytes: [12]u8 = undefined;
var Function: *fn([*:0]const u8) bool = undefined;
var FunctionSlice: *[12]u8 = undefined;
var OldProtect: u32 = 0;

fn MyHook(Password: [*:0]const u8) bool {
  const Formatted = std.fmt.allocPrintZ(std.heap.page_allocator, "Don't forget password: {s}", .{Password}) catch {print("Out of Memory!", .{}); return false;};
  _ = MessageBoxA(null, Formatted, "Finaly works", 0); 
  RevertInsert();
  const Return = Function(Password);
  InsertJumpToHook();
  return Return;
}

var ShellCode: [12]u8 = .{
  0x48, 0xB8,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0xFF, 0xE0
};

const Pattern: [18]u8 = .{
  0x55, 0x48, 0x83, 0xEC, 0x50, 0x48, 0x8D, 0x6C,
  0x24, 0x50, 0x48, 0x89, 0x4D, 0xE0, 0x48, 0x89,
  0x55, 0xE8
};

fn findFunctionMemory() ?[*]u8 {
  var Address: usize = 0;
  var LocalMemoryPosition: usize = 0;
  var LocalPatternPosition: usize = 0;
  var Equal: u8 = 0;

  var MemInfo: windows.MEMORY_BASIC_INFORMATION = undefined;

  const EXECUTE_FLAGS = 
    windows.PAGE_EXECUTE |
    windows.PAGE_EXECUTE_READ |
    windows.PAGE_EXECUTE_READWRITE |
    windows.PAGE_EXECUTE_WRITECOPY;

  if (windows.VirtualQuery(null, &MemInfo, @sizeOf(windows.MEMORY_BASIC_INFORMATION)) catch {
    print("Unexpected error at VirtualQuery initial\n", .{});
    return null;
  } != 0) {
    Address = @intFromPtr(MemInfo.BaseAddress) + MemInfo.RegionSize;
  } else {
    return null;
  }

  while (windows.VirtualQuery(@ptrFromInt(Address), &MemInfo, @sizeOf(windows.MEMORY_BASIC_INFORMATION)) catch {
    print("Unexpected error at VirtualQuery loop\n", .{});
    return null;
  } != 0) {
    if ((MemInfo.Protect & EXECUTE_FLAGS) != 0 and MemInfo.State == windows.MEM_COMMIT) {
      const Memory: [*]u8 = @ptrFromInt(Address);
      LocalMemoryPosition = 0;

      while (LocalMemoryPosition < MemInfo.RegionSize) {
        const Byte = Memory[LocalMemoryPosition];

        if (Byte == 0x00) {
          LocalMemoryPosition += 1;
        } else if (Byte == Pattern[0]) {
          LocalPatternPosition = 1;
          Equal = 1;
          var Fail: u8 = 0;
          var Pos = LocalMemoryPosition + 1;

          while (LocalPatternPosition < Pattern.len and Fail < 4 and Pos < MemInfo.RegionSize) {
            if (Memory[Pos] == Pattern[LocalPatternPosition]) {
              Equal += 1;
            } else {
              Fail += 1;
            }
            Pos += 1;
            LocalPatternPosition += 1;
          }

          if (Equal == Pattern.len) {
            return Memory[LocalMemoryPosition..];
          }
          LocalMemoryPosition += 1;
        } else {
          LocalMemoryPosition += 1;
        }
      }
    }

    Address = @intFromPtr(MemInfo.BaseAddress) + MemInfo.RegionSize;
  }

  return null;
}

fn InsertJumpToHook() void {
  @memcpy(FunctionSlice, &ShellCode);
}

fn RevertInsert() void {
  @memcpy(FunctionSlice, &OriginalBytes);
}

pub export fn DllMain(_: windows.HINSTANCE, Reason: windows.DWORD, _: windows.LPVOID) windows.BOOL {
  switch (Reason) {
    1 => {
      _ = MessageBoxA(null, "In Program!", "Hecker:D",0);
      const Countainer = findFunctionMemory();
      if (Countainer == null) {
        print("Didn't find the function!\n", .{});
        return 2;
      } else {
        Function = @ptrCast(Countainer.?);
      }
      FunctionSlice = @ptrCast(Function);
      const ShellSlice: *u64 = @alignCast(@ptrCast(ShellCode[2..10]));
      ShellSlice.* = @intFromPtr(&MyHook);
      @memcpy(&OriginalBytes, FunctionSlice);
      print("Wrote Original bytes? {}\n", .{OriginalBytes[0] != 0});
      
      windows.VirtualProtect(FunctionSlice, 12, windows.PAGE_EXECUTE_READWRITE, &OldProtect) catch |err| switch(err) {
        error.InvalidAddress => {
          print("Invalid address", .{});
          return 4;
        },
        error.Unexpected => {
          print("Other", .{});
          return 5;
        }
      };

      InsertJumpToHook();
      return 0;
    },
    0 => {
      return 0;
    },
    else => {return 0;}
  }
}