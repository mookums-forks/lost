const std = @import("std");

const src = &.{
    "src/attitude-estimators.cpp",
    "src/attitude-utils.cpp",
    "src/camera.cpp",
    "src/centroiders.cpp",
    "src/databases.cpp",
    "src/io.cpp",
    "src/main.cpp",
    "src/star-id.cpp",
    "src/star-utils.cpp",
};

pub fn build(b: *std.Build) !void {
    const float_mode = b.option(bool, "float", "Enables Float Mode (default: false)") orelse false;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const generate_txt_step = b.step("generate_txt", "Generate .txt files from .man files.");
    const generate_h_step = b.step("generate_h", "Generate .h files from .man files.");

    const exe = b.addExecutable(.{
        .name = "lost",
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibCpp();

    exe.addIncludePath(b.path("src/"));
    exe.addIncludePath(b.path("vendor/"));
    exe.addIncludePath(b.path("documentation/"));

    exe.linkSystemLibrary("cairo");

    exe.addCSourceFiles(.{
        .files = src,
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-Wno-missing-field-initializers",
            "-pedantic",
            "--std=c++11",
            //"-fsanitize=address",
        },
    });

    // Enable Float Mode.
    if (float_mode) {
        exe.root_module.addCMacro("LOST_FLOAT_MODE", "1");
    }

    // We need the man-*.h files to build the executable.
    exe.step.dependOn(generate_h_step);

    b.installArtifact(exe);

    // Allows you to run lost by using 'zig build run'
    // ex. zig build run -- database
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run Lost");
    run_step.dependOn(&run_cmd.step);

    // Generating the man-*.h files.
    generate_h_step.dependOn(generate_txt_step);

    var dir = try std.fs.cwd().openDir("documentation/", .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".man")) {
            const man_file = entry.name;
            const artifact_name = std.mem.trimRight(u8, man_file, ".man");
            const txt_file = try std.fmt.allocPrint(b.allocator, "{s}.txt", .{artifact_name});
            const h_file = try std.fmt.allocPrint(b.allocator, "man-{s}.h", .{artifact_name});

            const txt_cmd = try std.fmt.allocPrint(
                b.allocator,
                "groff -mandoc -Tascii documentation/{s} > documentation/{s} && printf '\\0' >> documentation/{s}",
                .{ man_file, txt_file, txt_file },
            );

            const h_cmd = try std.fmt.allocPrint(
                b.allocator,
                "xxd -i documentation/{s} > documentation/{s}",
                .{ txt_file, h_file },
            );

            const txt_run = b.addSystemCommand(&[_][]const u8{ "sh", "-c", txt_cmd });
            const h_run = b.addSystemCommand(&[_][]const u8{ "sh", "-c", h_cmd });

            h_run.step.dependOn(&txt_run.step);
            generate_txt_step.dependOn(&txt_run.step);
            generate_h_step.dependOn(&h_run.step);
        }
    }
}
