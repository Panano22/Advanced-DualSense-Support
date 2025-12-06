//! SCS Telemetry SDK Types and Callbacks
//! This module implements the SCS Telemetry SDK interface directly,
//! allowing the DLL to receive telemetry data from ETS2/ATS without external plugins.

const std = @import("std");

// ============================================================================
// SCS SDK Types
// ============================================================================

pub const scs_string_t = [*:0]const u8;
pub const scs_context_t = ?*anyopaque;
pub const scs_u32_t = u32;
pub const scs_s32_t = i32;
pub const scs_u64_t = u64;
pub const scs_float_t = f32;
pub const scs_double_t = f64;

// SCS special values
pub const SCS_U32_NIL: scs_u32_t = 0xFFFFFFFF;

// SCS Result codes
pub const SCSAPI_RESULT = c_int;
pub const SCS_RESULT_ok: SCSAPI_RESULT = 0;
pub const SCS_RESULT_unsupported: SCSAPI_RESULT = -1;
pub const SCS_RESULT_invalid_parameter: SCSAPI_RESULT = -2;
pub const SCS_RESULT_already_registered: SCSAPI_RESULT = -3;
pub const SCS_RESULT_not_found: SCSAPI_RESULT = -4;
pub const SCS_RESULT_unsupported_type: SCSAPI_RESULT = -5;
pub const SCS_RESULT_not_now: SCSAPI_RESULT = -6;
pub const SCS_RESULT_generic_error: SCSAPI_RESULT = -7;

// SCS Value types
pub const scs_value_type_t = u32;
pub const SCS_VALUE_TYPE_INVALID: scs_value_type_t = 0;
pub const SCS_VALUE_TYPE_bool: scs_value_type_t = 1;
pub const SCS_VALUE_TYPE_s32: scs_value_type_t = 2;
pub const SCS_VALUE_TYPE_u32: scs_value_type_t = 3;
pub const SCS_VALUE_TYPE_u64: scs_value_type_t = 4;
pub const SCS_VALUE_TYPE_float: scs_value_type_t = 5;
pub const SCS_VALUE_TYPE_double: scs_value_type_t = 6;
pub const SCS_VALUE_TYPE_fvector: scs_value_type_t = 7;
pub const SCS_VALUE_TYPE_dvector: scs_value_type_t = 8;
pub const SCS_VALUE_TYPE_euler: scs_value_type_t = 9;
pub const SCS_VALUE_TYPE_fplacement: scs_value_type_t = 10;
pub const SCS_VALUE_TYPE_dplacement: scs_value_type_t = 11;
pub const SCS_VALUE_TYPE_string: scs_value_type_t = 12;

// SDK version - we support 1.00
pub const SCS_TELEMETRY_VERSION_1_00: scs_u32_t = 0x00010000;
pub const SCS_TELEMETRY_VERSION_CURRENT: scs_u32_t = SCS_TELEMETRY_VERSION_1_00;

// Telemetry channel names
pub const SCS_TELEMETRY_TRUCK_CHANNEL_speed = "truck.speed";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_local_linear_velocity = "truck.local.linear.velocity";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_engine_rpm = "truck.engine.rpm";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_engine_gear = "truck.engine.gear";
// Input channels - what the player is pressing
pub const SCS_TELEMETRY_TRUCK_CHANNEL_input_throttle = "truck.input.throttle";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_input_brake = "truck.input.brake";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_input_clutch = "truck.input.clutch";
// Effective channels - what the game is actually applying
pub const SCS_TELEMETRY_TRUCK_CHANNEL_effective_throttle = "truck.effective.throttle";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_effective_brake = "truck.effective.brake";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_effective_clutch = "truck.effective.clutch";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_engine_enabled = "truck.engine.enabled";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_electric_enabled = "truck.electric.enabled";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_parking_brake = "truck.brake.parking";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_motor_brake = "truck.brake.motor";
pub const SCS_TELEMETRY_TRUCK_CHANNEL_cruise_control = "truck.cruise_control";

// Event types
pub const scs_event_t = u32;
pub const SCS_TELEMETRY_EVENT_invalid: scs_event_t = 0;
pub const SCS_TELEMETRY_EVENT_frame_start: scs_event_t = 1;
pub const SCS_TELEMETRY_EVENT_frame_end: scs_event_t = 2;
pub const SCS_TELEMETRY_EVENT_paused: scs_event_t = 3;
pub const SCS_TELEMETRY_EVENT_started: scs_event_t = 4;
pub const SCS_TELEMETRY_EVENT_configuration: scs_event_t = 5;
pub const SCS_TELEMETRY_EVENT_gameplay: scs_event_t = 6;

// ============================================================================
// SCS SDK Structures
// ============================================================================

// Value union
pub const scs_value_t = extern struct {
    type: scs_value_type_t,
    _padding: u32 = 0,
    value: extern union {
        value_bool: u8,
        value_s32: scs_s32_t,
        value_u32: scs_u32_t,
        value_u64: scs_u64_t,
        value_float: scs_float_t,
        value_double: scs_double_t,
        // Add more types as needed
        _raw: [32]u8,
    },
};

// Named value for configuration
pub const scs_named_value_t = extern struct {
    name: scs_string_t,
    index: scs_u32_t,
    value: scs_value_t,
};

// Telemetry configuration
pub const scs_telemetry_configuration_t = extern struct {
    id: scs_string_t,
    attributes: [*]const scs_named_value_t,
};

// ============================================================================
// Callback Function Types
// ============================================================================

pub const scs_telemetry_register_for_channel_t = *const fn (
    name: scs_string_t,
    index: scs_u32_t,
    value_type: scs_value_type_t,
    flags: scs_u32_t,
    callback: scs_telemetry_channel_callback_t,
    context: scs_context_t,
) callconv(.c) SCSAPI_RESULT;

pub const scs_telemetry_unregister_from_channel_t = *const fn (
    name: scs_string_t,
    index: scs_u32_t,
    value_type: scs_value_type_t,
) callconv(.c) SCSAPI_RESULT;

pub const scs_telemetry_register_for_event_t = *const fn (
    event: scs_event_t,
    callback: scs_telemetry_event_callback_t,
    context: scs_context_t,
) callconv(.c) SCSAPI_RESULT;

pub const scs_telemetry_unregister_from_event_t = *const fn (
    event: scs_event_t,
    callback: scs_telemetry_event_callback_t,
) callconv(.c) SCSAPI_RESULT;

pub const scs_telemetry_channel_callback_t = ?*const fn (
    name: scs_string_t,
    index: scs_u32_t,
    value: *const scs_value_t,
    context: scs_context_t,
) callconv(.c) void;

pub const scs_telemetry_event_callback_t = ?*const fn (
    event: scs_event_t,
    event_info: ?*const anyopaque,
    context: scs_context_t,
) callconv(.c) void;

pub const scs_log_t = *const fn (
    log_type: scs_log_type_t,
    message: scs_string_t,
) callconv(.c) void;

pub const scs_log_type_t = c_int;
pub const SCS_LOG_TYPE_message: scs_log_type_t = 0;
pub const SCS_LOG_TYPE_warning: scs_log_type_t = 1;
pub const SCS_LOG_TYPE_error: scs_log_type_t = 2;

// ============================================================================
// SDK Init Params Structure (version 1.00)
// ============================================================================

pub const scs_sdk_init_params_v100_t = extern struct {
    game_name: scs_string_t,
    game_id: scs_string_t,
    game_version: scs_u32_t,
    _unused: scs_u32_t = 0,
    log: ?scs_log_t,
};

pub const scs_telemetry_init_params_v100_t = extern struct {
    common: scs_sdk_init_params_v100_t,
    register_for_event: ?scs_telemetry_register_for_event_t,
    unregister_from_event: ?scs_telemetry_unregister_from_event_t,
    register_for_channel: ?scs_telemetry_register_for_channel_t,
    unregister_from_channel: ?scs_telemetry_unregister_from_channel_t,
};

// ============================================================================
// Global Telemetry State (updated by SDK callbacks)
// ============================================================================

pub const TelemetryState = struct {
    // Truck data
    speed: f32 = 0.0,           // m/s
    rpm: f32 = 0.0,             // RPM
    gear: i32 = 0,              // Gear (-1=R, 0=N, >0=forward)
    throttle: f32 = 0.0,        // 0.0-1.0
    brake: f32 = 0.0,           // 0.0-1.0
    clutch: f32 = 0.0,          // 0.0-1.0
    engine_enabled: bool = false,
    electric_enabled: bool = false,
    parking_brake: bool = false,
    motor_brake: bool = false,
    cruise_control: f32 = 0.0,  // Speed or 0 if off
    
    // State flags
    sdk_active: bool = false,
    paused: bool = true,
    
    // Last update timestamp
    last_update_tick: u32 = 0,
};

// Global telemetry state - updated by SDK callbacks
pub var g_telemetry: TelemetryState = .{};

// Store function pointers from init
var g_register_for_channel: ?scs_telemetry_register_for_channel_t = null;
var g_register_for_event: ?scs_telemetry_register_for_event_t = null;
var g_log: ?scs_log_t = null;
var g_sdk_initialized: bool = false;
var g_channels_registered: bool = false;

// Debug counters for callback tracking
var g_callback_count: u32 = 0;
var g_speed_callback_count: u32 = 0;
var g_rpm_callback_count: u32 = 0;
var g_throttle_callback_count: u32 = 0;
var g_brake_callback_count: u32 = 0;
var g_config_event_count: u32 = 0;

// Helper to log messages
fn logMessage(msg: scs_string_t) void {
    if (g_log) |log| {
        log(SCS_LOG_TYPE_message, msg);
    }
}

fn logWarning(msg: scs_string_t) void {
    if (g_log) |log| {
        log(SCS_LOG_TYPE_warning, msg);
    }
}

fn logError(msg: scs_string_t) void {
    if (g_log) |log| {
        log(SCS_LOG_TYPE_error, msg);
    }
}

// ============================================================================
// Channel Callbacks
// ============================================================================

fn channel_callback_speed(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    g_callback_count +%= 1;
    g_speed_callback_count +%= 1;
    if (value.type == SCS_VALUE_TYPE_float) {
        g_telemetry.speed = value.value.value_float;
        g_telemetry.last_update_tick +%= 1;
        // Log first few callbacks for debugging
        if (g_speed_callback_count <= 3) {
            logMessage("[DSX] Speed callback received data!");
        }
    }
}

fn channel_callback_rpm(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    g_callback_count +%= 1;
    g_rpm_callback_count +%= 1;
    if (value.type == SCS_VALUE_TYPE_float) {
        g_telemetry.rpm = value.value.value_float;
        // Log first few callbacks for debugging
        if (g_rpm_callback_count <= 3) {
            logMessage("[DSX] RPM callback received data!");
        }
    }
}

fn channel_callback_gear(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    if (value.type == SCS_VALUE_TYPE_s32) {
        g_telemetry.gear = value.value.value_s32;
    }
}

fn channel_callback_throttle(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    g_callback_count +%= 1;
    g_throttle_callback_count +%= 1;
    if (value.type == SCS_VALUE_TYPE_float) {
        g_telemetry.throttle = value.value.value_float;
        // Log first few callbacks for debugging
        if (g_throttle_callback_count <= 3) {
            logMessage("[DSX] Throttle callback received data!");
        }
    }
}

fn channel_callback_brake(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    g_callback_count +%= 1;
    g_brake_callback_count +%= 1;
    if (value.type == SCS_VALUE_TYPE_float) {
        g_telemetry.brake = value.value.value_float;
        // Log first few callbacks for debugging
        if (g_brake_callback_count <= 3) {
            logMessage("[DSX] Brake callback received data!");
        }
    }
}

fn channel_callback_clutch(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    if (value.type == SCS_VALUE_TYPE_float) {
        g_telemetry.clutch = value.value.value_float;
    }
}

fn channel_callback_engine_enabled(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    if (value.type == SCS_VALUE_TYPE_bool) {
        g_telemetry.engine_enabled = value.value.value_bool != 0;
    }
}

fn channel_callback_electric_enabled(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    if (value.type == SCS_VALUE_TYPE_bool) {
        g_telemetry.electric_enabled = value.value.value_bool != 0;
    }
}

fn channel_callback_parking_brake(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    if (value.type == SCS_VALUE_TYPE_bool) {
        g_telemetry.parking_brake = value.value.value_bool != 0;
    }
}

fn channel_callback_motor_brake(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    if (value.type == SCS_VALUE_TYPE_bool) {
        g_telemetry.motor_brake = value.value.value_bool != 0;
    }
}

fn channel_callback_cruise_control(_: scs_string_t, _: scs_u32_t, value: *const scs_value_t, _: scs_context_t) callconv(.c) void {
    if (value.type == SCS_VALUE_TYPE_float) {
        g_telemetry.cruise_control = value.value.value_float;
    }
}

// ============================================================================
// Event Callbacks
// ============================================================================

var g_pause_event_count: u32 = 0;
var g_start_event_count: u32 = 0;
var g_frame_event_count: u32 = 0;

fn event_callback_paused(_: scs_event_t, _: ?*const anyopaque, _: scs_context_t) callconv(.c) void {
    g_telemetry.paused = true;
    g_pause_event_count +%= 1;
    if (g_pause_event_count <= 5) {
        logMessage("[DSX] Game PAUSED event received");
    }
}

fn event_callback_started(_: scs_event_t, _: ?*const anyopaque, _: scs_context_t) callconv(.c) void {
    g_telemetry.paused = false;
    g_start_event_count +%= 1;
    if (g_start_event_count <= 5) {
        logMessage("[DSX] Game STARTED event received");
    }
}

fn event_callback_frame_end(_: scs_event_t, _: ?*const anyopaque, _: scs_context_t) callconv(.c) void {
    // Frame ended - telemetry data for this frame is complete
    g_telemetry.last_update_tick +%= 1;
    g_frame_event_count +%= 1;
    // Log every 1000 frames (~16 seconds at 60fps) to show we're alive
    if (g_frame_event_count % 1000 == 0) {
        logMessage("[DSX] Frame events processed (x1000)");
    }
}

// Configuration event - this is where we register channels!
// Channels only become available when a truck is loaded
fn event_callback_configuration(_: scs_event_t, event_info: ?*const anyopaque, _: scs_context_t) callconv(.c) void {
    g_config_event_count +%= 1;
    
    if (event_info == null) {
        logWarning("[DSX] Configuration event with null info");
        return;
    }
    
    const config: *const scs_telemetry_configuration_t = @ptrCast(@alignCast(event_info));
    const config_id = std.mem.span(config.id);
    
    // Log configuration event
    if (g_config_event_count <= 10) {
        logMessage("[DSX] Configuration event received");
    }
    
    // Check if this is a truck configuration
    if (std.mem.eql(u8, config_id, "truck")) {
        logMessage("[DSX] *** TRUCK CONFIGURATION RECEIVED ***");
        logMessage("[DSX] Registering telemetry channels NOW...");
        
        // Register channels now that truck is available
        registerTelemetryChannels();
    } else if (std.mem.eql(u8, config_id, "trailer")) {
        if (g_config_event_count <= 10) {
            logMessage("[DSX] Trailer configuration received");
        }
    } else if (std.mem.eql(u8, config_id, "job")) {
        if (g_config_event_count <= 10) {
            logMessage("[DSX] Job configuration received");
        }
    }
}

// Register all telemetry channels - called from configuration event
fn registerTelemetryChannels() void {
    const register_channel = g_register_for_channel orelse {
        logError("[DSX] Cannot register channels - no register function!");
        return;
    };
    
    var channels_ok: u32 = 0;
    var channels_failed: u32 = 0;
    
    for (CHANNELS_TO_REGISTER) |channel| {
        const result = register_channel(
            channel.name,
            SCS_U32_NIL,  // index - must be SCS_U32_NIL for non-array channels
            channel.value_type,
            0,  // flags (SCS_TELEMETRY_CHANNEL_FLAG_none)
            channel.callback,
            null,  // context
        );
        
        if (result == SCS_RESULT_ok) {
            channels_ok += 1;
        } else if (result == SCS_RESULT_already_registered) {
            // Already registered is fine
            channels_ok += 1;
        } else {
            channels_failed += 1;
            // Log failures for key channels
            const name = std.mem.span(channel.name);
            if (std.mem.eql(u8, name, "truck.speed") or
                std.mem.eql(u8, name, "truck.engine.rpm") or
                std.mem.eql(u8, name, "truck.input.throttle") or
                std.mem.eql(u8, name, "truck.input.brake")) {
                logWarning("[DSX] Key channel registration failed");
            }
        }
    }
    
    if (channels_ok > 0) {
        g_channels_registered = true;
        logMessage("[DSX] Channel registration successful!");
    }
    if (channels_failed > 0) {
        logWarning("[DSX] Some channels failed to register");
    }
}

// ============================================================================
// Channel Registration
// ============================================================================

const ChannelRegistration = struct {
    name: scs_string_t,
    value_type: scs_value_type_t,
    callback: scs_telemetry_channel_callback_t,
};

const CHANNELS_TO_REGISTER = [_]ChannelRegistration{
    // Core telemetry
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_speed, .value_type = SCS_VALUE_TYPE_float, .callback = channel_callback_speed },
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_engine_rpm, .value_type = SCS_VALUE_TYPE_float, .callback = channel_callback_rpm },
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_engine_gear, .value_type = SCS_VALUE_TYPE_s32, .callback = channel_callback_gear },
    // Input channels (player input) - try these first
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_input_throttle, .value_type = SCS_VALUE_TYPE_float, .callback = channel_callback_throttle },
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_input_brake, .value_type = SCS_VALUE_TYPE_float, .callback = channel_callback_brake },
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_input_clutch, .value_type = SCS_VALUE_TYPE_float, .callback = channel_callback_clutch },
    // Effective channels (game-applied values) - also register these as backup
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_effective_throttle, .value_type = SCS_VALUE_TYPE_float, .callback = channel_callback_throttle },
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_effective_brake, .value_type = SCS_VALUE_TYPE_float, .callback = channel_callback_brake },
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_effective_clutch, .value_type = SCS_VALUE_TYPE_float, .callback = channel_callback_clutch },
    // State channels
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_engine_enabled, .value_type = SCS_VALUE_TYPE_bool, .callback = channel_callback_engine_enabled },
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_electric_enabled, .value_type = SCS_VALUE_TYPE_bool, .callback = channel_callback_electric_enabled },
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_parking_brake, .value_type = SCS_VALUE_TYPE_bool, .callback = channel_callback_parking_brake },
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_motor_brake, .value_type = SCS_VALUE_TYPE_bool, .callback = channel_callback_motor_brake },
    .{ .name = SCS_TELEMETRY_TRUCK_CHANNEL_cruise_control, .value_type = SCS_VALUE_TYPE_float, .callback = channel_callback_cruise_control },
};

// ============================================================================
// SDK Exported Functions
// ============================================================================

/// Called by the game to initialize the telemetry plugin
pub fn scs_telemetry_init(version: scs_u32_t, params: *const anyopaque) callconv(.c) SCSAPI_RESULT {
    // Check version compatibility - be more flexible with version
    const version_major = (version >> 16) & 0xFFFF;
    if (version_major < 1) {
        return SCS_RESULT_unsupported;
    }
    
    // Cast params to v100 structure
    const init_params: *const scs_telemetry_init_params_v100_t = @ptrCast(@alignCast(params));
    
    // Store function pointers
    g_register_for_channel = init_params.register_for_channel;
    g_register_for_event = init_params.register_for_event;
    g_log = init_params.common.log;
    
    // Log initialization
    logMessage("[DSX] ========================================");
    logMessage("[DSX] ETS2 DSX Telemetry Plugin initializing...");
    logMessage("[DSX] ========================================");
    
    // Log what functions we got
    if (g_register_for_channel != null) {
        logMessage("[DSX] register_for_channel: OK");
    } else {
        logError("[DSX] register_for_channel: NULL!");
    }
    if (g_register_for_event != null) {
        logMessage("[DSX] register_for_event: OK");
    } else {
        logError("[DSX] register_for_event: NULL!");
    }
    
    // Register for events
    if (g_register_for_event) |register_event| {
        var result = register_event(SCS_TELEMETRY_EVENT_paused, event_callback_paused, null);
        if (result == SCS_RESULT_ok) {
            logMessage("[DSX] Event paused: registered OK");
        } else {
            logWarning("[DSX] Event paused: registration FAILED");
        }
        
        result = register_event(SCS_TELEMETRY_EVENT_started, event_callback_started, null);
        if (result == SCS_RESULT_ok) {
            logMessage("[DSX] Event started: registered OK");
        } else {
            logWarning("[DSX] Event started: registration FAILED");
        }
        
        result = register_event(SCS_TELEMETRY_EVENT_frame_end, event_callback_frame_end, null);
        if (result == SCS_RESULT_ok) {
            logMessage("[DSX] Event frame_end: registered OK");
        } else {
            logWarning("[DSX] Event frame_end: registration FAILED");
        }
        
        // IMPORTANT: Register for configuration event - this is when truck becomes available!
        result = register_event(SCS_TELEMETRY_EVENT_configuration, event_callback_configuration, null);
        if (result == SCS_RESULT_ok) {
            logMessage("[DSX] Event configuration: registered OK");
        } else {
            logWarning("[DSX] Event configuration: registration FAILED");
        }
    }
    
    // Try to register channels immediately - this works if truck is already loaded
    // If it fails (truck not loaded yet), we'll retry on configuration event
    logMessage("[DSX] ----------------------------------------");
    logMessage("[DSX] Attempting immediate channel registration...");
    registerTelemetryChannels();
    
    if (g_channels_registered) {
        logMessage("[DSX] Channels registered at init - truck already loaded!");
    } else {
        logMessage("[DSX] Channels will register on truck load");
    }
    logMessage("[DSX] ----------------------------------------");
    
    // Mark SDK as initialized and active
    g_sdk_initialized = true;
    g_telemetry.sdk_active = true;
    g_telemetry.paused = true;  // Start paused until game sends started event
    
    logMessage("[DSX] Plugin initialized successfully!");
    logMessage("[DSX] Waiting for game events...");
    
    return SCS_RESULT_ok;
}

/// Called by the game to shutdown the telemetry plugin
pub fn scs_telemetry_shutdown() callconv(.c) SCSAPI_RESULT {
    logMessage("[DSX] ========================================");
    logMessage("[DSX] Telemetry Plugin shutting down...");
    logMessage("[DSX] ========================================");
    
    g_sdk_initialized = false;
    g_channels_registered = false;
    g_telemetry.sdk_active = false;
    g_register_for_channel = null;
    g_register_for_event = null;
    g_log = null;
    
    return SCS_RESULT_ok;
}

// ============================================================================
// Public API for ets2.zig
// ============================================================================

/// Check if SDK telemetry is available (initialized, not necessarily with channels yet)
pub fn isAvailable() bool {
    return g_sdk_initialized and g_telemetry.sdk_active;
}

/// Check if SDK has registered channels and is receiving data
pub fn hasChannels() bool {
    return g_sdk_initialized and g_telemetry.sdk_active and g_channels_registered;
}

/// Get callback statistics for debugging
pub fn getCallbackStats() struct { total: u32, speed: u32, rpm: u32, throttle: u32, brake: u32, frames: u32 } {
    return .{
        .total = g_callback_count,
        .speed = g_speed_callback_count,
        .rpm = g_rpm_callback_count,
        .throttle = g_throttle_callback_count,
        .brake = g_brake_callback_count,
        .frames = g_frame_event_count,
    };
}

/// Check if game is paused
pub fn isPaused() bool {
    return g_telemetry.paused;
}

/// Get current telemetry state
pub fn getTelemetry() *const TelemetryState {
    return &g_telemetry;
}
