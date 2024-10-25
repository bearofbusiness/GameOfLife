const std = @import("std");
const io = std.io;

const mibu = @import("mibu");
const events = mibu.events;
const term = mibu.term;
const utils = mibu.utils;

// const stdout_file = io.getStdOut().writer();
// var bw = io.bufferedWriter(stdout_file);
// const stdout = bw.writer();

var allocator = std.heap.page_allocator;

var board: [][]bool = undefined;
var bufferBoard: [][]bool = undefined;

var boardSize: usize = 16;
const offsets = [_]i32{ -1, 0, 1 };
var buff: [5]u8 = undefined;

//vars between threads
var pause = false;
var exit = false;

pub fn main() !void {
    const stdin = io.getStdIn();
    const stdout = io.getStdOut();

    //get input argument
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); //bypass first arg
    const optslice = args.next();
    const slice = if (optslice) |slice| slice else &[_]u8{};
    boardSize = std.fmt.parseInt(usize, slice, 10) catch 16;

    //enable terminal raw mode
    var raw_term = try term.enableRawMode(stdin.handle, .blocking);
    defer raw_term.disableRawMode() catch {};

    try mibu.clear.all(stdout);

    // listen to mouse events
    try stdout.writer().print("{s}", .{utils.enable_mouse_tracking});
    defer stdout.writer().print("{s}", .{utils.disable_mouse_tracking}) catch {};

    try mibu.cursor.goTo(stdout.writer(), 1, 1);
    try stdout.writer().print("Press space to pause and click to edit while paused. Press q or Ctrl-C to exit...\n\r", .{});

    try createboards();

    board[3][1] = true;
    board[3][2] = true;
    board[3][3] = true;
    board[2][3] = true;
    board[1][2] = true;

    const inputThread = try std.Thread.spawn(.{}, getInputs, .{ stdin, stdout });
    _ = inputThread;

    while (true) {
        while ((try term.getSize(0)).width * 2 < boardSize or (try term.getSize(0)).height < boardSize + 2) {
            try mibu.cursor.goTo(stdout.writer(), 1, 2);
            try stdout.writer().print("Error: The Terminal Must be atleast {d} by {d}.", .{ boardSize, boardSize + 2 });
            if (exit) break;
        } else {
            try mibu.clear.all(stdout);
            try mibu.cursor.goTo(stdout.writer(), 1, 1);
            try stdout.writer().print("Press space to pause and click to edit while paused. Press q or Ctrl-C to exit...\n\r", .{});
            try printBoard(stdout);
        }

        //check for pause and exits
        while (pause) {
            if (exit) break;
        }
        if (exit) break;

        try printBoard(stdout);

        //_ = try std.io.getStdIn().reader().read(buff[0..]);
        std.time.sleep(100000000); //sleep for a second

        //copy from board to buffer
        for (board, 0..) |row, i| {
            for (row, 0..) |_, o| {
                bufferBoard[i][o] = board[i][o];
            }
        }

        runGeneration();
    }
}

fn getInputs(stdin: std.fs.File, stdout: std.fs.File) !void {
    const consoleOffsetx: u16 = 32;
    const consoleOffsety: u16 = 34;

    while (true) {
        const next = try events.next(stdin);
        switch (next) {
            .key => |k| switch (k) {
                // char can have more than 1 u8, because of unicode
                .char => |c| switch (c) {
                    'q' => {
                        exit = true;
                        break;
                    },
                    ' ' => {
                        pause = !pause;
                    },
                    else => {}, //try stdout.writer().print("Key char: {u}\n\r", .{c}),
                },
                .ctrl => |c| switch (c) {
                    'c' => {
                        exit = true;
                        break;
                    },
                    else => {}, //else => try stdout.writer().print("Key: {s}\n\r", .{k}),
                },
                else => {}, //else => try stdout.writer().print("Key: {s}\n\r", .{k}),
            },
            .mouse => |m| {
                if (pause and m.button != mibu.events.MouseButton.release) {
                    //try mibu.cursor.goTo(stdout.writer(), 1, 2);
                    //try mibu.clear.entire_line(stdout);
                    //try stdout.writer().print("Mouse: {s}", .{m});
                    if (m.button == mibu.events.MouseButton.left) {
                        if (m.x >= consoleOffsetx and (m.x - consoleOffsetx) / 2 < boardSize) {
                            if (m.y >= consoleOffsety and (m.y - consoleOffsety) < boardSize) {
                                //try stdout.writer().print(";  Clicked Pos: x{d}, y{d}", .{ (m.y - consoleOffsety), (m.x - consoleOffsetx) / 2 });
                                board[(m.y - consoleOffsety)][(m.x - consoleOffsetx) / 2] = !board[(m.y - consoleOffsety)][(m.x - consoleOffsetx) / 2];
                                try printBoard(stdout);
                            }
                        }
                    }
                }
            },

            // ex. mouse events not supported yet
            else => {}, //else => try stdout.writer().print("Event: {any}\n\r", .{next}),
        }
    }
}

fn createboards() !void {
    board = try allocator.alloc([]bool, boardSize);
    for (0..boardSize) |row| {
        board[row] = try allocator.alloc(bool, boardSize);
    }

    bufferBoard = try allocator.alloc([]bool, boardSize);
    for (0..boardSize) |row| {
        bufferBoard[row] = try allocator.alloc(bool, boardSize);
    }
}

fn printBoard(stdout: std.fs.File) !void {
    // try mibu.cursor.restore(stdout.writer());
    // try mibu.cursor.save(stdout.writer());
    try mibu.cursor.goTo(stdout.writer(), 1, 3);
    for (board) |row| {
        for (row) |space| {
            if (space) {
                try stdout.writer().print("▓▓", .{}); // █
            } else {
                try stdout.writer().print("░░", .{});
            }
        }
        try stdout.writer().print("\n\r", .{});
    }
    try stdout.writer().print("\n\r", .{});
    //try bw.flush();
}

fn runGeneration() void {
    for (board, 0..) |row, i| {
        for (row, 0..) |_, o| {
            var numOfLiving: u8 = 0;
            for (offsets) |offi| {
                for (offsets) |offo| {
                    if (offi == 0 and offo == 0) continue;
                    const offseti = try wraper(i, offi);
                    const offseto = try wraper(o, offo);
                    if (board[offseti][offseto]) {
                        numOfLiving += 1;
                        //std.log.debug("offset cell:{},{}; value:{}", .{ offseti, offseto, board[offseti][offseto] });
                    }
                }
            }
            //std.log.debug("cell:{},{}; numberOfLiving:{}; value:{}", .{ i, o, numOfLiving, board[i][o] });
            if (numOfLiving > 3 or numOfLiving < 2) bufferBoard[i][o] = false;
            if (numOfLiving == 3) bufferBoard[i][o] = true;
            //std.log.debug("cell:{},{}; value:{}", .{ i, o, board[i][o] });
            //std.log.debug("", .{});

        }
    }
    for (board, 0..) |row, i| {
        for (row, 0..) |_, o| {
            board[i][o] = bufferBoard[i][o];
        }
    }
}

fn wraper(x: usize, offx: i32) !usize {
    const xi32: i32 = @intCast(x);
    if (xi32 + offx < 0) return boardSize - 1;
    if (xi32 + offx >= boardSize) return 0;
    return @intCast(xi32 + offx);
}
