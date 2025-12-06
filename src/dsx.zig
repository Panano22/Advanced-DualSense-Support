const win32 = @import("win32.zig");
const kernel32 = @import("kernel32.zig");

const SOCKET = win32.SOCKET;
const INVALID_SOCKET = win32.INVALID_SOCKET;
const AF_INET = win32.AF_INET;
const SOCK_DGRAM = win32.SOCK_DGRAM;
const IPPROTO_UDP = win32.IPPROTO_UDP;
const sockaddr_in = win32.sockaddr_in;
const WSADATA = win32.WSADATA;
const DWORD = win32.DWORD;
const HANDLE = win32.HANDLE;
const INVALID_HANDLE_VALUE = win32.INVALID_HANDLE_VALUE;
const GENERIC_READ = win32.GENERIC_READ;
const OPEN_EXISTING = win32.OPEN_EXISTING;
const FILE_SHARE_READ = win32.FILE_SHARE_READ;

// DSX Trigger enum
pub const Trigger = enum(u8) {
    Invalid = 0,
    Left = 1,
    Right = 2,
};

// DSX TriggerMode enum - matches DualSenseX protocol
pub const TriggerMode = enum(u8) {
    Normal = 0,
    GameCube = 1,
    VerySoft = 2,
    Soft = 3,
    Hard = 4,
    VeryHard = 5,
    Hardest = 6,
    Rigid = 7,
    VibrateTrigger = 8,
    Choppy = 9,
    Medium = 10,
    VibrateTriggerPulse = 11,
    CustomTriggerValue = 12,
    Resistance = 13,
    Bow = 14,
    Galloping = 15,
    SemiAutomaticGun = 16,
    AutomaticGun = 17,
    Machine = 18,
};

// DSX InstructionType enum
pub const InstructionType = enum(u8) {
    Invalid = 0,
    TriggerUpdate = 1,
    RGBUpdate = 2,
    PlayerLED = 3,
    TriggerThreshold = 4,
};

// DSX Connection state
pub const DsxConnection = struct {
    socket: SOCKET,
    endpoint: sockaddr_in,
    initialized: bool,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .socket = INVALID_SOCKET,
            .endpoint = undefined,
            .initialized = false,
        };
    }

    pub fn connect(self: *Self) bool {
        // Initialize Winsock
        if (!kernel32.initWinsock()) return false;

        const wsaStartup = kernel32.pWSAStartup orelse return false;
        const socketFn = kernel32.pSocket orelse return false;
        const htons = kernel32.pHtons orelse return false;

        var wsaData: WSADATA = undefined;
        if (wsaStartup(0x0202, &wsaData) != 0) return false;

        // Read port from DualSenseX port file
        const port = readDsxPort() orelse return false;

        // Create UDP socket
        self.socket = socketFn(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (self.socket == INVALID_SOCKET) return false;

        // Setup endpoint (127.0.0.1:port)
        self.endpoint = sockaddr_in{
            .sin_family = AF_INET,
            .sin_port = htons(port),
            .sin_addr = 0x0100007F, // 127.0.0.1 in little-endian
            .sin_zero = [_]u8{0} ** 8,
        };

        self.initialized = true;
        return true;
    }

    pub fn close(self: *Self) void {
        if (self.socket != INVALID_SOCKET) {
            if (kernel32.pCloseSocket) |closeSock| {
                _ = closeSock(self.socket);
            }
            self.socket = INVALID_SOCKET;
        }
        if (kernel32.pWSACleanup) |cleanup| {
            _ = cleanup();
        }
        kernel32.cleanupWinsock();
        self.initialized = false;
    }

    pub fn sendPacket(self: *Self, json: []const u8) bool {
        if (!self.initialized) return false;
        const sendTo = kernel32.pSendTo orelse return false;

        const result = sendTo(
            self.socket,
            json.ptr,
            @intCast(json.len),
            0,
            &self.endpoint,
            @sizeOf(sockaddr_in),
        );

        return result != win32.SOCKET_ERROR;
    }
};

// Read DualSenseX port number from config file
fn readDsxPort() ?u16 {
    const createFile = kernel32.pCreateFileA orelse return null;
    const readFile = kernel32.pReadFile orelse return null;
    const closeHandle = kernel32.pCloseHandle orelse return null;

    const path = "C:\\Temp\\DualSenseX\\DualSenseX_PortNumber.txt";
    
    const handle = createFile(
        path,
        GENERIC_READ,
        FILE_SHARE_READ,
        null,
        OPEN_EXISTING,
        0,
        null,
    );

    if (handle == INVALID_HANDLE_VALUE) return null;
    defer _ = closeHandle(handle);

    var buffer: [16]u8 = undefined;
    var bytesRead: DWORD = 0;

    if (readFile(handle, &buffer, 16, &bytesRead, null) == 0) return null;
    if (bytesRead == 0) return null;

    // Parse port number from text
    var port: u16 = 0;
    for (buffer[0..bytesRead]) |c| {
        if (c >= '0' and c <= '9') {
            port = port * 10 + @as(u16, c - '0');
        } else if (c == '\r' or c == '\n' or c == 0) {
            break;
        }
    }

    return if (port > 0) port else null;
}

// JSON packet builder for DSX protocol
pub const PacketBuilder = struct {
    buffer: [1024]u8,
    len: usize,

    const Self = @This();

    pub fn init() Self {
        var self = Self{
            .buffer = undefined,
            .len = 0,
        };
        self.appendStr("{\"instructions\":[");
        return self;
    }

    fn appendStr(self: *Self, str: []const u8) void {
        for (str) |c| {
            if (self.len < self.buffer.len) {
                self.buffer[self.len] = c;
                self.len += 1;
            }
        }
    }

    fn appendInt(self: *Self, val: i32) void {
        if (val < 0) {
            self.appendStr("-");
            self.appendUint(@intCast(-val));
        } else {
            self.appendUint(@intCast(val));
        }
    }

    fn appendUint(self: *Self, val: u32) void {
        if (val == 0) {
            if (self.len < self.buffer.len) {
                self.buffer[self.len] = '0';
                self.len += 1;
            }
            return;
        }

        var tmp: [10]u8 = undefined;
        var i: usize = 0;
        var v = val;
        while (v > 0) : (i += 1) {
            tmp[i] = @intCast((v % 10) + '0');
            v /= 10;
        }

        // Reverse
        while (i > 0) {
            i -= 1;
            if (self.len < self.buffer.len) {
                self.buffer[self.len] = tmp[i];
                self.len += 1;
            }
        }
    }

    pub fn addTriggerUpdate(
        self: *Self,
        controller_index: u8,
        trigger: Trigger,
        mode: TriggerMode,
        params: []const i32,
    ) void {
        if (self.len > 18) { // After initial "{"instructions":["
            self.appendStr(",");
        }

        self.appendStr("{\"type\":");
        self.appendUint(@intFromEnum(InstructionType.TriggerUpdate));
        self.appendStr(",\"parameters\":[");
        self.appendUint(controller_index);
        self.appendStr(",");
        self.appendUint(@intFromEnum(trigger));
        self.appendStr(",");
        self.appendUint(@intFromEnum(mode));

        for (params) |p| {
            self.appendStr(",");
            self.appendInt(p);
        }

        self.appendStr("]}");
    }

    pub fn addMachineTrigger(
        self: *Self,
        controller_index: u8,
        trigger: Trigger,
        start: u8,
        end: u8,
        strength_a: u8,
        strength_b: u8,
        frequency: u8,
        period: u8,
    ) void {
        const params = [_]i32{
            @intCast(start),
            @intCast(end),
            @intCast(strength_a),
            @intCast(strength_b),
            @intCast(frequency),
            @intCast(period),
        };
        self.addTriggerUpdate(controller_index, trigger, .Machine, &params);
    }

    pub fn addResistanceTrigger(
        self: *Self,
        controller_index: u8,
        trigger: Trigger,
        start: u8,
        force: u8,
    ) void {
        const params = [_]i32{
            @intCast(start),
            @intCast(force),
        };
        self.addTriggerUpdate(controller_index, trigger, .Resistance, &params);
    }

    pub fn addVibrateTrigger(
        self: *Self,
        controller_index: u8,
        trigger: Trigger,
        position: u8,
        amplitude: u8,
        frequency: u8,
    ) void {
        const params = [_]i32{
            @intCast(position),
            @intCast(amplitude),
            @intCast(frequency),
        };
        self.addTriggerUpdate(controller_index, trigger, .VibrateTrigger, &params);
    }

    pub fn build(self: *Self) []const u8 {
        self.appendStr("]}");
        return self.buffer[0..self.len];
    }
};
