const std = @import("std");

pub fn build(b: *std.Build) void {
    // Target x86_64 Windows with GNU ABI for universal Win10/11 compatibility
    // GNU ABI doesn't require MSVC runtime, making it more portable
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .gnu,
    });

    // ReleaseSafe: optimized but with safety checks for stability
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe;

    // HidAPI Proxy DLL
    const hidapi_dll = b.addLibrary(.{
        .name = "dsx_haptics",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(hidapi_dll);

    // Default step builds the DLL
    const install_dll = b.addInstallArtifact(hidapi_dll, .{});
    b.getInstallStep().dependOn(&install_dll.step);
}
