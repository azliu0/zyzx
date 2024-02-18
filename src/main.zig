const std = @import("std");
const llm_client = @import("llm_client.zig");

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

var should_stop: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false);

fn waitingAnimation() void {
    // const colors = [_][]const u8{ "30", "31", "32", "33", "34", "35", "36", "37" };
    // var index: usize = 0;

    // while (!should_stop.load(std.atomic.Ordering.SeqCst)) {
    //     std.time.sleep(500000);
    //     stdout.print("\r \r", .{}) catch {};
    //     for (0..index) |i| {
    //         stdout.print("\x1B[{s}m•\x1B[0m", .{colors[i]}) catch {};
    //     }
    //     index += 1;
    //     index %= colors.len;
    // }

    // // Clear spinner before exit
    // stdout.print("\r \r", .{}) catch {};
}

pub fn main() !void {
    try processCommand();
}

fn processCommand() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var repeat = true;
    var in: [4096]u8 = undefined;

    while (repeat) {
        var natural_language = std.ArrayList(u8).init(allocator);
        defer natural_language.deinit();

        var argv = std.ArrayList(u8).init(allocator);
        defer argv.deinit();

        // in = undefined;
        try stdout.print(">> What can I help you with?\n>> ", .{});
        // _ = try stdin.readUntilDelimiterOrEof(&in, '\n');
        // for (in) |c| {
        //     try natural_language.append(c);
        // }

        stdin.streamUntilDelimiter(natural_language.writer(), '\n', null) catch unreachable;

        var thread = try std.Thread.spawn(.{}, waitingAnimation, .{});

        var res: []const u8 = try llm_client.strip_response(allocator, natural_language.items);

        should_stop.store(true, std.atomic.Ordering.SeqCst);
        thread.join();

        for (res) |c| {
            try argv.append(c);
        }

        try make_file(argv.items);
        try run_sh();

        in = undefined;
        try stdout.print("Repeat? (y/n): ", .{});
        _ = try stdin.readUntilDelimiterOrEof(&in, '\n');
        if (in[0] != 'y') {
            repeat = false;
        }
    }
    // var token = std.mem.tokenize(u8, CMD, "\n");
    // while (token.next()) |line| {
    //     try argv.append(line);
    // }
    // try run_sh();
}

fn make_file(argv: []u8) !void {
    var file = try std.fs.cwd().createFile("bash.sh", .{});
    defer file.close();
    try file.writeAll(argv);
}

fn run_sh() !void {
    var in: [4096]u8 = undefined;

    // ask for approval
    try stdout.print("Run Program? (y/n): ", .{});
    _ = try stdin.readUntilDelimiterOrEof(&in, '\n');
    if (in[0] != 'y') {
        return;
    }

    const argv = [_][]const u8{
        "bash",
        "./bash.sh",
    };
    const alloc = std.heap.page_allocator;
    var proc = try std.ChildProcess.exec(.{
        .allocator = alloc,
        .argv = &argv,
    });
    try stdout.print("stdout: {s}", .{proc.stdout});
    std.log.info("stderr: {s}", .{proc.stderr});
}
