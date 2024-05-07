const std = @import("std");

pub fn create_new_dir(dir_name: []const u8) !std.fs.Dir {
    var current_dir = std.fs.cwd();
    current_dir.makeDir(dir_name) catch |e| {
        switch (e) {
            std.posix.MakeDirError.PathAlreadyExists => {},
            else => std.debug.print("some error", .{}),
        }
    };

    return current_dir.openDir(dir_name, .{});
}

pub fn create_subdir(dir: std.fs.Dir, path: []const u8) !std.fs.Dir {
    dir.makeDir(path) catch |e| {
        switch (e) {
            std.posix.MakeDirError.PathAlreadyExists => {},
            else => std.debug.print("some error", .{}),
        }
    };

    return dir;
}

pub fn copyRecursiveDir(src_dir: std.fs.Dir, dest_dir: std.fs.Dir) anyerror!void {
    var iter = src_dir.iterate();
    while (true) {
        const entry = try iter.next();
        if (entry == null) {
            break;
        } else {
            switch (entry.?.kind) {
                .file => try src_dir.copyFile(entry.?.name, dest_dir, entry.?.name, .{}),
                .directory => {
                    dest_dir.makeDir(entry.?.name) catch |e| {
                        switch (e) {
                            std.posix.MakeDirError.PathAlreadyExists => {},
                            else => return e,
                        }
                    };
                    var dest_entry_dir = try dest_dir.openDir(entry.?.name, .{ .access_sub_paths = true, .iterate = true });
                    defer dest_entry_dir.close();
                    var source_entry_dir = try src_dir.openDir(entry.?.name, .{ .access_sub_paths = true, .iterate = true });
                    defer source_entry_dir.close();

                    try copyRecursiveDir(source_entry_dir, dest_entry_dir);
                },
                else => {},
            }
        }
    }
}
