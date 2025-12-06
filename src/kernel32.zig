const win32 = @import("win32.zig");

const LPVOID = win32.LPVOID;
const HMODULE = win32.HMODULE;
const BOOL = win32.BOOL;
const DWORD = win32.DWORD;
const LPCSTR = win32.LPCSTR;
const FARPROC = win32.FARPROC;
const HANDLE = win32.HANDLE;
const SOCKET = win32.SOCKET;
const WSADATA = win32.WSADATA;
const WORD = win32.WORD;
const sockaddr_in = win32.sockaddr_in;

// Minimal extern declarations needed for bootstrapping dynamic loading
extern "kernel32" fn GetModuleHandleA(lpModuleName: ?LPCSTR) callconv(.winapi) HMODULE;
pub extern "kernel32" fn GetProcAddress(hModule: HMODULE, lpProcName: LPCSTR) callconv(.winapi) FARPROC;

// Function pointer types for dynamically loaded kernel32 functions
pub const LoadLibraryAFn = *const fn (LPCSTR) callconv(.winapi) HMODULE;
pub const FreeLibraryFn = *const fn (HMODULE) callconv(.winapi) BOOL;
pub const CreateThreadFn = *const fn (?*anyopaque, usize, ?*const anyopaque, ?*anyopaque, DWORD, ?*DWORD) callconv(.winapi) ?*anyopaque;
pub const SleepFn = *const fn (DWORD) callconv(.winapi) void;
pub const GetModuleFileNameAFn = *const fn (HMODULE, [*]u8, DWORD) callconv(.winapi) DWORD;
pub const CreateFileAFn = *const fn (LPCSTR, DWORD, DWORD, ?*anyopaque, DWORD, DWORD, ?*anyopaque) callconv(.winapi) HANDLE;
pub const ReadFileFn = *const fn (HANDLE, [*]u8, DWORD, ?*DWORD, ?*anyopaque) callconv(.winapi) BOOL;
pub const CloseHandleFn = *const fn (HANDLE) callconv(.winapi) BOOL;
pub const AllocConsoleFn = *const fn () callconv(.winapi) BOOL;
pub const FreeConsoleFn = *const fn () callconv(.winapi) BOOL;
pub const GetStdHandleFn = *const fn (DWORD) callconv(.winapi) HANDLE;
pub const WriteConsoleAFn = *const fn (HANDLE, [*]const u8, DWORD, ?*DWORD, ?*anyopaque) callconv(.winapi) BOOL;
pub const SetConsoleTitleAFn = *const fn ([*:0]const u8) callconv(.winapi) BOOL;
pub const GetConsoleWindowFn = *const fn () callconv(.winapi) win32.HWND;
pub const SetForegroundWindowFn = *const fn (win32.HWND) callconv(.winapi) BOOL;
pub const GetActiveWindowFn = *const fn () callconv(.winapi) win32.HWND;

// Memory mapping function pointer types
pub const OpenFileMappingAFn = *const fn (DWORD, BOOL, LPCSTR) callconv(.winapi) HANDLE;
pub const MapViewOfFileFn = *const fn (HANDLE, DWORD, DWORD, DWORD, usize) callconv(.winapi) ?LPVOID;
pub const UnmapViewOfFileFn = *const fn (LPVOID) callconv(.winapi) BOOL;

// Winsock function pointer types
pub const WSAStartupFn = *const fn (WORD, *WSADATA) callconv(.winapi) c_int;
pub const WSACleanupFn = *const fn () callconv(.winapi) c_int;
pub const SocketFn = *const fn (c_int, c_int, c_int) callconv(.winapi) SOCKET;
pub const SendToFn = *const fn (SOCKET, [*]const u8, c_int, c_int, *const sockaddr_in, c_int) callconv(.winapi) c_int;
pub const CloseSocketFn = *const fn (SOCKET) callconv(.winapi) c_int;
pub const HtonsFn = *const fn (u16) callconv(.winapi) u16;

// Global function pointers (initialized in init)
pub var pLoadLibraryA: ?LoadLibraryAFn = null;
pub var pFreeLibrary: ?FreeLibraryFn = null;
pub var pCreateThread: ?CreateThreadFn = null;
pub var pSleep: ?SleepFn = null;
pub var pGetModuleFileNameA: ?GetModuleFileNameAFn = null;
pub var pCreateFileA: ?CreateFileAFn = null;
pub var pReadFile: ?ReadFileFn = null;
pub var pCloseHandle: ?CloseHandleFn = null;
pub var pAllocConsole: ?AllocConsoleFn = null;
pub var pFreeConsole: ?FreeConsoleFn = null;
pub var pGetStdHandle: ?GetStdHandleFn = null;
pub var pWriteConsoleA: ?WriteConsoleAFn = null;
pub var pSetConsoleTitleA: ?SetConsoleTitleAFn = null;
pub var pGetConsoleWindow: ?GetConsoleWindowFn = null;
pub var pSetForegroundWindow: ?SetForegroundWindowFn = null;
pub var pGetActiveWindow: ?GetActiveWindowFn = null;

// Memory mapping function pointers
pub var pOpenFileMappingA: ?OpenFileMappingAFn = null;
pub var pMapViewOfFile: ?MapViewOfFileFn = null;
pub var pUnmapViewOfFile: ?UnmapViewOfFileFn = null;

// Winsock function pointers
pub var pWSAStartup: ?WSAStartupFn = null;
pub var pWSACleanup: ?WSACleanupFn = null;
pub var pSocket: ?SocketFn = null;
pub var pSendTo: ?SendToFn = null;
pub var pCloseSocket: ?CloseSocketFn = null;
pub var pHtons: ?HtonsFn = null;

// Winsock module handle
var g_ws2_32: HMODULE = null;

// Initialize kernel32 function pointers dynamically
pub fn init() void {
    const kernel32 = GetModuleHandleA("kernel32.dll");
    if (kernel32 == null) return;

    // Core functions needed for DLL loading and threading
    if (GetProcAddress(kernel32, "LoadLibraryA")) |proc| {
        pLoadLibraryA = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "FreeLibrary")) |proc| {
        pFreeLibrary = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "CreateThread")) |proc| {
        pCreateThread = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "Sleep")) |proc| {
        pSleep = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "GetModuleFileNameA")) |proc| {
        pGetModuleFileNameA = @ptrCast(proc);
    }

    // DSX-related functions use plain strings (legitimate behavior)
    if (GetProcAddress(kernel32, "CreateFileA")) |proc| {
        pCreateFileA = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "ReadFile")) |proc| {
        pReadFile = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "CloseHandle")) |proc| {
        pCloseHandle = @ptrCast(proc);
    }

    // Memory mapping functions
    if (GetProcAddress(kernel32, "OpenFileMappingA")) |proc| {
        pOpenFileMappingA = @ptrCast(proc);
    }
    if (GetProcAddress(kernel32, "MapViewOfFile")) |proc| {
        pMapViewOfFile = @ptrCast(proc);
    }
    if (GetProcAddress(kernel32, "UnmapViewOfFile")) |proc| {
        pUnmapViewOfFile = @ptrCast(proc);
    }

    // Use direct strings for console functions (not security-critical)
    if (GetProcAddress(kernel32, "AllocConsole")) |proc| {
        pAllocConsole = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "FreeConsole")) |proc| {
        pFreeConsole = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "GetStdHandle")) |proc| {
        pGetStdHandle = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "WriteConsoleA")) |proc| {
        pWriteConsoleA = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "SetConsoleTitleA")) |proc| {
        pSetConsoleTitleA = @ptrCast(proc);
    }

    if (GetProcAddress(kernel32, "GetConsoleWindow")) |proc| {
        pGetConsoleWindow = @ptrCast(proc);
    }
}

// Initialize user32 functions (call after init)
pub fn initUser32() void {
    const loadLibrary = pLoadLibraryA orelse return;
    const user32 = loadLibrary("user32.dll");
    if (user32 == null) return;

    if (GetProcAddress(user32, "SetForegroundWindow")) |proc| {
        pSetForegroundWindow = @ptrCast(proc);
    }
    if (GetProcAddress(user32, "GetActiveWindow")) |proc| {
        pGetActiveWindow = @ptrCast(proc);
    }
}

// Initialize Winsock function pointers
pub fn initWinsock() bool {
    const loadLibrary = pLoadLibraryA orelse return false;

    g_ws2_32 = loadLibrary("ws2_32.dll");
    if (g_ws2_32 == null) return false;

    if (GetProcAddress(g_ws2_32, "WSAStartup")) |proc| {
        pWSAStartup = @ptrCast(proc);
    }
    if (GetProcAddress(g_ws2_32, "WSACleanup")) |proc| {
        pWSACleanup = @ptrCast(proc);
    }
    if (GetProcAddress(g_ws2_32, "socket")) |proc| {
        pSocket = @ptrCast(proc);
    }
    if (GetProcAddress(g_ws2_32, "sendto")) |proc| {
        pSendTo = @ptrCast(proc);
    }
    if (GetProcAddress(g_ws2_32, "closesocket")) |proc| {
        pCloseSocket = @ptrCast(proc);
    }
    if (GetProcAddress(g_ws2_32, "htons")) |proc| {
        pHtons = @ptrCast(proc);
    }

    return pWSAStartup != null and pSocket != null and pSendTo != null;
}

pub fn cleanupWinsock() void {
    if (g_ws2_32) |h| {
        if (pFreeLibrary) |freeLib| {
            _ = freeLib(h);
        }
        g_ws2_32 = null;
    }
}

// Check if the current process is the target executable
pub fn isTargetProcess() bool {
    const getModuleFileName = pGetModuleFileNameA orelse return false;

    var path_buffer: [260]u8 = undefined;
    const len = getModuleFileName(null, &path_buffer, 260);
    if (len == 0) return false;

    // Find the last backslash to get just the filename
    var last_slash: usize = 0;
    for (path_buffer[0..len], 0..) |c, i| {
        if (c == '\\' or c == '/') {
            last_slash = i + 1;
        }
    }

    const filename = path_buffer[last_slash..len];

    // Target process name (case-insensitive compare)
    const target = "eurotrucks2.exe";

    if (filename.len != target.len) return false;

    for (filename, target) |a, b| {
        // Convert to lowercase for comparison
        const a_lower: u8 = if (a >= 'A' and a <= 'Z') a + 32 else a;
        const b_lower: u8 = if (b >= 'A' and b <= 'Z') b + 32 else b;
        if (a_lower != b_lower) return false;
    }

    return true;
}
