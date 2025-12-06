const std = @import("std");
const win32 = @import("win32.zig");
const kernel32 = @import("kernel32.zig");
const dsx = @import("dsx.zig");
const console = @import("console.zig");
const scs_sdk = @import("scs_sdk.zig");
const config = @import("config.zig");

const DWORD = win32.DWORD;

// Global connection state
var g_connection: dsx.DsxConnection = dsx.DsxConnection.init();
var g_running: bool = false;

// Unified telemetry data structure
const TelemetryData = struct {
    rpm: f32,
    throttle: f32,
    brake: f32,
    speed_kmh: f32,
    gear: i32,
    engine_on: bool,
    is_live: bool,
    is_paused: bool,
};

// Get current telemetry values from SDK (returns null if not available)
fn getTelemetry() ?TelemetryData {
    // Check if SCS SDK telemetry channels are registered
    if (!scs_sdk.hasChannels()) {
        return null;
    }
    
    const telem = scs_sdk.getTelemetry();
    const is_paused = scs_sdk.isPaused();
    const stats = scs_sdk.getCallbackStats();
    
    // Check if we're actually receiving callback data
    const has_data = stats.total > 0;
    
    if (is_paused or !has_data) {
        // Game paused or no data yet
        return .{
            .rpm = @max(0.0, telem.rpm),
            .throttle = 0.0,
            .brake = 0.0,
            .speed_kmh = 0.0,
            .gear = 0,
            .engine_on = false,
            .is_live = false,
            .is_paused = true,
        };
    }
    
    return .{
        .rpm = @max(0.0, telem.rpm),
        .throttle = @max(0.0, @min(1.0, telem.throttle)),
        .brake = @max(0.0, @min(1.0, telem.brake)),
        .speed_kmh = @abs(telem.speed) * 3.6, // m/s to km/h
        .gear = telem.gear,
        .engine_on = telem.engine_enabled,
        .is_live = true,
        .is_paused = false,
    };
}

// Calculate trigger parameters based on telemetry
fn calculateAcceleratorTrigger(packet: *dsx.PacketBuilder, telem: TelemetryData) void {
    // Right trigger = Accelerator with engine vibration feel
    // Using Machine mode to simulate diesel engine rumble
    
    if (!telem.engine_on) {
        // Engine off - no feedback
        packet.addResistanceTrigger(0, .Right, 0, 0);
        return;
    }
    
    // RPM-based frequency (lower RPM = slower pulses, typical truck idles at 600-800, redline ~2100)
    const rpm_normalized = @max(0.0, @min(1.0, (telem.rpm - 500.0) / 1600.0));
    const frequency: u8 = @intFromFloat(15.0 + rpm_normalized * 40.0); // 15-55 Hz
    
    // Throttle affects strength - more throttle = more engine feedback
    const base_strength: f32 = if (telem.throttle > 0.05) 
        2.0 + telem.throttle * 6.0 // 2-8 when throttle applied
    else 
        1.0; // Light idle vibration
    
    // Engine vibration gets stronger at higher RPM
    const strength: u8 = @intFromFloat(@min(8.0, base_strength + rpm_normalized * 2.0));
    
    packet.addMachineTrigger(
        0,                    // controller index
        .Right,               // accelerator trigger
        1,                    // start position
        9,                    // end position  
        0,                    // strength_a (off portion)
        strength,             // strength_b (vibration strength)
        frequency,            // frequency
        1,                    // period
    );
}

fn calculateBrakeTrigger(packet: *dsx.PacketBuilder, telem: TelemetryData) void {
    // Left trigger = Brake with progressive resistance
    // Using Resistance mode to simulate brake pedal feel
    
    // Brake force increases resistance
    const brake_force: u8 = if (telem.brake > 0.05)
        @intFromFloat(2.0 + telem.brake * 6.0) // 2-8 based on brake pressure
    else
        0; // No resistance when not braking
    
    // Higher speed = more brake resistance (simulating brake effort needed)
    const speed_factor: f32 = @min(1.0, telem.speed_kmh / 100.0);
    const final_force: u8 = @intFromFloat(@as(f32, @floatFromInt(brake_force)) * (0.5 + speed_factor * 0.5));
    
    packet.addResistanceTrigger(
        0,           // controller index
        .Left,       // brake trigger
        0,           // start position
        final_force, // resistance force
    );
}

// Log counter for periodic detailed logs
var g_log_counter: u32 = 0;

// Main DSX update loop - sends trigger effects
fn dsxUpdateThread(_: ?*anyopaque) callconv(.winapi) DWORD {
    const sleep = kernel32.pSleep orelse return 1;
    
    // Load config and conditionally initialize console window
    config.load();
    const debug_enabled = config.isDebugEnabled();
    
    if (debug_enabled) {
        if (!console.init()) {
            // Console failed but continue anyway
        }
        
        console.info("ETS2 DualSenseX Telemetry Plugin");
        console.info("Standalone mode - no external plugins required!");
        console.print("\n");
    }
    
    // Initial delay to let everything load
    if (debug_enabled) {
        console.info("Waiting for game to initialize (3 seconds)...");
    }
    sleep(3000);
    
    // Try to connect to DualSenseX
    if (debug_enabled) {
        console.info("Connecting to DualSenseX...");
        console.info("Looking for port file: C:\\Temp\\DualSenseX\\DualSenseX_PortNumber.txt");
    }
    if (!g_connection.connect()) {
        if (debug_enabled) {
            console.err("Failed to connect to DualSenseX!");
            console.err("Possible causes:");
            console.err("  1. DualSenseX is not running");
            console.err("  2. Port file not found at C:\\Temp\\DualSenseX\\");
            console.err("  3. Winsock initialization failed");
            console.info("");
            console.info("Please start DualSenseX and restart the game.");
            console.info("Console will remain open for reference...");
        }
        
        while (g_running) {
            sleep(1000);
        }
        if (debug_enabled) {
            console.deinit();
        }
        return 0;
    }
    
    if (debug_enabled) {
        console.success("Connected to DualSenseX!");
        
        // Check SDK status
        if (scs_sdk.hasChannels()) {
            console.success("SCS Telemetry SDK active with channels!");
            console.info("Receiving LIVE telemetry directly from game.");
        } else if (scs_sdk.isAvailable()) {
            console.warn("SCS Telemetry SDK initialized but no channels yet.");
            console.info("Channels register when you load a truck (enter driving mode).");
            console.info("Waiting for truck to be loaded...");
        } else {
            console.warn("SCS Telemetry SDK not yet initialized.");
            console.info("Waiting for SDK to activate (enter driving mode).");
        }
        
        console.print("\n");
        console.info("Trigger Effects:");
        console.info("  Right Trigger (RT) = Accelerator with engine vibration");
        console.info("  Left Trigger (LT)  = Brake with progressive resistance");
        console.print("\n");
        console.print("-------------------------------------------------------------\n");
        console.print("\n");
    }
    
    g_running = true;
    var sdk_was_active = false;
    
    // Main loop - update at ~10Hz for smooth feel
    while (g_running) {
        // Check if SDK channels just became active (truck loaded)
        const sdk_active = scs_sdk.hasChannels();
        if (debug_enabled) {
            if (sdk_active and !sdk_was_active) {
                console.print("\n");
                console.success("SCS Telemetry SDK channels registered!");
                console.info("Truck loaded - now receiving LIVE telemetry from game.");
                console.print("\n");
            } else if (!sdk_active and sdk_was_active) {
                console.print("\n");
                console.warn("SCS Telemetry SDK channels lost.");
                console.info("Waiting for truck to be loaded...");
                console.print("\n");
            }
        }
        sdk_was_active = sdk_active;
        
        // Get telemetry from SDK
        const telem = getTelemetry() orelse {
            // No telemetry available - wait
            sleep(100);
            continue;
        };
        
        // Build DSX packet with trigger effects
        var packet = dsx.PacketBuilder.init();
        
        // Add accelerator trigger (right) - engine vibration
        calculateAcceleratorTrigger(&packet, telem);
        
        // Add brake trigger (left) - resistance
        calculateBrakeTrigger(&packet, telem);
        
        // Send packet to DualSenseX
        const json = packet.build();
        const send_ok = g_connection.sendPacket(json);
        
        // Log truck state
        if (debug_enabled) {
            console.logTruckState(telem.rpm, telem.throttle, telem.brake, telem.speed_kmh);
        }
        
        // Calculate effect values for logging
        const rpm_normalized = @max(0.0, @min(1.0, (telem.rpm - 500.0) / 1600.0));
        const frequency: u8 = @intFromFloat(15.0 + rpm_normalized * 40.0);
        const base_strength: f32 = if (telem.throttle > 0.05) 
            2.0 + telem.throttle * 6.0
        else 
            1.0;
        const accel_strength: u8 = @intFromFloat(@min(8.0, base_strength + rpm_normalized * 2.0));
        
        const brake_force: u8 = if (telem.brake > 0.05)
            @intFromFloat(2.0 + telem.brake * 6.0)
        else
            0;
        const speed_factor: f32 = @min(1.0, telem.speed_kmh / 100.0);
        const brake_strength: u8 = @intFromFloat(@as(f32, @floatFromInt(brake_force)) * (0.5 + speed_factor * 0.5));
        
        // Detailed effect logging every 50 ticks (5 seconds)
        g_log_counter +%= 1;
        if (debug_enabled and g_log_counter % 50 == 0) {
            console.print("\n");
            
            // Show SDK debug info
            const stats = scs_sdk.getCallbackStats();
            if (scs_sdk.hasChannels()) {
                console.info("[SDK] Callbacks: total=");
                // Note: Can't easily format numbers, just show status
                if (stats.total > 0) {
                    console.success("[SDK RECEIVING DATA]");
                } else {
                    console.warn("[SDK CHANNELS OK - NO DATA YET]");
                }
            } else if (scs_sdk.isAvailable()) {
                console.warn("[SDK INIT - WAITING FOR TRUCK]");
            }
            
            if (telem.is_live) {
                console.success("[LIVE TELEMETRY - SDK]");
            } else if (telem.is_paused) {
                console.warn("[GAME PAUSED OR NO DATA]");
            }
            
            if (send_ok) {
                console.logTriggerEffect("RT (Accel)", "Machine", accel_strength, frequency);
                console.logTriggerEffect("LT (Brake)", "Resistance", brake_strength, 0);
            } else {
                console.warn("Failed to send DSX packet");
            }
        }
        
        // Sleep 100ms (10 updates per second)
        sleep(100);
    }
    
    if (debug_enabled) {
        console.print("\n");
        console.info("Shutting down DSX integration...");
    }
    g_connection.close();
    if (debug_enabled) {
        console.success("Disconnected from DualSenseX");
        console.deinit();
    }
    return 0;
}

// Start the DSX behavior thread
pub fn start() void {
    const createThread = kernel32.pCreateThread orelse return;
    const thread_proc: ?*const anyopaque = @ptrCast(&dsxUpdateThread);
    _ = createThread(null, 0, thread_proc, null, 0, null);
}

// Stop the DSX behavior
pub fn stop() void {
    g_running = false;
}
