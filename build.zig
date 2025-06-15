const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(Builder: *std.Build) void {
  // Standard target options allows the person running `zig build` to choose
  // what target to build for. Here we do not override the defaults, which
  // means any target is allowed, and the default is native. Other options
  // for restricting supported target set are available.
  const Target = Builder.standardTargetOptions(.{});
  const Option1 = Builder.option(bool, "Hack", "Build main.zig?");
  const Option2 = Builder.option(bool, "Payload", "Build payload?");
  const Option3 = Builder.option(bool, "Injector", "Build Injector?");


  // Standard optimization options allow the person running `zig build` to select
  // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
  // set a preferred release mode, allowing the user to decide how to optimize.
  const Optimize = Builder.standardOptimizeOption(.{});

  // This creates another `std.Build.Step.Compile`, but this one builds an executable
  // rather than a static library.
  
  

  const TestApp = Builder.addExecutable(.{
    .name = "TestApp",
    .target = Target,
    .root_source_file = .{.cwd_relative = "src/test_app.zig"}
  });
  TestApp.linkSystemLibrary("user32");

  const InstallConfig: std.Build.Step.InstallArtifact.Options =
  if (Optimize == .Debug)
    std.Build.Step.InstallArtifact.Options{
      .dest_dir = .{ .override = .{ .custom = "../Binaries/" } },
      .pdb_dir = .{ .override = .{ .custom = "../Binaries/PDB/" } },
  }
  else
    std.Build.Step.InstallArtifact.Options{
      .dest_dir = .{ .override = .{ .custom = "../Binaries/" } },
  };

  if (Option1 == true) {
    const Exe = Builder.addExecutable(.{
      .name = "Code_Injection",
      .target = Target,
      .root_source_file = .{.cwd_relative = "src/main.zig"},
    });
    Exe.linkSystemLibrary("kernel32");

    const Payload = Builder.addSharedLibrary(.{
        .root_source_file = .{.cwd_relative = "src/Payload.zig"},
        .target = Target,
        .optimize = Optimize,
        .name = "Payload"
    });

    const InstallPayload = Builder.addInstallArtifact(Payload, .{
      .dest_dir = .{.override = .{.custom = "../Binaries"}}
    });
    
    Builder.default_step.dependOn(&InstallPayload.step);
    const InstallExe = Builder.addInstallArtifact(Exe, InstallConfig);
    Builder.default_step.dependOn(&InstallExe.step);
  } else {
    if (Option2 == true) {
      const Payload = Builder.addSharedLibrary(.{
        .root_source_file = .{.cwd_relative = "src/Payload.zig"},
        .target = Target,
        .optimize = Optimize,
        .name = "Payload"
      });

      const InstallPayload = Builder.addInstallArtifact(Payload, .{
        .dest_dir = .{.override = .{.custom = "../Binaries"}}
      });

      Builder.default_step.dependOn(&InstallPayload.step);
    }
    if (Option3 == true) {
      const Exe = Builder.addExecutable(.{
      .name = "Code_Injection",
      .target = Target,
      .root_source_file = .{.cwd_relative = "src/main.zig"},
    });
    Exe.linkSystemLibrary("kernel32");

    const InstallExe = Builder.addInstallArtifact(Exe, InstallConfig);
      Builder.default_step.dependOn(&InstallExe.step);
    }
  }

  const InstallTestApp = Builder.addInstallArtifact(TestApp, InstallConfig);

  Builder.default_step.dependOn(&InstallTestApp.step);
}
