const std = @import("std");
const print = std.debug.print;

extern "kernel32" fn VirtualAllocEx(
  Process: std.os.windows.HANDLE,
  Address: ?*anyopaque,
  Size: usize,
  AllocationType: u32,
  Protect: u32
) ?std.os.windows.LPVOID;

extern "kernel32" fn CreateRemoteThreadEx(
  Process: std.os.windows.HANDLE,
  SecurityAttributes: ?*opaque{},
  StackSize: usize,
  StartAddress: std.os.windows.LPTHREAD_START_ROUTINE,
  Parameter: ?*anyopaque,
  CreationFlags: u32,
  AttributesList: ?*opaque{},
  ThreadId: ?*u32
) ?std.os.windows.HANDLE;

extern "kernel32" fn ResumeThread(
  Handle: std.os.windows.HANDLE
) u32;

const Dll = "C:\\Programming\\Code Injection\\Binaries\\Payload.dll";

const InjectError = error{
  MemoryAllocation,
  KernelModule,
  NoLoadLibraryA,
  ThreadError,
  ResumeError
};
pub fn main() !void {
  const TargetPath =  try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, "C:\\Programming\\Code Injection\\Binaries\\TestApp.exe");
  const CMDL = try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, "C:\\Programming\\Code Injection\\Binaries\\TestApp.exe heh");

  const CreateFlags: std.os.windows.CreateProcessFlags = .{
    .create_suspended = true
  };
  const CurrentDirectory: [:0]u16 = try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, "C:\\Programming\\Code Injection\\Binaries");
  var StartupInfo: std.os.windows.STARTUPINFOW = std.mem.zeroes(std.os.windows.STARTUPINFOW);
  var ProcessInfo: std.os.windows.PROCESS_INFORMATION = std.mem.zeroes(std.os.windows.PROCESS_INFORMATION);

  try std.os.windows.CreateProcessW(
    TargetPath, 
    CMDL, 
    null, 
    null,
    1, 
    CreateFlags, 
    null, 
    CurrentDirectory, 
    &StartupInfo, 
    &ProcessInfo
  );

  const Pointer: ?*anyopaque = VirtualAllocEx(ProcessInfo.hProcess, null, Dll.len, std.os.windows.MEM_COMMIT | std.os.windows.MEM_RESERVE, std.os.windows.PAGE_EXECUTE_READWRITE);
  if (Pointer == null) {
    print("Couldn't allocate memory inside a process, error is: {}!\n", .{std.os.windows.GetLastError()});
    return error.MemoryAllocation;
  }
  _ = try std.os.windows.WriteProcessMemory(ProcessInfo.hProcess, Pointer, Dll);
  const KernelModule = std.os.windows.kernel32.GetModuleHandleW(try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, "kernel32.dll"));
  if (KernelModule == null) {
    print("Can't load kernel32 module, error is: {}!\n", .{std.os.windows.GetLastError()});
    return error.KernelModule;
  }

  const LoadLibraryAddress = std.os.windows.kernel32.GetProcAddress(@ptrCast(KernelModule.?), "LoadLibraryA");
  if (LoadLibraryAddress == null) {
    print("Can't get address of LoadLibraryA, error is: {}!\n", .{std.os.windows.GetLastError()});
    return error.NoLoadLibraryA;
  }

  const Thread = CreateRemoteThreadEx(ProcessInfo.hProcess, null, 0, @ptrCast(LoadLibraryAddress.?), @ptrCast(Pointer.?), 0, null, null);
  if (Thread == null) {
    print("Can't create thread, error is: {}!\n", .{std.os.windows.GetLastError()});
    return error.ThreadError;
  }

  if (ResumeThread(Thread.?) == -1) {
    print("Can't resume thread, error is: {}!\n", .{std.os.windows.GetLastError()});
    return error.ResumeError;
  }
  try std.os.windows.WaitForSingleObject(Thread.?, std.os.windows.INFINITE);
  if (ResumeThread(ProcessInfo.hThread) == -1) {
    print("Can't resume process thread, error is: {}!\n", .{std.os.windows.GetLastError()});
    return error.ResumeError;
  }
}