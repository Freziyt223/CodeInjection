const std = @import("std");
const windows = std.os.windows;
const print = std.debug.print;
var File: windows.HANDLE = windows.INVALID_HANDLE_VALUE;

pub export fn MyHook(_: [*:0]const u8) bool {
  return true;
}

var ShellCode: [12]u8 = .{
  0x48, 0xB8,             // mov rax, imm64
  0x00, 0x00, 0x00, 0x00, // нижні 4 байти адреси
  0x00, 0x00, 0x00, 0x00, // верхні 4 байти адреси
  0xFF, 0xE0              // jmp rax
};
var oldProtect: u32 = 0;
var OriginalBytes: [12]u8 = undefined;
const FunctionSize: usize = 64;
const Pattern: [11]u8 = .{
  0x55, 0x48, 0x83, 0xec, 0x30, 0x48, 0x8d, 0x6c, 0x24, 0x30, 0xe8
};
var Function: *fn([*:0]const u8) bool = undefined;

var FoundMemory: ?[]u8 = undefined;

fn injectCode() void {
  @memcpy(FoundMemory.?[0..12], &ShellCode);
}

fn revertCode() void {
  @memcpy(FoundMemory.?[0..12], &OriginalBytes);
}

fn findFunctionMemory() ?[]u8 {
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
            return Memory[LocalMemoryPosition..LocalMemoryPosition + 80];
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

pub export fn DllMain(_: std.os.windows.HINSTANCE, Reason: u32, _: *anyopaque) c_int {
  switch (Reason) {
    // Attached to process
    1 => {
      FoundMemory = findFunctionMemory();
      if (FoundMemory == null) {
        print("Found null memory!\n", .{});
        return 2;
      }

      Function = @ptrCast(FoundMemory.?);
      if (Function("hunter2") == true) {print("It's hunter2\n", .{});}

      @memcpy(&OriginalBytes, FoundMemory.?[0..12]);
      const ShellSlice: *usize = @alignCast(@ptrCast(ShellCode[2..10]));
      ShellSlice.* = @intFromPtr(&MyHook);
      print("MyHook: {*}\n", .{&MyHook});
      print("My Hook in shellcode: 0x{X}\n", .{ShellSlice.*});
      
      windows.VirtualProtect(@ptrCast(FoundMemory.?), FunctionSize, windows.PAGE_EXECUTE_READWRITE, &oldProtect) catch |err| {
        switch (err) {
          error.InvalidAddress => {print("InvalidAddress error when applying new protection!\n", .{}); return 3;},
          error.Unexpected => {print("Unexpected error when applying new protection!\n", .{}); return 4;}
        }
      };
      injectCode();
      
      print("Ready!\n", .{});
      return 1; // True in windows C
    },
    // Detached from process
    0 => {
      print("Detaching!\n", .{});
      revertCode();
      windows.VirtualProtect(@ptrCast(FoundMemory.?), FunctionSize, oldProtect, &oldProtect) catch |err| {
      switch (err) {
        error.InvalidAddress => {print("InvalidAddress error when applying old protection!\n", .{}); return 3;},
        error.Unexpected => {print("Unexpected error when applying old protection!\n", .{}); return 4;}
      }
    };
      return 1;
    },
    // Attached to thread
    2 => {
      return 1;
    },
    // Detached from thread
    3 => {
      return 1;
    },
    else => {
      return 0;
    }
  }
}