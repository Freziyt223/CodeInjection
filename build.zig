const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(Builder: *std.Build) void {
  const Target = Builder.standardTargetOptions(.{});
  const Optimize = Builder.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

  const TestApp = Builder.addExecutable(.{
    .name = "TestApp",
    .root_module = Builder.addModule("TestApp", .{
      .target = Target,
      .optimize = Optimize,
      .root_source_file = .{.cwd_relative = "src/TestApp.zig"},
      .strip = true
    })
  });
  TestApp.linkSystemLibrary("kernel32");
  TestApp.linkSystemLibrary("user32");

  const Injector = Builder.addExecutable(.{
    .name = "Injector",
    .root_module = Builder.addModule("Injector", .{
      .target = Target,
      .optimize = Optimize,
      .root_source_file = .{.cwd_relative = "src/Injector.zig"},
      .strip = true
    })
  });
  Injector.linkSystemLibrary("kernel32");

  const Payload = Builder.addLibrary(.{
    .linkage = .dynamic,
    .name = "Payload",
    .root_module = Builder.addModule("Payload", .{
      .target = Target,
      .optimize = Optimize,
      .root_source_file = .{.cwd_relative = "src/Payload.zig"},
      .strip = true
    }),
  });
  Payload.entry = .{
    .symbol_name = "DllMain"
  };
  Payload.linkSystemLibrary("kernel32");

  const Test2 = Builder.addExecutable(.{
    .name = "Test2",
    .root_module = Builder.createModule(.{
      .optimize = Optimize,
      .target = Target,
      .root_source_file = .{.cwd_relative = "src/Injector2.zig"},
      .strip = true,
    })
  });

  const TestAppArtifact = Builder.addInstallArtifact(TestApp, .{.dest_dir = .{.override = .{ .custom = "../Binaries/"}}});
  const PayloadArtifact = Builder.addInstallArtifact(Payload, .{.dest_dir = .{.override = .{ .custom = "../Binaries/"}}});
  const InjectorArtifact = Builder.addInstallArtifact(Injector, .{.dest_dir = .{.override = .{ .custom = "../Binaries/"}}});
  const Test2Artifact = Builder.addInstallArtifact(Test2, .{.dest_dir = .{.override = .{.custom = "../Binaries/"}}});

  const TestAppStep = Builder.step("TestApp", "Build TestApp");
  TestAppStep.dependOn(&TestAppArtifact.step);

  const PayloadStep = Builder.step("Payload", "Build Payload");
  PayloadStep.dependOn(&PayloadArtifact.step);

  const InjectorStep = Builder.step("Injector", "Build Injector");
  InjectorStep.dependOn(&InjectorArtifact.step);

  const Test2Step = Builder.step("Test2", "Build Test2");
  Test2Step.dependOn(&Test2Artifact.step);

  Builder.default_step.dependOn(&TestAppArtifact.step);
  Builder.default_step.dependOn(&PayloadArtifact.step);
  Builder.default_step.dependOn(&InjectorArtifact.step);
}