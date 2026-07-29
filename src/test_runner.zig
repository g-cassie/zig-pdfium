// https://gist.github.com/karlseguin/c6bea5b35e4e8d26af6f81c22cb5d76b
// in your build.zig, you can specify a custom test runner:
// const tests = b.addTest(.{
//   .target = target,
//   .optimize = optimize,
//   .test_runner = "test_runner.zig", // add this line
//   .root_source_file = b.path("src/main.zig"),
// });

const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;

const BORDER = "=" ** 80;

// use in custom panic handler
var current_test: ?[]const u8 = null;

/// `std.process.Init` gives us `io` (needed for the stderr writer and for
/// timing) and `environ_map`, both of which replace APIs removed in 0.16.
pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var mem: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&mem);

    const allocator = fba.allocator();

    // Values borrow from `environ_map`, so there is nothing to free.
    const env = Env.init(init.environ_map);

    var slowest = SlowTracker.init(allocator, io, 5);
    defer slowest.deinit(allocator);

    var pass: usize = 0;
    var fail: usize = 0;
    var skip: usize = 0;
    var leak: usize = 0;

    var failed_tests: std.ArrayListUnmanaged([]const u8) = .empty;
    defer failed_tests.deinit(allocator);

    var buf: [1024]u8 = undefined;
    var out = std.Io.File.stderr().writer(io, &buf);
    var w = &out.interface;
    try w.writeAll("\r\x1b[0K"); // beginning of line and clear to end of line
    defer w.flush() catch {};

    for (builtin.test_functions) |t| {
        if (isSetup(t)) {
            current_test = friendlyName(t.name);
            beginTestEnv(init);
            defer _ = endTestEnv();
            t.func() catch |err| {
                log(w, .fail, "\nsetup \"{s}\" failed: {}\n", .{ t.name, err });
                return err;
            };
        }
    }

    for (builtin.test_functions) |t| {
        if (isSetup(t) or isTeardown(t)) {
            continue;
        }

        var status = Status.pass;
        slowest.startTiming();

        const is_unnamed_test = isUnnamed(t);
        if (env.filter) |f| {
            if (!is_unnamed_test and std.mem.find(u8, t.name, f) == null) {
                continue;
            }
        }

        const friendly_name = friendlyName(t.name);
        current_test = friendly_name;
        beginTestEnv(init);
        const result = t.func();
        current_test = null;

        if (is_unnamed_test) {
            _ = endTestEnv();
            continue;
        }

        const ns_taken = slowest.endTiming(allocator, friendly_name);

        if (endTestEnv()) {
            leak += 1;
            log(w, .fail, "\n{s}\n\"{s}\" - Memory Leak\n{s}\n", .{ BORDER, friendly_name, BORDER });
        }

        if (result) |_| {
            pass += 1;
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip += 1;
                status = .skip;
            },
            else => {
                status = .fail;
                fail += 1;
                failed_tests.append(allocator, friendly_name) catch @panic("OOM");
                log(w, .fail, "\n{s}\n\"{s}\" - {s}\n{s}\n", .{ BORDER, friendly_name, @errorName(err), BORDER });
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpErrorReturnTrace(trace);
                }
                if (env.fail_first) {
                    break;
                }
            },
        }

        if (env.verbose) {
            const ms = @as(f64, @floatFromInt(ns_taken)) / 1_000_000.0;
            log(w, status, "{s} ({d:.2}ms)\n", .{ friendly_name, ms });
        } else {
            try w.print(".", .{});
        }
    }

    for (builtin.test_functions) |t| {
        if (isTeardown(t)) {
            current_test = friendlyName(t.name);
            beginTestEnv(init);
            defer _ = endTestEnv();
            t.func() catch |err| {
                log(w, .fail, "\n{s}\n\"{s}\" - {s}\n{s}\n", .{ BORDER, t.name, @errorName(err), BORDER });
                return err;
            };
        }
    }

    const total_tests = pass + fail;
    const status = if (fail == 0) Status.pass else Status.fail;
    log(w, status, "\r{d} of {d} test{s} passed\n", .{ pass, total_tests, if (total_tests != 1) "s" else "" });
    if (skip > 0) {
        log(w, .skip, "{d} test{s} skipped\n", .{ skip, if (skip != 1) "s" else "" });
    }
    if (leak > 0) {
        log(w, .fail, "{d} test{s} leaked\n", .{ leak, if (leak != 1) "s" else "" });
    }
    try w.print("\n", .{});
    try slowest.display(w);

    if (failed_tests.items.len > 0) {
        log(w, .fail, "\nFailed tests:\n", .{});
        for (failed_tests.items) |test_name| {
            log(w, .fail, "  {s}\n", .{test_name});
        }
    }

    try w.print("\n", .{});
    std.process.exit(if (fail == 0) 0 else 1);
}

/// 0.16 requires `std.testing.io_instance` to be initialized before any test
/// touches `std.testing.io`; leaving it `undefined` would read garbage rather
/// than fail loudly. Pairs with `endTestEnv`.
fn beginTestEnv(init: std.process.Init) void {
    std.testing.allocator_instance = .{};
    std.testing.io_instance = .init(std.testing.allocator, .{
        .argv0 = .init(init.minimal.args),
        .environ = init.minimal.environ,
    });
    std.testing.environ = init.minimal.environ;
}

/// Returns true if the test leaked memory. `io_instance` must be torn down
/// first because it allocates from `testing.allocator`.
fn endTestEnv() bool {
    std.testing.io_instance.deinit();
    return std.testing.allocator_instance.deinit() == .leak;
}

fn friendlyName(name: []const u8) []const u8 {
    var it = std.mem.splitScalar(u8, name, '.');
    while (it.next()) |value| {
        if (std.mem.eql(u8, value, "test")) {
            const rest = it.rest();
            return if (rest.len > 0) rest else name;
        }
    }
    return name;
}

const Status = enum {
    pass,
    fail,
    skip,
    text,
};
fn log(w: *std.Io.Writer, s: Status, comptime fmt: []const u8, args: anytype) void {
    const color = switch (s) {
        .pass => "\x1b[32m",
        .fail => "\x1b[31m",
        .skip => "\x1b[33m",
        .text => "",
    };
    w.writeAll(color) catch @panic("failed to write color");
    w.print(fmt, args) catch @panic("failed to print");
    w.writeAll("\x1b[0m") catch @panic("failed to write reset");
    w.flush() catch @panic("failed to flush");
}

const SlowTracker = struct {
    const SlowestQueue = std.PriorityDequeue(TestInfo, void, compareTiming);
    max: usize,
    slowest: SlowestQueue,
    io: std.Io,
    /// `std.time.Timer` was removed in 0.16; we take monotonic timestamps
    /// instead. `.awake` is `CLOCK_MONOTONIC` on Linux.
    started: std.Io.Timestamp,

    fn init(allocator: Allocator, io: std.Io, count: u32) SlowTracker {
        var slowest = SlowestQueue.initContext({});
        slowest.ensureTotalCapacity(allocator, count) catch @panic("OOM");
        return .{
            .max = count,
            .io = io,
            .started = .now(io, .awake),
            .slowest = slowest,
        };
    }

    const TestInfo = struct {
        ns: u64,
        name: []const u8,
    };

    fn deinit(self: *SlowTracker, allocator: Allocator) void {
        self.slowest.deinit(allocator);
    }

    fn startTiming(self: *SlowTracker) void {
        self.started = .now(self.io, .awake);
    }

    fn endTiming(self: *SlowTracker, allocator: Allocator, test_name: []const u8) u64 {
        const elapsed = self.started.untilNow(self.io, .awake);
        const ns: u64 = @intCast(@max(0, elapsed.nanoseconds));

        var slowest = &self.slowest;

        if (slowest.count() < self.max) {
            // Capacity is fixed to the # of slow tests we want to track
            // If we've tracked fewer tests than this capacity, than always add
            slowest.push(allocator, TestInfo{ .ns = ns, .name = test_name }) catch @panic("failed to track test timing");
            return ns;
        }

        {
            // Optimization to avoid shifting the dequeue for the common case
            // where the test isn't one of our slowest.
            const fastest_of_the_slow = slowest.peekMin() orelse unreachable;
            if (fastest_of_the_slow.ns > ns) {
                // the test was faster than our fastest slow test, don't add
                return ns;
            }
        }

        // the previous fastest of our slow tests, has been pushed off.
        _ = slowest.popMin();
        slowest.push(allocator, TestInfo{ .ns = ns, .name = test_name }) catch @panic("failed to track test timing");
        return ns;
    }

    fn display(self: *SlowTracker, w: *std.Io.Writer) !void {
        // Shallow copy so draining the queue here leaves the original intact
        // for `deinit` to free.
        var slowest = self.slowest;
        const count = slowest.count();
        try w.print("Slowest {d} test{s}: \n", .{ count, if (count != 1) "s" else "" });
        while (slowest.popMin()) |info| {
            const ms = @as(f64, @floatFromInt(info.ns)) / 1_000_000.0;
            try w.print("  {d:.2}ms\t{s}\n", .{ ms, info.name });
        }
    }

    fn compareTiming(context: void, a: TestInfo, b: TestInfo) std.math.Order {
        _ = context;
        return std.math.order(a.ns, b.ns);
    }
};

/// `std.process.getEnvVarOwned` was removed in 0.16. `Environ.Map.get` returns
/// a borrowed slice, so unlike the old allocating API there is nothing to free.
const Env = struct {
    verbose: bool,
    fail_first: bool,
    filter: ?[]const u8,

    fn init(environ_map: *std.process.Environ.Map) Env {
        return .{
            .verbose = readEnvBool(environ_map, "TEST_VERBOSE", true),
            .fail_first = readEnvBool(environ_map, "TEST_FAIL_FIRST", false),
            .filter = environ_map.get("TEST_FILTER"),
        };
    }

    fn readEnvBool(environ_map: *std.process.Environ.Map, key: []const u8, deflt: bool) bool {
        const value = environ_map.get(key) orelse return deflt;
        return std.ascii.eqlIgnoreCase(value, "true");
    }
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    if (current_test) |ct| {
        std.debug.print("\x1b[31m{s}\npanic running \"{s}\"\n{s}\x1b[0m\n", .{ BORDER, ct, BORDER });
    }
    std.debug.defaultPanic(msg, ret_addr);
}

fn isUnnamed(t: std.builtin.TestFn) bool {
    const marker = ".test_";
    const test_name = t.name;
    const index = std.mem.find(u8, test_name, marker) orelse return false;
    _ = std.fmt.parseInt(u32, test_name[index + marker.len ..], 10) catch return false;
    return true;
}

fn isSetup(t: std.builtin.TestFn) bool {
    std.debug.print("{s}\n", .{t.name});
    return std.mem.endsWith(u8, t.name, "tests:beforeAll");
}

fn isTeardown(t: std.builtin.TestFn) bool {
    return std.mem.endsWith(u8, t.name, "tests:afterAll");
}
