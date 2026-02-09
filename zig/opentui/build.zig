const std = @import("std");
const builtin = @import("builtin");

const SupportedZigVersion = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

const SUPPORTED_ZIG_VERSIONS = [_]SupportedZigVersion{
    .{ .major = 0, .minor = 15, .patch = 2 },
};

const SupportedTarget = struct {
    zig_target: []const u8,
    output_name: []const u8,
    description: []const u8,
};

const SUPPORTED_TARGETS = [_]SupportedTarget{
    .{ .zig_target = "x86_64-linux", .output_name = "x86_64-linux", .description = "Linux x86_64" },
    .{ .zig_target = "aarch64-linux", .output_name = "aarch64-linux", .description = "Linux aarch64" },
    .{ .zig_target = "x86_64-macos", .output_name = "x86_64-macos", .description = "macOS x86_64 (Intel)" },
    .{ .zig_target = "aarch64-macos", .output_name = "aarch64-macos", .description = "macOS aarch64 (Apple Silicon)" },
    .{ .zig_target = "x86_64-windows-gnu", .output_name = "x86_64-windows", .description = "Windows x86_64" },
    .{ .zig_target = "aarch64-windows-gnu", .output_name = "aarch64-windows", .description = "Windows aarch64" },
};

const LIB_NAME = "opentui-textarea";
const ROOT_SOURCE_FILE = "test.zig"; // standalone build: no lib.zig entry point

/// Apply dependencies to a module
fn applyDependencies(b: *std.Build, module: *std.Build.Module, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget) void {
    // Add uucode for grapheme break detection and width calculation
    if (b.lazyDependency("uucode", .{
        .target = target,
        .optimize = optimize,
        .fields = @as([]const []const u8, &.{
            "grapheme_break",
            "east_asian_width",
            "general_category",
            "is_emoji_presentation",
        }),
    })) |uucode_dep| {
        module.addImport("uucode", uucode_dep.module("uucode"));
    }
}

fn checkZigVersion() void {
    const current_version = builtin.zig_version;
    var is_supported = false;

    for (SUPPORTED_ZIG_VERSIONS) |supported| {
        if (current_version.major == supported.major and
            current_version.minor == supported.minor and
            current_version.patch == supported.patch)
        {
            is_supported = true;
            break;
        }
    }

    if (!is_supported) {
        std.debug.print("\x1b[31mError: Unsupported Zig version {}.{}.{}\x1b[0m\n", .{
            current_version.major,
            current_version.minor,
            current_version.patch,
        });
        std.debug.print("Supported Zig versions:\n", .{});
        for (SUPPORTED_ZIG_VERSIONS) |supported| {
            std.debug.print("  - {}.{}.{}\n", .{
                supported.major,
                supported.minor,
                supported.patch,
            });
        }
        std.debug.print("\nPlease install a supported Zig version to continue.\n", .{});
        std.process.exit(1);
    }
}

pub fn build(b: *std.Build) void {
    checkZigVersion();

    const optimize = b.standardOptimizeOption(.{});
    const resolved_target = b.standardTargetOptions(.{});
    const build_all = b.option(bool, "all", "Build for all supported targets") orelse false;

    // Expose a single module for consumers (e.g. zigler NIF bindings)
    // All vendored files go through nif-api.zig to avoid Zig 0.15's
    // "file exists in two modules" constraint.
    {
        const nif_api_mod = b.addModule("opentui", .{
            .root_source_file = b.path("nif-api.zig"),
        });
        applyDependencies(b, nif_api_mod, optimize, resolved_target);
    }

    if (build_all) {
        // Build all supported targets
        buildAllTargets(b, optimize);
    } else {
        // Build for the resolved target (native by default, or from -Dtarget)
        const arch_name = @tagName(resolved_target.result.cpu.arch);
        const os_name = @tagName(resolved_target.result.os.tag);

        // Find matching supported target for output naming
        var found = false;
        for (SUPPORTED_TARGETS) |supported_target| {
            if (std.mem.indexOf(u8, supported_target.zig_target, arch_name) != null and
                std.mem.indexOf(u8, supported_target.zig_target, os_name) != null)
            {
                buildTargetResolved(b, resolved_target, supported_target.output_name, supported_target.description, optimize) catch |err| {
                    std.debug.print("Failed to build target {s}: {}\n", .{ supported_target.description, err });
                };
                found = true;
                break;
            }
        }

        if (!found) {
            // Build for native/custom target with generic naming
            buildTargetResolved(b, resolved_target, "native", "native target", optimize) catch |err| {
                std.debug.print("Failed to build native target: {}\n", .{err});
            };
        }
    }

    // Test step (native only)
    const test_step = b.step("test", "Run unit tests");
    const native_target = b.resolveTargetQuery(.{});
    const test_mod = b.createModule(.{
        .root_source_file = b.path("test.zig"),
        .target = native_target,
        .optimize = .Debug,
    });
    applyDependencies(b, test_mod, .Debug, native_target);
    const run_test = b.addRunArtifact(b.addTest(.{
        .root_module = test_mod,
        .filters = if (b.option([]const u8, "test-filter", "Skip tests that do not match filter")) |f| &.{f} else &.{},
    }));
    test_step.dependOn(&run_test.step);
}

fn buildAllTargets(b: *std.Build, optimize: std.builtin.OptimizeMode) void {
    for (SUPPORTED_TARGETS) |supported_target| {
        buildTarget(b, supported_target.zig_target, supported_target.output_name, supported_target.description, optimize) catch |err| {
            std.debug.print("Failed to build target {s}: {}\n", .{ supported_target.description, err });
            continue;
        };
    }
}

fn buildTargetResolved(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    output_name: []const u8,
    description: []const u8,
    optimize: std.builtin.OptimizeMode,
) !void {
    const module = b.createModule(.{
        .root_source_file = b.path(ROOT_SOURCE_FILE),
        .target = target,
        .optimize = optimize,
    });

    applyDependencies(b, module, optimize, target);

    const lib = b.addLibrary(.{
        .name = LIB_NAME,
        .root_module = module,
        .linkage = .dynamic,
    });

    const install_dir = b.addInstallArtifact(lib, .{
        .dest_dir = .{
            .override = .{
                .custom = try std.fmt.allocPrint(b.allocator, "../lib/{s}", .{output_name}),
            },
        },
    });

    const build_step_name = try std.fmt.allocPrint(b.allocator, "build-{s}", .{output_name});
    const build_step = b.step(build_step_name, try std.fmt.allocPrint(b.allocator, "Build for {s}", .{description}));
    build_step.dependOn(&install_dir.step);

    b.getInstallStep().dependOn(&install_dir.step);
}

fn buildTarget(
    b: *std.Build,
    zig_target: []const u8,
    output_name: []const u8,
    description: []const u8,
    optimize: std.builtin.OptimizeMode,
) !void {
    const target_query = try std.Target.Query.parse(.{ .arch_os_abi = zig_target });
    const target = b.resolveTargetQuery(target_query);
    try buildTargetResolved(b, target, output_name, description, optimize);
}
