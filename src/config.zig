const kernel32 = @import("kernel32.zig");
const win32 = @import("win32.zig");

const HANDLE = win32.HANDLE;
const HMODULE = win32.HMODULE;
const DWORD = win32.DWORD;
const BOOL = win32.BOOL;
const INVALID_HANDLE_VALUE = win32.INVALID_HANDLE_VALUE;
const GENERIC_READ = win32.GENERIC_READ;
const FILE_SHARE_READ = win32.FILE_SHARE_READ;
const OPEN_EXISTING = win32.OPEN_EXISTING;
const FILE_ATTRIBUTE_NORMAL = win32.FILE_ATTRIBUTE_NORMAL;

// Configuration settings
pub const Config = struct {
    debug: bool = false,
};

// Global config instance
var g_config: Config = .{};
var g_loaded: bool = false;

// Store DLL module handle for getting correct path
var g_dll_handle: HMODULE = null;

// Set the DLL handle (called from DllMain)
pub fn setDllHandle(handle: HMODULE) void {
    g_dll_handle = handle;
}

// Get the loaded config
pub fn getConfig() Config {
    if (!g_loaded) {
        load();
    }
    return g_config;
}

// Check if debug mode is enabled
pub fn isDebugEnabled() bool {
    return getConfig().debug;
}

// Load config from config.ini next to the DLL
pub fn load() void {
    if (g_loaded) return;
    g_loaded = true;

    const getModuleFileName = kernel32.pGetModuleFileNameA orelse return;
    const createFile = kernel32.pCreateFileA orelse return;
    const readFile = kernel32.pReadFile orelse return;
    const closeHandle = kernel32.pCloseHandle orelse return;

    // Get DLL path (use DLL handle, not null which would give exe path)
    var path_buffer: [260]u8 = undefined;
    const len = getModuleFileName(g_dll_handle, &path_buffer, 260);
    if (len == 0) return;

    // Find the last backslash to replace filename with config.ini
    var last_slash: usize = 0;
    for (path_buffer[0..len], 0..) |c, i| {
        if (c == '\\' or c == '/') {
            last_slash = i;
        }
    }

    // Build config.ini path
    const config_name = "config.ini";
    if (last_slash + 1 + config_name.len >= path_buffer.len) return;

    for (config_name, 0..) |c, i| {
        path_buffer[last_slash + 1 + i] = c;
    }
    path_buffer[last_slash + 1 + config_name.len] = 0; // Null terminate

    // Open config file
    const handle = createFile(
        @ptrCast(&path_buffer),
        GENERIC_READ,
        FILE_SHARE_READ,
        null,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        null,
    );

    if (handle == INVALID_HANDLE_VALUE) {
        // Config file doesn't exist, use defaults
        return;
    }

    defer _ = closeHandle(handle);

    // Read file content
    var file_buffer: [512]u8 = undefined;
    var bytes_read: DWORD = 0;

    if (readFile(handle, &file_buffer, 512, &bytes_read, null) == 0) {
        return;
    }

    // Parse the config
    parseConfig(file_buffer[0..bytes_read]);
}

// Simple INI parser - looks for debug=true or debug=false
fn parseConfig(content: []const u8) void {
    var i: usize = 0;

    while (i < content.len) {
        // Skip whitespace and newlines
        while (i < content.len and (content[i] == ' ' or content[i] == '\t' or content[i] == '\r' or content[i] == '\n')) {
            i += 1;
        }

        if (i >= content.len) break;

        // Skip comment lines
        if (content[i] == ';' or content[i] == '#') {
            while (i < content.len and content[i] != '\n') {
                i += 1;
            }
            continue;
        }

        // Skip section headers [section]
        if (content[i] == '[') {
            while (i < content.len and content[i] != '\n') {
                i += 1;
            }
            continue;
        }

        // Look for "debug"
        if (i + 5 <= content.len and eqlIgnoreCase(content[i .. i + 5], "debug")) {
            i += 5;

            // Skip whitespace
            while (i < content.len and (content[i] == ' ' or content[i] == '\t')) {
                i += 1;
            }

            // Expect '='
            if (i < content.len and content[i] == '=') {
                i += 1;

                // Skip whitespace
                while (i < content.len and (content[i] == ' ' or content[i] == '\t')) {
                    i += 1;
                }

                // Check for "true" or "1"
                if (i + 4 <= content.len and eqlIgnoreCase(content[i .. i + 4], "true")) {
                    g_config.debug = true;
                } else if (i < content.len and content[i] == '1') {
                    g_config.debug = true;
                } else {
                    g_config.debug = false;
                }
            }

            // Skip to end of line
            while (i < content.len and content[i] != '\n') {
                i += 1;
            }
            continue;
        }

        // Skip unknown line
        while (i < content.len and content[i] != '\n') {
            i += 1;
        }
    }
}

// Case-insensitive string comparison
fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        const la: u8 = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
        const lb: u8 = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
        if (la != lb) return false;
    }
    return true;
}
