const win32 = @import("win32.zig");
const kernel32 = @import("kernel32.zig");

const HANDLE = win32.HANDLE;
const DWORD = win32.DWORD;
const HWND = win32.HWND;
const STD_OUTPUT_HANDLE = win32.STD_OUTPUT_HANDLE;

var g_console_handle: HANDLE = null;
var g_initialized: bool = false;
var g_game_window: HWND = null;

// Initialize console window
pub fn init() bool {
    // Initialize user32 for window management
    kernel32.initUser32();
    
    // Save the current active window (the game)
    if (kernel32.pGetActiveWindow) |getActive| {
        g_game_window = getActive();
    }
    
    const allocConsole = kernel32.pAllocConsole orelse return false;
    const getStdHandle = kernel32.pGetStdHandle orelse return false;
    const setTitle = kernel32.pSetConsoleTitleA orelse return false;

    if (allocConsole() == 0) return false;

    g_console_handle = getStdHandle(STD_OUTPUT_HANDLE);
    if (g_console_handle == null) return false;

    _ = setTitle("ETS2 DualSenseX Integration - Haptic Feedback");
    g_initialized = true;
    
    // Restore focus to the game window
    if (g_game_window != null) {
        if (kernel32.pSetForegroundWindow) |setFg| {
            _ = setFg(g_game_window);
        }
    }

    // Print banner
    print("\n");
    print("  ╔══════════════════════════════════════════════════════╗\n");
    print("  ║     ETS2 DualSenseX Haptic Feedback Integration      ║\n");
    print("  ║                    Version 1.0                       ║\n");
    print("  ╚══════════════════════════════════════════════════════╝\n");
    print("\n");

    return true;
}

// Cleanup console
pub fn deinit() void {
    if (g_initialized) {
        if (kernel32.pFreeConsole) |freeConsole| {
            _ = freeConsole();
        }
        g_initialized = false;
        g_console_handle = null;
    }
}

// Print a string to console
pub fn print(msg: []const u8) void {
    if (!g_initialized) return;
    const writeConsole = kernel32.pWriteConsoleA orelse return;

    var written: DWORD = 0;
    _ = writeConsole(g_console_handle, msg.ptr, @intCast(msg.len), &written, null);
}

// Log levels
pub const LogLevel = enum {
    INFO,
    SUCCESS,
    WARNING,
    ERROR,
    DEBUG,
};

// Log with level prefix
pub fn log(level: LogLevel, msg: []const u8) void {
    const prefix = switch (level) {
        .INFO => "[INFO]    ",
        .SUCCESS => "[OK]      ",
        .WARNING => "[WARN]    ",
        .ERROR => "[ERROR]   ",
        .DEBUG => "[DEBUG]   ",
    };
    print(prefix);
    print(msg);
    print("\n");
}

// Log info message
pub fn info(msg: []const u8) void {
    log(.INFO, msg);
}

// Log success message
pub fn success(msg: []const u8) void {
    log(.SUCCESS, msg);
}

// Log warning message
pub fn warn(msg: []const u8) void {
    log(.WARNING, msg);
}

// Log error message
pub fn err(msg: []const u8) void {
    log(.ERROR, msg);
}

// Log debug message
pub fn debug(msg: []const u8) void {
    log(.DEBUG, msg);
}

// Format and print truck state
pub fn logTruckState(rpm: f32, throttle: f32, brake: f32, speed: f32) void {
    if (!g_initialized) return;

    var buf: [128]u8 = undefined;
    const len = formatTruckState(&buf, rpm, throttle, brake, speed);
    print(buf[0..len]);
}

fn formatTruckState(buf: []u8, rpm: f32, throttle: f32, brake: f32, speed: f32) usize {
    var pos: usize = 0;

    // "[TRUCK]   RPM: "
    const prefix = "[TRUCK]   RPM: ";
    for (prefix) |c| {
        buf[pos] = c;
        pos += 1;
    }

    // RPM value
    pos += formatInt(buf[pos..], @as(i32, @intFromFloat(rpm)));

    // " | Throttle: "
    const throttle_label = " | Throttle: ";
    for (throttle_label) |c| {
        buf[pos] = c;
        pos += 1;
    }

    // Throttle percentage
    pos += formatInt(buf[pos..], @as(i32, @intFromFloat(throttle * 100)));
    buf[pos] = '%';
    pos += 1;

    // " | Brake: "
    const brake_label = " | Brake: ";
    for (brake_label) |c| {
        buf[pos] = c;
        pos += 1;
    }

    // Brake percentage
    pos += formatInt(buf[pos..], @as(i32, @intFromFloat(brake * 100)));
    buf[pos] = '%';
    pos += 1;

    // " | Speed: "
    const speed_label = " | Speed: ";
    for (speed_label) |c| {
        buf[pos] = c;
        pos += 1;
    }

    // Speed value
    pos += formatInt(buf[pos..], @as(i32, @intFromFloat(speed)));

    // " km/h\r"
    const suffix = " km/h\r";
    for (suffix) |c| {
        buf[pos] = c;
        pos += 1;
    }

    return pos;
}

// Format trigger effect sent
pub fn logTriggerEffect(trigger: []const u8, mode: []const u8, strength: u8, freq: u8) void {
    if (!g_initialized) return;

    var buf: [100]u8 = undefined;
    var pos: usize = 0;

    const prefix = "[DSX]     ";
    for (prefix) |c| {
        buf[pos] = c;
        pos += 1;
    }

    for (trigger) |c| {
        buf[pos] = c;
        pos += 1;
    }

    const arrow = " -> ";
    for (arrow) |c| {
        buf[pos] = c;
        pos += 1;
    }

    for (mode) |c| {
        buf[pos] = c;
        pos += 1;
    }

    const str_label = " (str: ";
    for (str_label) |c| {
        buf[pos] = c;
        pos += 1;
    }

    pos += formatInt(buf[pos..], strength);

    const freq_label = ", freq: ";
    for (freq_label) |c| {
        buf[pos] = c;
        pos += 1;
    }

    pos += formatInt(buf[pos..], freq);

    const suffix = ")\n";
    for (suffix) |c| {
        buf[pos] = c;
        pos += 1;
    }

    print(buf[0..pos]);
}

// Simple integer to string formatting
fn formatInt(buf: []u8, val: i32) usize {
    if (val < 0) {
        buf[0] = '-';
        return 1 + formatUint(buf[1..], @intCast(-val));
    }
    return formatUint(buf, @intCast(val));
}

fn formatUint(buf: []u8, val: u32) usize {
    if (val == 0) {
        buf[0] = '0';
        return 1;
    }

    var tmp: [10]u8 = undefined;
    var i: usize = 0;
    var v = val;

    while (v > 0) : (i += 1) {
        tmp[i] = @intCast((v % 10) + '0');
        v /= 10;
    }

    // Reverse into output buffer
    var pos: usize = 0;
    while (i > 0) {
        i -= 1;
        buf[pos] = tmp[i];
        pos += 1;
    }

    return pos;
}
