const std = @import("std");
const create_dir = @import("ssg_new.zig");
const build_pages = @import("build.zig");
const c_md = @cImport({
    @cInclude("md4c-html.h");
    @cInclude("md4c.h");
});

// const params = struct {
//     base_path: []const u8,
//     subtitle: []const u8,
//     author: []const u8,
//     site_url: []const u8,
// };

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
                            std.os.MakeDirError.PathAlreadyExists => {},
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

// pub fn process_output(html_output: [*c]const c_md.MD_CHAR, size: c_md.MD_SIZE, _: ?*anyopaque) callconv(.C) void {
//     const html_str: []const u8 = @ptrCast(html_output[0..size]);

//     const temp_file = std.fs.cwd().createFile("./temp.html", .{}) catch unreachable;
//     _ = temp_file.write(html_str) catch unreachable;
//     defer temp_file.close();

//     std.debug.print("\n{s}", .{html_str});
// }

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var dir = try create_dir.create_new_dir("./site");
    dir = try create_dir.create_subdir(dir, "./templates");
    dir = try create_dir.create_subdir(dir, "./templates/listed-kevlar-theme");
    dir = try create_dir.create_subdir(dir, "./posts");
    dir = try create_dir.create_subdir(dir, "./dist");
    defer dir.close();

    const source_dir = try std.fs.cwd().openDir("./listed-kevlar-theme", .{ .access_sub_paths = true, .iterate = true });
    const target_dir = try std.fs.cwd().openDir("./site/templates/listed-kevlar-theme", .{ .access_sub_paths = true, .iterate = true });
    try create_dir.copyRecursiveDir(source_dir, target_dir);

    try build_pages.build();

    const x = "# hello world#";

    const some_var = try alloc.alloc(u8, x.len);

    defer alloc.free(some_var);
    std.mem.copyForwards(u8, some_var, x);
    //_ = c_md.md_html(some_c_str, x.len, process_output, null, k, k);
}
