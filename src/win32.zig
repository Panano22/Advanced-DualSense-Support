// Windows types
pub const LPVOID = *anyopaque;
pub const HMODULE = ?*anyopaque;
pub const BOOL = i32;
pub const DWORD = u32;
pub const LPCSTR = [*:0]const u8;
pub const FARPROC = ?*const fn () callconv(.winapi) isize;
pub const HANDLE = ?*anyopaque;
pub const WORD = u16;
pub const UINT = u32;

// Windows constants
pub const DLL_PROCESS_ATTACH: DWORD = 1;
pub const DLL_PROCESS_DETACH: DWORD = 0;
pub const TRUE: BOOL = 1;
pub const FALSE: BOOL = 0;
pub const INVALID_HANDLE_VALUE: HANDLE = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));
pub const GENERIC_READ: DWORD = 0x80000000;
pub const GENERIC_WRITE: DWORD = 0x40000000;
pub const OPEN_EXISTING: DWORD = 3;
pub const FILE_SHARE_READ: DWORD = 0x00000001;
pub const FILE_ATTRIBUTE_NORMAL: DWORD = 0x00000080;

// File mapping constants
pub const FILE_MAP_READ: DWORD = 0x0004;

// Console constants
pub const STD_OUTPUT_HANDLE: DWORD = @bitCast(@as(i32, -11));
pub const STD_ERROR_HANDLE: DWORD = @bitCast(@as(i32, -12));

// Window types
pub const HWND = ?*anyopaque;

// HID types
pub const hid_device = anyopaque;
pub const hid_device_info = anyopaque;
pub const wchar_t = u16;

// Winsock types
pub const SOCKET = usize;
pub const INVALID_SOCKET: SOCKET = ~@as(SOCKET, 0);
pub const SOCKET_ERROR: c_int = -1;

// Address family
pub const AF_INET: c_int = 2;

// Socket type
pub const SOCK_DGRAM: c_int = 2;

// Protocol
pub const IPPROTO_UDP: c_int = 17;

// sockaddr_in structure
pub const sockaddr_in = extern struct {
    sin_family: i16,
    sin_port: u16,
    sin_addr: u32,
    sin_zero: [8]u8,
};

// WSADATA structure
pub const WSADATA = extern struct {
    wVersion: WORD,
    wHighVersion: WORD,
    iMaxSockets: u16,
    iMaxUdpDg: u16,
    lpVendorInfo: ?[*]u8,
    szDescription: [257]u8,
    szSystemStatus: [129]u8,
};
