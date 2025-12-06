const win32 = @import("win32.zig");
const kernel32 = @import("kernel32.zig");
const ets2 = @import("ets2.zig");
const scs_sdk = @import("scs_sdk.zig");
const config = @import("config.zig");

const BOOL = win32.BOOL;
const DWORD = win32.DWORD;
const TRUE = win32.TRUE;
const DLL_PROCESS_ATTACH = win32.DLL_PROCESS_ATTACH;
const DLL_PROCESS_DETACH = win32.DLL_PROCESS_DETACH;

// ============================================================================
// SCS Telemetry SDK Exports
// These are called by ETS2/ATS when the DLL is loaded as a telemetry plugin
// Place this DLL in: <game>/bin/win_x64/plugins/
// ============================================================================

pub export fn scs_telemetry_init(version: u32, params: *const anyopaque) callconv(.c) c_int {
    // Initialize kernel32 if not already done
    kernel32.init();

    // Initialize SCS SDK
    const result = scs_sdk.scs_telemetry_init(version, params);

    // If initialization succeeded, start the DSX thread
    if (result == scs_sdk.SCS_RESULT_ok) {
        ets2.start();
    }

    return result;
}

pub export fn scs_telemetry_shutdown() callconv(.c) c_int {
    // Stop DSX behavior
    ets2.stop();

    // Shutdown SCS SDK
    return scs_sdk.scs_telemetry_shutdown();
}

// ============================================================================
// DLL Entry Point
// ============================================================================

pub export fn DllMain(hinstDLL: ?*anyopaque, fdwReason: DWORD, lpvReserved: ?*anyopaque) BOOL {
    _ = lpvReserved;

    switch (fdwReason) {
        DLL_PROCESS_ATTACH => {
            // Store DLL handle for config file path resolution
            config.setDllHandle(hinstDLL);
            // Initialize kernel32 function pointers dynamically
            kernel32.init();
            // Load real hidapi.dll for proxy functionality
            // Only execute payload if running in the target process
            if (kernel32.isTargetProcess()) {
                // Note: When loaded as SCS telemetry plugin, scs_telemetry_init
                // will be called by the game and will start the DSX thread.
                // When loaded as hidapi.dll proxy, we start DSX here as fallback.
                // The scs_sdk module will provide simulated data if SDK callbacks
                // aren't active.

                // Check if we need to start DSX (not started by scs_telemetry_init)
                if (!scs_sdk.isAvailable()) {
                    // Start DualSenseX haptic feedback with simulated data
                    ets2.start();
                }

            }
        },
        DLL_PROCESS_DETACH => {
            // Stop DSX behavior
            ets2.stop();
        },
        else => {},
    }

    return TRUE;
}
