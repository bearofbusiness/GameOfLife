const std = @import("std");

const stdout_file = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

var allocator = std.heap.page_allocator;

var board: [][]bool = undefined;
var bufferBoard: [][]bool = undefined;

const boardSize: usize = 16;
const offsets = [_]i32{ -1, 0, 1 };
var buff: [5]u8 = undefined;
pub fn main() !void {
    try createboards();
    board[3][1] = true;
    board[3][2] = true;
    board[3][3] = true;
    board[2][3] = true;
    board[1][2] = true;

    while (true) {
        try printBoard();

        //copy from board to buffer
        for (board, 0..) |row, i| {
            for (row, 0..) |_, o| {
                bufferBoard[i][o] = board[i][o];
            }
        }
        //_ = try std.io.getStdIn().reader().read(buff[0..]);
        std.time.sleep(100000000); //sleep for a second
        runGeneration();
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

fn printBoard() !void {
    for (board) |row| {
        for (row) |space| {
            if (space) {
                try stdout.print("▓▓", .{}); // █
            } else {
                try stdout.print("░░", .{});
            }
        }
        try stdout.print("\n", .{});
    }
    try stdout.print("\n", .{});
    try bw.flush();
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
