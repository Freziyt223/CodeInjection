const std = @import("std");
const windows = std.os.windows;

const PROC_THREAD_ATTRIBUTE_ENTRY = extern struct {
  Attribute: windows.DWORD_PTR,
  cbSize: usize,
  lpValue: windows.PVOID,
};

const PROC_THREAD_ATTRIBUTE_LIST = extern struct {
  dwFlags: windows.DWORD,
  Size: windows.ULONG,
  Count: windows.ULONG,
  Reserved: windows.ULONG,
  Unknown: ?*windows.ULONG,
  Entries: [0]PROC_THREAD_ATTRIBUTE_ENTRY,
};

extern "kernel32" fn GetModuleHandleA(
  Name: windows.LPCSTR
) callconv(.winapi) windows.HMODULE;

extern "kernel32" fn CreateRemoteThreadEx(
  hProcess: windows.HANDLE,
  SecurityAttributes: ?*windows.SECURITY_ATTRIBUTES,
  StackSize: windows.SIZE_T,
  StartAddress: windows.LPTHREAD_START_ROUTINE,
  Parameters: ?windows.LPVOID,
  CreationFlags: windows.DWORD,
  AttributeList: ?*PROC_THREAD_ATTRIBUTE_LIST,
  ThreadID: ?*windows.DWORD
) callconv(.winapi) windows.HANDLE;

extern "kernel32" fn VirtualAllocEx(
  Process: windows.HANDLE,
  Address: ?windows.LPVOID,
  Size: windows.DWORD,
  AllocationType: windows.DWORD,
  Protect: windows.DWORD
) callconv(.winapi) windows.LPVOID;

extern "kernel32" fn ResumeThread(
  hThread: windows.HANDLE
) callconv(.winapi) u32;

const WritingError = error{
  FailedToAllocate
};

fn RemoteThread() !void {

}

pub fn main() !void {
  const CMD: [:0]u16 = try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, "C:\\Programming\\Code Injection\\Binaries\\TestApp.exe hunter2");

  var SI: windows.STARTUPINFOW = std.mem.zeroes(windows.STARTUPINFOW);
  SI.cb = @sizeOf(windows.STARTUPINFOW);
  var PI: windows.PROCESS_INFORMATION = std.mem.zeroes(windows.PROCESS_INFORMATION);
  var Flags = windows.CreateProcessFlags{};
  Flags.create_suspended = true;

  try windows.CreateProcessW(
    null, 
    CMD, 
    null, 
    null, 
    0, 
    Flags, 
    null, 
    null, 
    &SI, 
    &PI
  );

  const ptr = VirtualAllocEx(PI.hProcess, null, 4096, windows.MEM_RESERVE | windows.MEM_COMMIT, windows.PAGE_EXECUTE_READWRITE);

  const dllpath = "C:\\Programming\\Code Injection\\Binaries\\Payload.dll\x00";
  
  _ = try windows.WriteProcessMemory(PI.hProcess, ptr, dllpath);

  const kernel32 = GetModuleHandleA("kernel32");
  const LoadLibraryA = windows.kernel32.GetProcAddress(kernel32, "LoadLibraryA");

  _ = CreateRemoteThreadEx(PI.hProcess, null, 0, @ptrCast(LoadLibraryA.?), ptr, 0, null, null);
  
  if (ResumeThread(PI.hThread) == -1) {
    const err = windows.kernel32.GetLastError();
    std.debug.print("ResumeThread failed with error: {}\n", .{err});
    return err;
  }
}